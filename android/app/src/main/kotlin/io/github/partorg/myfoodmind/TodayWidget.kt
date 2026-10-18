package io.github.partorg.myfoodmind

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.time.LocalDate
import kotlin.math.abs

/**
 * Home-screen widget: today's calories (only if the user turned that on in Settings), a mic that opens the chat
 * listening, and a Log button. Three layouts by size: small (line + mic), medium (+ Log), large (+ progress).
 */
class TodayWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray,
                          widgetData: SharedPreferences) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, views(context, widgetData, appWidgetManager.getAppWidgetOptions(id)))
        }
    }

    // Android 10-11 pick the layout here when the user resizes; 12+ pick from the sized layouts themselves.
    override fun onAppWidgetOptionsChanged(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int,
                                           newOptions: Bundle) {
        appWidgetManager.updateAppWidget(appWidgetId, views(context, HomeWidgetPlugin.getData(context), newOptions))
    }

    private fun views(context: Context, widgetData: SharedPreferences, options: Bundle): RemoteViews {
        // Written by the app (syncHomeWidget in lib/app_state.dart). A stale day counts as nothing eaten yet.
        val today = widgetData.getString("day", "") == LocalDate.now().toString()
        val kcal = widgetData.getString("kcal", "") ?: ""
        val goal = widgetData.getString("goal", "") ?: ""
        val shown = if (today) kcal else "0"
        val line = when {
            kcal.isEmpty() -> context.getString(R.string.widget_hidden)
            goal.isEmpty() -> context.getString(R.string.widget_kcal, shown)
            else -> context.getString(R.string.widget_kcal_goal, shown, goal)
        }
        val eaten = shown.filter { it.isDigit() }.toIntOrNull() // "≈1240" when a meal is estimated
        val target = goal.toIntOrNull()

        fun open(uri: String?) = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri?.let(Uri::parse))

        fun build(layout: Int) = RemoteViews(context.packageName, layout).apply {
            setTextViewText(R.id.widget_line, line)
            setOnClickPendingIntent(R.id.widget_root, open(null))
            setOnClickPendingIntent(R.id.widget_voice, open("myfoodmind://voice"))
            if (layout != R.layout.today_widget_small) {
                setOnClickPendingIntent(R.id.widget_log, open("myfoodmind://log"))
            }
            if (layout == R.layout.today_widget_large) {
                val known = kcal.isNotEmpty() && eaten != null && target != null && target > 0
                val visibility = if (known) View.VISIBLE else View.GONE
                setViewVisibility(R.id.widget_progress, visibility)
                setViewVisibility(R.id.widget_left, visibility)
                if (known) {
                    setProgressBar(R.id.widget_progress, 100, minOf(100, eaten!! * 100 / target!!), false)
                    val left = target - eaten
                    setTextViewText(R.id.widget_left,
                        context.getString(if (left >= 0) R.string.widget_left else R.string.widget_over, abs(left).toString()))
                }
            }
        }

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            RemoteViews(mapOf(
                SizeF(70f, 40f) to build(R.layout.today_widget_small),
                SizeF(200f, 40f) to build(R.layout.today_widget),
                SizeF(200f, 110f) to build(R.layout.today_widget_large),
            ))
        } else {
            val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
            build(when {
                width == 0 -> R.layout.today_widget // size not known yet
                width >= 200 && height >= 110 -> R.layout.today_widget_large
                width >= 200 -> R.layout.today_widget
                else -> R.layout.today_widget_small
            })
        }
    }
}
