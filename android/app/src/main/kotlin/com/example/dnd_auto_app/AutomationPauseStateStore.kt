package com.example.dnd_auto_app

import android.content.Context
import android.util.Log

data class AutomationPauseState(
    val automationPaused: Boolean,
    val pauseUntilMillis: Long,
    val pausedAtMillis: Long,
    val pauseReason: String
)

object AutomationPauseStateStore {
    private const val PREFS_NAME = "DndPrefs"
    private const val KEY_AUTOMATION_PAUSED = "automationPaused"
    private const val KEY_PAUSE_UNTIL_MILLIS = "pauseUntilMillis"
    private const val KEY_PAUSED_AT_MILLIS = "pausedAtMillis"
    private const val KEY_PAUSE_REASON = "pauseReason"
    private const val DEFAULT_PAUSE_REASON = "manual"
    private const val TAG = "DndAutomationPause"

    fun read(context: Context): AutomationPauseState {
        clearIfExpired(context)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val state = AutomationPauseState(
            automationPaused = prefs.getBoolean(KEY_AUTOMATION_PAUSED, false),
            pauseUntilMillis = prefs.getLong(KEY_PAUSE_UNTIL_MILLIS, 0L),
            pausedAtMillis = prefs.getLong(KEY_PAUSED_AT_MILLIS, 0L),
            pauseReason = prefs.getString(KEY_PAUSE_REASON, DEFAULT_PAUSE_REASON)
                ?: DEFAULT_PAUSE_REASON
        )
        Log.d(
            TAG,
            "Pause state read: paused=${state.automationPaused}, until=${state.pauseUntilMillis}, pausedAt=${state.pausedAtMillis}, reason=${state.pauseReason}"
        )
        return state
    }

    fun pause(context: Context, durationMillis: Long?) {
        val now = System.currentTimeMillis()
        val pauseUntilMillis = if (durationMillis != null && durationMillis > 0L) {
            now + durationMillis
        } else {
            0L
        }

        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_AUTOMATION_PAUSED, true)
            .putLong(KEY_PAUSE_UNTIL_MILLIS, pauseUntilMillis)
            .putLong(KEY_PAUSED_AT_MILLIS, now)
            .putString(KEY_PAUSE_REASON, DEFAULT_PAUSE_REASON)
            .apply()

        Log.d(
            TAG,
            "Pause requested: durationMillis=${durationMillis ?: "indefinite"}, pauseUntilMillis=$pauseUntilMillis, pausedAtMillis=$now"
        )
    }

    fun resume(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_AUTOMATION_PAUSED, false)
            .putLong(KEY_PAUSE_UNTIL_MILLIS, 0L)
            .putLong(KEY_PAUSED_AT_MILLIS, 0L)
            .putString(KEY_PAUSE_REASON, DEFAULT_PAUSE_REASON)
            .apply()

        Log.d(TAG, "Resume requested: pause state cleared.")
    }

    fun clearIfExpired(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val automationPaused = prefs.getBoolean(KEY_AUTOMATION_PAUSED, false)
        val pauseUntilMillis = prefs.getLong(KEY_PAUSE_UNTIL_MILLIS, 0L)
        val now = System.currentTimeMillis()

        if (!automationPaused || pauseUntilMillis <= 0L || now < pauseUntilMillis) {
            return false
        }

        prefs.edit()
            .putBoolean(KEY_AUTOMATION_PAUSED, false)
            .putLong(KEY_PAUSE_UNTIL_MILLIS, 0L)
            .putLong(KEY_PAUSED_AT_MILLIS, 0L)
            .putString(KEY_PAUSE_REASON, DEFAULT_PAUSE_REASON)
            .apply()

        Log.d(
            TAG,
            "Expired pause cleared: pauseUntilMillis=$pauseUntilMillis, now=$now"
        )
        return true
    }

    fun isPausedNow(context: Context): Boolean {
        clearIfExpired(context)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_AUTOMATION_PAUSED, false)
    }
}
