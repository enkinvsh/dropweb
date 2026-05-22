package app.dropweb.services

import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi
import androidx.lifecycle.Observer
import app.dropweb.GlobalState
import app.dropweb.RunState


@RequiresApi(Build.VERSION_CODES.N)
class DropwebTileService : TileService() {

    private val mihomoObserver = Observer<RunState> { _ ->
        refreshTile()
    }

    private fun refreshTile() {
        val tile = qsTile ?: return

        val mihomoState = GlobalState.runState.value
        val hasProfile = GlobalState.hasActiveProfile()

        tile.state = when {
            !hasProfile -> Tile.STATE_UNAVAILABLE
            else -> when (mihomoState) {
                RunState.START -> Tile.STATE_ACTIVE
                RunState.PENDING -> Tile.STATE_UNAVAILABLE
                RunState.STOP, null -> Tile.STATE_INACTIVE
            }
        }
        tile.updateTile()
    }

    override fun onStartListening() {
        super.onStartListening()

        GlobalState.syncStatus()
        GlobalState.runState.observeForever(mihomoObserver)

        refreshTile()
    }

    override fun onStopListening() {
        GlobalState.runState.removeObserver(mihomoObserver)
        super.onStopListening()
    }

    override fun onClick() {
        unlockAndRun {
            when (qsTile?.state) {
                Tile.STATE_INACTIVE -> GlobalState.handleStart()
                Tile.STATE_ACTIVE -> GlobalState.handleStop()
                Tile.STATE_UNAVAILABLE -> Unit
                else -> GlobalState.handleToggle()
            }
        }
    }

    override fun onDestroy() {
        GlobalState.runState.removeObserver(mihomoObserver)
        super.onDestroy()
    }
}
