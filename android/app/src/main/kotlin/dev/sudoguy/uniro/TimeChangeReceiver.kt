package dev.sudoguy.uniro

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Listens for system clock changes and records a reschedule flag that
 * Dart reads on next launch / resume via the device MethodChannel.
 * Does no scheduling itself, so it can never crash the app.
 */
class TimeChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        try {
            when (intent?.action) {
                Intent.ACTION_TIMEZONE_CHANGED,
                Intent.ACTION_TIME_CHANGED,
                Intent.ACTION_DATE_CHANGED -> {
                    context.getSharedPreferences(
                        "FlutterSharedPreferences",
                        Context.MODE_PRIVATE
                    ).edit()
                        .putBoolean("ct_needs_reschedule", true)
                        .putLong(
                            "ct_time_event_ms",
                            System.currentTimeMillis()
                        )
                        .apply()
                }
            }
        } catch (e: Throwable) {
            e.printStackTrace()
        }
    }
}
