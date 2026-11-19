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

    private data class CourseInfo(
        val id: String,
        val name: String,
        val code: String,
        val room: String?
    )

    private data class SlotInfo(
        val id: String,
        val courseId: String,
        val weekday: Int, // 1 = Monday .. 7 = Sunday
        val startMinutes: Int,
        val endMinutes: Int,
        val room: String?
    )

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.campus_widget_layout)

        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            // 1. Read Courses
            val coursesMap = mutableMapOf<String, CourseInfo>()
            val rawCourses = prefs.getString("flutter.ct_courses", null)
            if (!rawCourses.isNullOrBlank()) {
                val array = JSONArray(rawCourses)
                for (i in 0 until array.length()) {
                    val c = array.getJSONObject(i)
                    val id = optCleanString(c, "id")
                    if (!id.isNullOrBlank()) {
                        val name = optCleanString(c, "name")
                        val code = optCleanString(c, "code")
                        val room = optCleanString(c, "room")
                        coursesMap[id] = CourseInfo(
                            id = id,
                            name = name ?: (code ?: "Class"),
                            code = code ?: "",
                            room = room
                        )
                    }
                }
            }

            // 2. Read Slots
            val slotsList = mutableListOf<SlotInfo>()
            val classesByWeekday = mutableMapOf<Int, Int>() // 1..7 -> count
            val rawSlots = prefs.getString("flutter.ct_slots", null)
            if (!rawSlots.isNullOrBlank()) {
                val array = JSONArray(rawSlots)
                for (i in 0 until array.length()) {
                    val s = array.getJSONObject(i)
                    val weekday = s.optInt("weekday", 1).coerceIn(1, 7)
                    val slot = SlotInfo(
                        id = optCleanString(s, "id") ?: "",
                        courseId = optCleanString(s, "courseId") ?: "",
                        weekday = weekday,
                        startMinutes = s.optInt("startMinutes", 540),
                        endMinutes = s.optInt("endMinutes", 630),
                        room = optCleanString(s, "room")
                    )
                    slotsList.add(slot)
                    classesByWeekday[weekday] = (classesByWeekday[weekday] ?: 0) + 1
                }
            }

            // 3. Read Tasks
            val rawTasks = prefs.getString("flutter.ct_tasks", null)
            val pendingTasks = mutableListOf<JSONObject>()
            val tasksByDate = mutableMapOf<String, Int>()

            if (!rawTasks.isNullOrBlank()) {
                val array = JSONArray(rawTasks)
                for (i in 0 until array.length()) {
                    val task = array.getJSONObject(i)
                    val status = optCleanString(task, "status")
                    if (status != "completed") {
                        pendingTasks.add(task)
                        val dueDate = optCleanString(task, "dueDate")
                        if (!dueDate.isNullOrBlank()) {
                            tasksByDate[dueDate] = (tasksByDate[dueDate] ?: 0) + 1
                        }
                    }
                }
            }
            pendingTasks.sortBy { optCleanString(it, "dueDate") ?: "9999-99-99" }

            // 4. Calculate Current Week (Monday to Sunday)
            val nowCal = Calendar.getInstance()
            val nowWeekday = if (nowCal.get(Calendar.DAY_OF_WEEK) == Calendar.SUNDAY) 7 else nowCal.get(Calendar.DAY_OF_WEEK) - 1
            val nowMinutes = nowCal.get(Calendar.HOUR_OF_DAY) * 60 + nowCal.get(Calendar.MINUTE)

            val weekCal = Calendar.getInstance()
            weekCal.firstDayOfWeek = Calendar.MONDAY
            while (weekCal.get(Calendar.DAY_OF_WEEK) != Calendar.MONDAY) {
                weekCal.add(Calendar.DAY_OF_YEAR, -1)
            }

            val dateFmt = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            val dayNames = arrayOf("Mo", "Tu", "We", "Th", "Fr", "Sa", "Su")
            val weekDates = mutableListOf<String>()
            val weekDayNumbers = mutableListOf<Int>()
            val weekClassesCountList = mutableListOf<Int>()
            val weekTasksCountList = mutableListOf<Int>()
            var totalWeekClasses = 0
            var totalWeekTasks = 0

            for (i in 0 until 7) {
                val dateStr = dateFmt.format(weekCal.time)
                val weekdayNumber = i + 1 // 1 = Monday .. 7 = Sunday
                val dayClasses = classesByWeekday[weekdayNumber] ?: 0
                val dayTasks = tasksByDate[dateStr] ?: 0

                weekDates.add(dateStr)
                weekDayNumbers.add(weekCal.get(Calendar.DAY_OF_MONTH))
                weekClassesCountList.add(dayClasses)
                weekTasksCountList.add(dayTasks)

                totalWeekClasses += dayClasses
                totalWeekTasks += dayTasks
                weekCal.add(Calendar.DAY_OF_YEAR, 1)
            }

            // Summary text: e.g. "4 classes • 2 tasks" or "3 tasks" or "0 due this week"
            val summaryText = when {
                totalWeekClasses > 0 && totalWeekTasks > 0 -> "$totalWeekClasses classes • $totalWeekTasks tasks"
                totalWeekClasses > 0 -> "$totalWeekClasses classes this week"
                totalWeekTasks > 0 -> "$totalWeekTasks tasks this week"
                else -> "0 scheduled this week"
            }
            views.setTextViewText(R.id.widget_week_summary, summaryText)

            // Render Graphic Weekly Load Chart via Canvas
            try {
                val chartBitmap = drawWeeklyLoadChart(
                    weekDates = weekDates,
                    dayNames = dayNames,
                    dayNumbers = weekDayNumbers,
                    classesCounts = weekClassesCountList,
                    tasksCounts = weekTasksCountList
                )
                views.setImageViewBitmap(R.id.widget_chart_image, chartBitmap)
            } catch (e: Throwable) {
                e.printStackTrace()
            }

            val todayStr = dateFmt.format(Date())
            val tomorrowCal = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
            val tomorrowStr = dateFmt.format(tomorrowCal.time)

            // 5. Find Upcoming Class
            // Search in order:
            // a) remaining classes today (endMinutes > nowMinutes)
            // b) classes on subsequent weekdays this week / next cycle
            var nextSlot: SlotInfo? = null
            var nextSlotDayLabel = ""

            val todayRemaining = slotsList
                .filter { it.weekday == nowWeekday && it.endMinutes > nowMinutes }
                .sortedBy { it.startMinutes }

            if (todayRemaining.isNotEmpty()) {
                nextSlot = todayRemaining.first()
                nextSlotDayLabel = "Today"
            } else if (slotsList.isNotEmpty()) {
                // Find next weekday with classes
                for (offset in 1..7) {
                    val targetWeekday = ((nowWeekday - 1 + offset) % 7) + 1
                    val daySlots = slotsList
                        .filter { it.weekday == targetWeekday }
                        .sortedBy { it.startMinutes }
                    if (daySlots.isNotEmpty()) {
                        nextSlot = daySlots.first()
                        nextSlotDayLabel = if (offset == 1) "Tomorrow" else dayNames[targetWeekday - 1]
                        break
                    }
                }
            }

            if (nextSlot != null) {
                views.setViewVisibility(R.id.widget_class_container, View.VISIBLE)
                val course = coursesMap[nextSlot.courseId]
                val courseCode = course?.code?.takeIf { it.isNotBlank() && !it.equals("null", ignoreCase = true) }
                val courseName = course?.name?.takeIf { it.isNotBlank() && !it.equals("null", ignoreCase = true) }
                val displayTitle = courseCode ?: (courseName ?: "Class")
                views.setTextViewText(R.id.widget_class_title, displayTitle)

                val timeStr = "${formatTime(nextSlot.startMinutes)}–${formatTime(nextSlot.endMinutes)}"
                val roomStr = nextSlot.room?.takeIf { !it.equals("null", ignoreCase = true) }
                    ?: course?.room?.takeIf { !it.equals("null", ignoreCase = true) }
                val metaStr = if (!roomStr.isNullOrBlank()) {
                    "$nextSlotDayLabel • $timeStr • Rm $roomStr"
                } else {
                    "$nextSlotDayLabel • $timeStr"
                }
                views.setTextViewText(R.id.widget_class_meta, metaStr)
            } else {
                views.setViewVisibility(R.id.widget_class_container, View.GONE)
            }

            // 6. Find Upcoming Task
            if (pendingTasks.isNotEmpty()) {
                views.setViewVisibility(R.id.widget_task_container, View.VISIBLE)
                val t = pendingTasks[0]
                val taskTitle = optCleanString(t, "title") ?: "Upcoming Task"
                views.setTextViewText(R.id.widget_task_title, taskTitle)
                val type = formatType(optCleanString(t, "type") ?: "")
                val due = formatDue(optCleanString(t, "dueDate") ?: "", todayStr, tomorrowStr)
                views.setTextViewText(R.id.widget_task_meta, "$type • $due")
            } else {
                views.setViewVisibility(R.id.widget_task_container, View.GONE)
            }

            // 7. Empty State: Only visible if neither class nor task exists
            if (nextSlot == null && pendingTasks.isEmpty()) {
                views.setViewVisibility(R.id.widget_empty_text, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_empty_text, View.GONE)
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
        classesCounts: List<Int>,
        tasksCounts: List<Int>
    ): Bitmap {
        val width = 560
        val height = 160
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val totalCounts = weekDates.indices.map { classesCounts[it] + tasksCounts[it] }
        val maxCount = (totalCounts.maxOrNull() ?: 1).coerceAtLeast(1)

        val slotWidth = width / 7f
        val barWidth = 24f
        val maxBarHeight = 72f
        val chartBaseline = 110f

        val paintClassGold = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#C9962A") }
        val paintTaskRed = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#E05345") }
        val paintBarEmpty = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#26262B") }

        val paintDayName = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = 20f
            textAlign = Paint.Align.CENTER
        }
        val paintDayNumber = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = 17f
            textAlign = Paint.Align.CENTER
        }

        val dateFmt = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        val todayStr = dateFmt.format(Date())

        for (i in 0 until 7) {
            val classCount = classesCounts[i]
            val taskCount = tasksCounts[i]
            val totalForDay = classCount + taskCount
            val dateStr = weekDates[i]
            val centerX = slotWidth * i + (slotWidth / 2f)

            if (totalForDay > 0) {
                val totalH = (totalForDay.toFloat() / maxCount * maxBarHeight).coerceAtLeast(14f)
                val topY = chartBaseline - totalH

                if (classCount > 0 && taskCount > 0) {
                    // Stacked: Class on bottom, Task on top
                    val classH = (classCount.toFloat() / totalForDay) * totalH
                    val splitY = chartBaseline - classH

                    // Bottom portion: Class (Gold)
                    val classRect = RectF(centerX - barWidth / 2f, splitY, centerX + barWidth / 2f, chartBaseline)
                    canvas.drawRoundRect(classRect, 5f, 5f, paintClassGold)

                    // Top portion: Task (Red)
                    val taskRect = RectF(centerX - barWidth / 2f, topY, centerX + barWidth / 2f, splitY)
                    canvas.drawRoundRect(taskRect, 5f, 5f, paintTaskRed)
                } else if (classCount > 0) {
                    // Only Classes: Gold Bar
                    val rect = RectF(centerX - barWidth / 2f, topY, centerX + barWidth / 2f, chartBaseline)
                    canvas.drawRoundRect(rect, 6f, 6f, paintClassGold)
                } else {
                    // Only Tasks: Red Bar
                    val rect = RectF(centerX - barWidth / 2f, topY, centerX + barWidth / 2f, chartBaseline)
                    canvas.drawRoundRect(rect, 6f, 6f, paintTaskRed)
                }
            } else {
                // Empty day indicator
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

    private fun formatTime(minutes: Int): String {
        val h = (minutes / 60) % 24
        val m = minutes % 60
        val ampm = if (h >= 12) "PM" else "AM"
        val h12 = if (h % 12 == 0) 12 else h % 12
        return String.format(Locale.getDefault(), "%d:%02d %s", h12, m, ampm)
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
        fun optCleanString(obj: JSONObject, key: String, fallback: String? = null): String? {
            if (!obj.has(key) || obj.isNull(key)) return fallback
            val raw = obj.optString(key, fallback ?: "").trim()
            return if (raw.isEmpty() || raw.equals("null", ignoreCase = true)) fallback else raw
        }

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
