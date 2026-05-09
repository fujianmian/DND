package com.example.dnd_auto_app

import android.content.Context
import android.util.Log

data class AutomationDndState(
    val automationDndActive: Boolean,
    val activeAutomationRuleNames: String,
    val lastAutomationDndChangedAt: Long
)

object AutomationDndStateStore {
    private const val PREFS_NAME = "DndPrefs"
    private const val KEY_AUTOMATION_DND_ACTIVE = "automationDndActive"
    private const val KEY_ACTIVE_AUTOMATION_RULE_NAMES = "activeAutomationRuleNames"
    private const val KEY_LAST_AUTOMATION_DND_CHANGED_AT = "lastAutomationDndChangedAt"
    private const val TAG = "DndAutomationState"

    fun write(
        context: Context,
        automationDndActive: Boolean,
        activeAutomationRuleNames: String
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val previousActive = prefs.getBoolean(KEY_AUTOMATION_DND_ACTIVE, false)
        val previousRuleNames = prefs.getString(KEY_ACTIVE_AUTOMATION_RULE_NAMES, "") ?: ""
        val previousChangedAt = prefs.getLong(KEY_LAST_AUTOMATION_DND_CHANGED_AT, 0L)
        val changedAt =
            if (
                previousChangedAt == 0L ||
                previousActive != automationDndActive ||
                previousRuleNames != activeAutomationRuleNames
            ) {
                System.currentTimeMillis()
            } else {
                previousChangedAt
            }

        prefs
            .edit()
            .putBoolean(KEY_AUTOMATION_DND_ACTIVE, automationDndActive)
            .putString(KEY_ACTIVE_AUTOMATION_RULE_NAMES, activeAutomationRuleNames)
            .putLong(KEY_LAST_AUTOMATION_DND_CHANGED_AT, changedAt)
            .apply()

        if (previousActive != automationDndActive) {
            Log.d(
                TAG,
                "automationDndActive changed: $previousActive -> $automationDndActive, activeAutomationRuleNames=$activeAutomationRuleNames, changedAt=$changedAt"
            )
        }
        Log.d(
            TAG,
            "automationDndActive=$automationDndActive, activeAutomationRuleNames=$activeAutomationRuleNames, changedAt=$changedAt"
        )
    }

    fun read(context: Context): AutomationDndState {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return AutomationDndState(
            automationDndActive = prefs.getBoolean(KEY_AUTOMATION_DND_ACTIVE, false),
            activeAutomationRuleNames = prefs.getString(
                KEY_ACTIVE_AUTOMATION_RULE_NAMES,
                ""
            ) ?: "",
            lastAutomationDndChangedAt = prefs.getLong(
                KEY_LAST_AUTOMATION_DND_CHANGED_AT,
                0L
            )
        )
    }
}
