package dev.sudoguy.uniro

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class CampusWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.campus_widget_layout)

        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val rawTasks = prefs.getString("flutter.ct_tasks", null)

            val pendingList = mutableListOf<JSONObject>()
            val tasksByDate = mutableMapOf<String, Int>()

            if (!rawTasks.isNullOrBlank()) {
                val array = JSONArray(rawTasks)
                for (i in 0 until array.length()) {
                    val task = array.getJSONObject(i)
                    if (task.optString("status") != "completed") {
                        pendingList.add(task)
                        val dueDate = task.optString("dueDate")
                        if (dueDate.isNotBlank()) {
                            tasksByDate[dueDate] = (tasksByDate[dueDate] ?: 0) + 1
                        }
                    }
                }
            }

            pendingList.sortBy { it.optString("dueDate", "9999-99-99") }

            // Calculate current week start (Monday)
            val cal = Calendar.getInstance()
            cal.firstDayOfWeek = Calendar.MONDAY
            while (cal.get(Calendar.DAY_OF_WEEK) != Calendar.MONDAY) {
                cal.add(Calendar.DAY_OF_YEAR, -1)
            }

            val dateFmt = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            val dayNames = arrayOf("Mo", "Tu", "We", "Th", "Fr", "Sa", "Su")
            val weekDates = mutableListOf<String>()
            val weekDayNumbers = mutableListOf<Int>()
            var weekDueCount = 0

            for (i in 0 until 7) {
                val dateStr = dateFmt.format(cal.time)
                weekDates.add(dateStr)
                weekDayNumbers.add(cal.get(Calendar.DAY_OF_MONTH))
                val countForDay = tasksByDate[dateStr] ?: 0
                weekDueCount += countForDay
                cal.add(Calendar.DAY_OF_YEAR, 1)
            }

            views.setTextViewText(R.id.widget_week_summary, "$weekDueCount due this week")

            // Render Graphic Weekly Load Chart via Canvas
            try {
                val chartBitmap = drawWeeklyLoadChart(weekDates, dayNames, weekDayNumbers, tasksByDate)
                views.setImageViewBitmap(R.id.widget_chart_image, chartBitmap)
            } catch (e: Throwable) {
                e.printStackTrace()
            }

            val todayStr = dateFmt.format(Date())
            val tomorrowCal = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
            val tomorrowStr = dateFmt.format(tomorrowCal.time)

            if (pendingList.isEmpty()) {
                views.setViewVisibility(R.id.widget_task_container, View.GONE)
                views.setViewVisibility(R.id.widget_empty_text, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_empty_text, View.GONE)
                views.setViewVisibility(R.id.widget_task_container, View.VISIBLE)

                val t = pendingList[0]
                views.setTextViewText(R.id.widget_task_title, t.optString("title", "Upcoming Task"))
                val type = formatType(t.optString("type"))
                val due = formatDue(t.optString("dueDate"), todayStr, tomorrowStr)
                views.setTextViewText(R.id.widget_task_meta, "$type • $due")
            }

            // Click Intent -> Open App
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

        } catch (e: Throwable) {
            e.printStackTrace()
        }

        try {
            appWidgetManager.updateAppWidget(appWidgetId, views)
        } catch (e: Throwable) {
            e.printStackTrace()
        }
    }

    private fun drawWeeklyLoadChart(
        weekDates: List<String>,
        dayNames: Array<String>,
        dayNumbers: List<Int>,
        tasksByDate: Map<String, Int>
    ): Bitmap {
        val width = 560
        val height = 160
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val counts = weekDates.map { tasksByDate[it] ?: 0 }
        val maxCount = (counts.maxOrNull() ?: 1).coerceAtLeast(1)

        val slotWidth = width / 7f
        val barWidth = 26f
        val maxBarHeight = 75f
        val chartBaseline = 110f

        val paintBarRed = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#E05345") }
        val paintBarEmpty = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#26262B") }

        val paintDayName = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#9E9589")
            textSize = 20f
            textAlign = Paint.Align.CENTER
        }
        val paintDayNumber = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#6A655F")
            textSize = 17f
            textAlign = Paint.Align.CENTER
        }

        val dateFmt = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        val todayStr = dateFmt.format(Date())

        for (i in 0 until 7) {
            val count = counts[i]
            val dateStr = weekDates[i]
            val centerX = slotWidth * i + (slotWidth / 2f)

            if (count > 0) {
                val barH = (count.toFloat() / maxCount * maxBarHeight).coerceAtLeast(14f)
                val top = chartBaseline - barH
                val rect = RectF(centerX - barWidth / 2f, top, centerX + barWidth / 2f, chartBaseline)
                canvas.drawRoundRect(rect, 6f, 6f, paintBarRed)
            } else {
                val rect = RectF(centerX - barWidth / 2f, chartBaseline - 6f, centerX + barWidth / 2f, chartBaseline)
                canvas.drawRoundRect(rect, 3f, 3f, paintBarEmpty)
            }

            // Highlight current day if it's today
            if (dateStr == todayStr) {
                paintDayName.color = Color.parseColor("#E8963C")
                paintDayNumber.color = Color.parseColor("#E8963C")
            } else {
                paintDayName.color = Color.parseColor("#9E9589")
                paintDayNumber.color = Color.parseColor("#6A655F")
            }

            // Draw day label (Mo, Tu...)
            canvas.drawText(dayNames[i], centerX, chartBaseline + 24f, paintDayName)
            // Draw day number (21, 22...)
            canvas.drawText(dayNumbers[i].toString(), centerX, chartBaseline + 44f, paintDayNumber)
        }

        return bitmap
    }

    private fun formatType(type: String): String = when (type.lowercase(Locale.getDefault())) {
        "assignment" -> "Assignment"
        "exam" -> "Exam"
        "ct" -> "Class Test"
        "viva" -> "Viva"
        "presentation" -> "Presentation"
        "lab" -> "Lab"
        "project" -> "Project"
        else -> "Task"
    }

    private fun formatDue(dueDate: String, todayStr: String, tomorrowStr: String): String = when (dueDate) {
        todayStr -> "Due Today"
        tomorrowStr -> "Due Tomorrow"
        else -> if (dueDate.isNotBlank() && dueDate < todayStr) "Overdue" else if (dueDate.isNotBlank()) "Due $dueDate" else "No due date"
    }

    companion object {
        fun updateAllWidgets(context: Context) {
            try {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val ids = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, CampusWidgetProvider::class.java)
                )
                if (ids.isNotEmpty()) {
                    val provider = CampusWidgetProvider()
                    provider.onUpdate(context, appWidgetManager, ids)
                }
            } catch (e: Throwable) {
                e.printStackTrace()
            }
        }
    }
}
