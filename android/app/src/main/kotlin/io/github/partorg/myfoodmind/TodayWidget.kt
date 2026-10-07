package io.github.partorg.myfoodmind

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.time.LocalDate

/** Home-screen widget: today's calories (only if the user turned that on in Me) and a Log button. */
class TodayWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray,
                          widgetData: SharedPreferences) {
        // Written by the app (lib/home_widget_sync.dart). A stale day counts as nothing eaten yet.
        val today = widgetData.getString("day", "") == LocalDate.now().toString()
        val kcal = widgetData.getString("kcal", "") ?: ""
        val goal = widgetData.getString("goal", "") ?: ""
        val line = when {
            kcal.isEmpty() -> context.getString(R.string.widget_hidden)
            goal.isEmpty() -> context.getString(R.string.widget_kcal, if (today) kcal else "0")
            else -> context.getString(R.string.widget_kcal_goal, if (today) kcal else "0", goal)
        }
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.today_widget).apply {
                setTextViewText(R.id.widget_line, line)
                setOnClickPendingIntent(R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
                setOnClickPendingIntent(R.id.widget_log,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("myfoodmind://log")))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
