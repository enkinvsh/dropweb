package app.dropweb.widgets

import android.content.Context
import android.graphics.Color
import android.util.Log
import app.dropweb.R
import org.json.JSONObject

/** Цвета виджета одной яркости; роли те же, что у кнопки подключения в приложении. */
data class WidgetColors(
    val bg: Int,
    val title: Int,
    val sub: Int,
    val offBg: Int,
    val offFg: Int,
    val onBg: Int,
    val onFg: Int,
)

data class WidgetTexts(
    val on: String,
    val off: String,
    val pending: String,
    val cdOn: String,
    val cdOff: String,
    val cdPending: String,
)

/** Стиль виджета: то, что приложение посчитало в Dart (`m3eWidgetPayload`). */
data class WidgetStyle(
    val name: String,
    val texts: WidgetTexts,
    val light: WidgetColors,
    val dark: WidgetColors,
)

/**
 * Хранит последний стиль от приложения. Виджет живёт и тогда, когда приложение не
 * запущено, поэтому стиль лежит в SharedPreferences, а не в памяти процесса.
 */
object WidgetStyleStore {
    private const val PREFS = "dropweb_widget"
    private const val KEY_STYLE = "style"

    /** Должна совпадать с `kM3eWidgetPayloadVersion` в Dart. */
    private const val VERSION = 1

    fun save(context: Context, json: String) {
        // Битый или чужой по версии JSON не затираем: иначе виджет потерял бы
        // хороший стиль из-за одной неудачной отправки.
        if (parse(json) == null) return
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY_STYLE, json).apply()
    }

    fun load(context: Context): WidgetStyle {
        val json = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_STYLE, null)
        return (json?.let(::parse)) ?: fallback(context)
    }

    /**
     * До первого запуска приложения: «Голубой» из [WidgetStyleDefaults] и подписи из
     * ресурсов (Android выбирает язык системы).
     */
    private fun fallback(context: Context) = WidgetStyle(
        name = context.getString(R.string.app_name),
        texts = WidgetTexts(
            on = context.getString(R.string.widget_status_on),
            off = context.getString(R.string.widget_status_off),
            pending = context.getString(R.string.widget_status_pending),
            cdOn = context.getString(R.string.widget_cd_disconnect),
            cdOff = context.getString(R.string.widget_cd_connect),
            cdPending = context.getString(R.string.widget_cd_cancel),
        ),
        light = WidgetStyleDefaults.light,
        dark = WidgetStyleDefaults.dark,
    )

    private fun parse(json: String): WidgetStyle? = try {
        val o = JSONObject(json)
        if (o.getInt("v") != VERSION) {
            null
        } else {
            val t = o.getJSONObject("texts")
            WidgetStyle(
                name = o.getString("name"),
                texts = WidgetTexts(
                    on = t.getString("on"),
                    off = t.getString("off"),
                    pending = t.getString("pending"),
                    cdOn = t.getString("cdOn"),
                    cdOff = t.getString("cdOff"),
                    cdPending = t.getString("cdPending"),
                ),
                light = colors(o.getJSONObject("light")),
                dark = colors(o.getJSONObject("dark")),
            )
        }
    } catch (e: Exception) {
        // JSONException и IllegalArgumentException от Color.parseColor.
        Log.w("WidgetStyle", "bad widget style: $e")
        null
    }

    private fun colors(o: JSONObject) = WidgetColors(
        bg = Color.parseColor(o.getString("bg")),
        title = Color.parseColor(o.getString("title")),
        sub = Color.parseColor(o.getString("sub")),
        offBg = Color.parseColor(o.getString("offBg")),
        offFg = Color.parseColor(o.getString("offFg")),
        onBg = Color.parseColor(o.getString("onBg")),
        onFg = Color.parseColor(o.getString("onFg")),
    )
}
