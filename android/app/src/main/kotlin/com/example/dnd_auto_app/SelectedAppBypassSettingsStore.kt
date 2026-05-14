package com.example.dnd_auto_app

import android.content.Context

data class SelectedAppBypassSettings(
    val enabled: Boolean,
    val packages: Set<String>
)

object SelectedAppBypassSettingsStore {
    private const val PREFS_NAME = "quietly_selected_app_bypass_prefs"
    private const val SELECTED_APP_BYPASS_ENABLED = "selectedAppBypassEnabled"
    private const val SELECTED_APP_BYPASS_PACKAGES = "selectedAppBypassPackages"

    fun read(context: Context): SelectedAppBypassSettings {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val packages = prefs.getStringSet(SELECTED_APP_BYPASS_PACKAGES, emptySet())
            ?: emptySet()

        return SelectedAppBypassSettings(
            enabled = prefs.getBoolean(SELECTED_APP_BYPASS_ENABLED, false),
            packages = packages.map { it.trim() }.filter { it.isNotEmpty() }.toSet()
        )
    }

    fun save(
        context: Context,
        enabled: Boolean,
        packages: Set<String>
    ) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(SELECTED_APP_BYPASS_ENABLED, enabled)
            .putStringSet(
                SELECTED_APP_BYPASS_PACKAGES,
                packages.map { it.trim() }.filter { it.isNotEmpty() }.toSet()
            )
            .apply()
    }
}
