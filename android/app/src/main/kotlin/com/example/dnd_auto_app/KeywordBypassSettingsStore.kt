package com.example.dnd_auto_app

import android.content.Context

data class KeywordBypassSettings(
    val enabled: Boolean,
    val keywords: Set<String>,
    val packages: Set<String>
)

object KeywordBypassSettingsStore {
    private const val PREFS_NAME = "quietly_keyword_bypass_prefs"
    private const val KEYWORD_BYPASS_ENABLED = "keywordBypassEnabled"
    private const val KEYWORD_BYPASS_KEYWORDS = "keywordBypassKeywords"
    private const val KEYWORD_BYPASS_PACKAGES = "keywordBypassPackages"

    private fun defaultKeywords(): Set<String> {
        return linkedSetOf("urgent", "emergency", "asap")
    }

    fun read(context: Context): KeywordBypassSettings {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val keywords = if (prefs.contains(KEYWORD_BYPASS_KEYWORDS)) {
            prefs.getStringSet(KEYWORD_BYPASS_KEYWORDS, emptySet()) ?: emptySet()
        } else {
            defaultKeywords()
        }
        val packages = prefs.getStringSet(KEYWORD_BYPASS_PACKAGES, emptySet()) ?: emptySet()

        return KeywordBypassSettings(
            enabled = prefs.getBoolean(KEYWORD_BYPASS_ENABLED, false),
            keywords = keywords.map { it.trim() }.filter { it.isNotEmpty() }.toSet(),
            packages = packages.map { it.trim() }.filter { it.isNotEmpty() }.toSet()
        )
    }
}
