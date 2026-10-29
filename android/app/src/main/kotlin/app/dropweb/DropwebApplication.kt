package app.dropweb;

import android.app.Application
import android.content.Context
import android.content.res.Configuration
import androidx.lifecycle.Observer
import app.dropweb.widgets.DropwebWidgetProvider

class DropwebApplication : Application() {
    companion object {
        private lateinit var instance: DropwebApplication
        fun getAppContext(): Context {
            return instance.applicationContext
        }
    }

    private val widgetObserver = Observer<RunState> {
        DropwebWidgetProvider.updateAllWidgets(this)
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        GlobalState.runState.observeForever(widgetObserver)
    }

    /** До Android 12 виджет не знает о ночи сам, поэтому перекрашиваем при смене темы системы. */
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        DropwebWidgetProvider.updateAllWidgets(this)
    }
}
