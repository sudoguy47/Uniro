package com.example.uniro1

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

class CampusMonthWidgetProvider : AppWidgetProvider() {

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
        val views = RemoteViews(context.packageName, R.layout.campus_month_widget_layout)

        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val rawTasks = prefs.getString("flutter.ct_tasks", null)

            val pendingList = mutableListOf<JSONObject>()
            val tasksByDate = mutableMapOf<String, MutableList<JSONObject>>()
            val completedDates = mutableSetOf<String>()

            val cal = Calendar.getInstance()
            val currentYear = cal.get(Calendar.YEAR)
            val currentMonth = cal.get(Calendar.MONTH) // 0-based

            val monthPrefix = String.format(Locale.US, "%04d-%02d", currentYear, currentMonth + 1)
            var monthPendingCount = 0
            var monthCompletedCount = 0

            if (!rawTasks.isNullOrBlank()) {
                val array = JSONArray(rawTasks)
                for (i in 0 until array.length()) {
                    val task = array.getJSONObject(i)
                    val dueDate = task.optString("dueDate")
                    val status = task.optString("status")

                    if (status != "completed") {
                        pendingList.add(task)
                    }

                    if (dueDate.isNotBlank()) {
                        tasksByDate.getOrPut(dueDate) { mutableListOf() }.add(task)
                        if (status == "completed") {
                            completedDates.add(dueDate)
                        }
                        if (dueDate.startsWith(monthPrefix)) {
                            if (status == "completed") {
                                monthCompletedCount++
                            } else {
                                monthPendingCount++
                            }
                        }
                    }
                }
            }

            pendingList.sortBy { it.optString("dueDate", "9999-99-99") }

            // Month Header (e.g. "SEP 2026")
            val monthHeaderFmt = SimpleDateFormat("MMM yyyy", Locale.US)
            views.setTextViewText(R.id.widget_month_header_title, monthHeaderFmt.format(cal.time).uppercase(Locale.US))

            // Calculate Activity Streak (consecutive days with completed tasks)
            val streakCal = Calendar.getInstance()
            val todayDateStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(streakCal.time)
            val tomorrowCal = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
            val tomorrowDateStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(tomorrowCal.time)

            var streak = 0
            if (completedDates.contains(todayDateStr)) {
                streak = 1
                streakCal.add(Calendar.DAY_OF_YEAR, -1)
            } else {
                streakCal.add(Calendar.DAY_OF_YEAR, -1)
                val yesterdayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(streakCal.time)
                if (completedDates.contains(yesterdayStr)) {
                    streak = 1
                    streakCal.add(Calendar.DAY_OF_YEAR, -1)
                }
            }

            while (streak > 0) {
                val dStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(streakCal.time)
                if (completedDates.contains(dStr)) {
                    streak++
                    streakCal.add(Calendar.DAY_OF_YEAR, -1)
                } else {
                    break
                }
            }

            views.setTextViewText(R.id.widget_month_streak, "🔥 $streak")

            // Render Monthly Calendar Matrix Bitmap
            try {
                val gridBitmap = drawMonthlyCalendarGrid(currentYear, currentMonth, todayDateStr, tasksByDate)
                views.setImageViewBitmap(R.id.widget_month_chart_image, gridBitmap)
            } catch (e: Throwable) {
                e.printStackTrace()
            }

            // Highlight next upcoming task or month summary
            val upcomingTasks = pendingList.filter { it.optString("dueDate") >= todayDateStr }
            val nextTask = if (upcomingTasks.isNotEmpty()) upcomingTasks[0] else if (pendingList.isNotEmpty()) pendingList[0] else null

            if (nextTask != null) {
                val title = nextTask.optString("title", "Upcoming Task")
                val type = formatType(nextTask.optString("type"))
                val due = formatDue(nextTask.optString("dueDate"), todayDateStr, tomorrowDateStr)
                views.setTextViewText(R.id.widget_month_task_title, title)
                views.setTextViewText(R.id.widget_month_task_meta, "$type • $due • $monthPendingCount due this month")
            } else {
                views.setTextViewText(R.id.widget_month_task_title, "All caught up! No pending tasks")
                views.setTextViewText(R.id.widget_month_task_meta, "$monthCompletedCount completed this month")
            }

            // Tap intent opens app
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId + 1000,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_month_root, pendingIntent)

        } catch (e: Throwable) {
            e.printStackTrace()
        }

        try {
            appWidgetManager.updateAppWidget(appWidgetId, views)
        } catch (e: Throwable) {
            e.printStackTrace()
        }
    }

    private fun drawMonthlyCalendarGrid(
        year: Int,
        month: Int,
        todayStr: String,
        tasksByDate: Map<String, List<JSONObject>>
    ): Bitmap {
        val width = 560
        val height = 230
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val cal = Calendar.getInstance().apply {
            set(Calendar.YEAR, year)
            set(Calendar.MONTH, month)
            set(Calendar.DAY_OF_MONTH, 1)
        }

        val daysInMonth = cal.getActualMaximum(Calendar.DAY_OF_MONTH)
        // Monday = 0, Tuesday = 1, ..., Sunday = 6
        val startOffset = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7

        val dayNames = arrayOf("Mo", "Tu", "We", "Th", "Fr", "Sa", "Su")
        val slotWidth = width / 7f
        val cellWidth = 72f
        val cellHeight = 27f
        val cellRadius = 6f

        val paintDayName = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#7A7570")
            textSize = 15f
            textAlign = Paint.Align.CENTER
        }

        // Draw Day of Week Header row
        for (col in 0 until 7) {
            val cx = slotWidth * col + (slotWidth / 2f)
            canvas.drawText(dayNames[col], cx, 15f, paintDayName)
        }

        val paintCellEmpty = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#1C1C22") }
        val paintCellPlaceholder = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#141418") }
        val paintCellWarm = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#B35422") }
        val paintCellRed = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#E05345") }
        val paintCellGreen = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#2E7D32") }

        val paintTodayBorder = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#E8963C")
            style = Paint.Style.STROKE
            strokeWidth = 2.2f
        }

        val paintTextMuted = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#706B65")
            textSize = 14f
            textAlign = Paint.Align.CENTER
        }
        val paintTextWhite = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = 14f
            textAlign = Paint.Align.CENTER
            isFakeBoldText = true
        }
        val paintTextToday = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#E8963C")
            textSize = 14f
            textAlign = Paint.Align.CENTER
            isFakeBoldText = true
        }

        val startY = 24f
        val rowHeight = cellHeight + 5f

        for (row in 0 until 6) {
            for (col in 0 until 7) {
                val index = row * 7 + col
                val dayNum = index - startOffset + 1

                val cx = slotWidth * col + (slotWidth / 2f)
                val cy = startY + (row * rowHeight)
                val rect = RectF(cx - cellWidth / 2f, cy, cx + cellWidth / 2f, cy + cellHeight)

                if (dayNum in 1..daysInMonth) {
                    val dateStr = String.format(Locale.US, "%04d-%02d-%02d", year, month + 1, dayNum)
                    val isToday = dateStr == todayStr

                    val tasks = tasksByDate[dateStr] ?: emptyList()
                    val pendingCount = tasks.count { it.optString("status") != "completed" }
                    val completedCount = tasks.count { it.optString("status") == "completed" }

                    // Choose background paint
                    val bgPaint = when {
                        pendingCount >= 2 -> paintCellRed
                        pendingCount == 1 -> paintCellWarm
                        completedCount > 0 -> paintCellGreen
                        else -> paintCellEmpty
                    }

                    canvas.drawRoundRect(rect, cellRadius, cellRadius, bgPaint)

                    // Draw today accent ring
                    if (isToday) {
                        canvas.drawRoundRect(rect, cellRadius, cellRadius, paintTodayBorder)
                    }

                    // Choose text paint
                    val tPaint = when {
                        pendingCount > 0 || completedCount > 0 -> paintTextWhite
                        isToday -> paintTextToday
                        else -> paintTextMuted
                    }

                    canvas.drawText(dayNum.toString(), cx, cy + (cellHeight / 2f) + 5f, tPaint)
                } else {
                    // Placeholder cell outside current month (creates GymMane matrix pattern)
                    canvas.drawRoundRect(rect, cellRadius, cellRadius, paintCellPlaceholder)
                }
            }
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
                    ComponentName(context, CampusMonthWidgetProvider::class.java)
                )
                if (ids.isNotEmpty()) {
                    val provider = CampusMonthWidgetProvider()
                    provider.onUpdate(context, appWidgetManager, ids)
                }
            } catch (e: Throwable) {
                e.printStackTrace()
            }
        }
    }
}
