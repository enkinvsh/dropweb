package app.dropweb.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.widget.RemoteViews
import app.dropweb.GlobalState
import app.dropweb.R
import app.dropweb.RunState
import app.dropweb.extensions.getActionPendingIntent

/**
 * Виджет подключения: 1×1 — только кнопка, 2×1 и шире — плашка с именем сервиса и
 * статусом. Внешний вид повторяет кнопку подключения на главной (формы и роли цветов);
 * анимации RemoteViews не умеют, поэтому cookie не вращается, а connecting — статичный
 * SoftBurst.
 */
class DropwebWidgetProvider : AppWidgetProvider() {

    companion object {
        /**
         * Ширина, с которой виджет считается «широким». 110 dp — минимальная ширина двух
         * ячеек по гайдам (70 * n - 30).
         */
        private const val WIDE_MIN_DP = 110f
        private const val CELL_MIN_DP = 40f

        fun updateAllWidgets(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                ComponentName(context, DropwebWidgetProvider::class.java)
            )
            for (id in ids) {
                update(context, mgr, id)
            }
        }

        private fun update(context: Context, mgr: AppWidgetManager, id: Int) {
            val style = WidgetStyleStore.load(context)
            val state = currentState()
            val views = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Система сама выбирает раскладку по фактическому размеру: лаунчер не
                // обязан слать onAppWidgetOptionsChanged при каждом ресайзе.
                RemoteViews(
                    mapOf(
                        SizeF(CELL_MIN_DP, CELL_MIN_DP) to build(context, style, state, false),
                        SizeF(WIDE_MIN_DP, CELL_MIN_DP) to build(context, style, state, true),
                    )
                )
            } else {
                // OPTION_APPWIDGET_MIN_WIDTH уже в dp.
                val minWidth = mgr.getAppWidgetOptions(id)
                    .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
                build(context, style, state, minWidth >= WIDE_MIN_DP)
            }
            mgr.updateAppWidget(id, views)
        }

        private fun currentState() = when (GlobalState.runState.value) {
            RunState.START -> WidgetState.ON
            RunState.PENDING -> WidgetState.CONNECTING
            else -> WidgetState.OFF
        }

        private fun isNight(context: Context): Boolean =
            context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK ==
                Configuration.UI_MODE_NIGHT_YES

        /**
         * Цвет с учётом ночи. С Android 12 обе яркости уходят в RemoteViews и система сама
         * выбирает нужную при смене темы; раньше — только по яркости на момент обновления.
         */
        private fun RemoteViews.color(
            context: Context,
            viewId: Int,
            method: String,
            light: Int,
            dark: Int,
        ) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                setColorInt(viewId, method, light, dark)
            } else {
                setInt(viewId, method, if (isNight(context)) dark else light)
            }
        }

        private fun build(
            context: Context,
            style: WidgetStyle,
            state: WidgetState,
            wide: Boolean,
        ): RemoteViews {
            val views = RemoteViews(
                context.packageName,
                if (wide) R.layout.widget_vpn_wide else R.layout.widget_vpn_compact,
            )

            val shape = when (state) {
                WidgetState.ON -> R.drawable.widget_shape_cookie9
                else -> R.drawable.widget_shape_circle
            }
            val glyph = when (state) {
                WidgetState.CONNECTING -> R.drawable.widget_ic_connecting
                else -> R.drawable.widget_ic_power
            }
            val on = state == WidgetState.ON
            views.setImageViewResource(R.id.widget_shape, shape)
            views.setImageViewResource(R.id.widget_icon, glyph)
            views.color(
                context, R.id.widget_shape, "setColorFilter",
                if (on) style.light.onBg else style.light.offBg,
                if (on) style.dark.onBg else style.dark.offBg,
            )
            views.color(
                context, R.id.widget_icon, "setColorFilter",
                if (on) style.light.onFg else style.light.offFg,
                if (on) style.dark.onFg else style.dark.offFg,
            )

            views.setContentDescription(
                R.id.widget_button,
                when (state) {
                    WidgetState.ON -> style.texts.cdOn
                    WidgetState.CONNECTING -> style.texts.cdPending
                    WidgetState.OFF -> style.texts.cdOff
                },
            )
            views.setOnClickPendingIntent(R.id.widget_button, context.getActionPendingIntent("CHANGE"))

            if (wide) {
                views.color(context, R.id.widget_bg, "setColorFilter", style.light.bg, style.dark.bg)
                views.setTextViewText(R.id.widget_title, style.name)
                views.color(context, R.id.widget_title, "setTextColor", style.light.title, style.dark.title)
                views.setTextViewText(
                    R.id.widget_status,
                    when (state) {
                        WidgetState.ON -> style.texts.on
                        WidgetState.CONNECTING -> style.texts.pending
                        WidgetState.OFF -> style.texts.off
                    },
                )
                views.color(context, R.id.widget_status, "setTextColor", style.light.sub, style.dark.sub)
                // Тап мимо кнопки открывает приложение.
                context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
                    views.setOnClickPendingIntent(
                        R.id.widget_root,
                        PendingIntent.getActivity(
                            context, 0, it,
                            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                        ),
                    )
                }
            }
            return views
        }
    }

    private enum class WidgetState { OFF, CONNECTING, ON }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            update(context, appWidgetManager, id)
        }
    }

    /** До Android 12 размер выбирает сам провайдер, поэтому смена размера — повод перестроить. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        update(context, appWidgetManager, appWidgetId)
    }
}
