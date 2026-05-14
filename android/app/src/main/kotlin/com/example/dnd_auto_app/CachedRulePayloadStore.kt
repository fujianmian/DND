package com.example.dnd_auto_app

import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

object CachedRulePayloadStore {
    const val ACTION_RESTORE_FROM_CACHE = "com.example.dnd_auto_app.RESTORE_RULES_FROM_CACHE"
    private const val PREFS_NAME = "quietly_rule_payload_cache"
    private const val KEY_PAYLOAD_JSON = "payloadJson"
    private const val KEY_CACHED_AT = "cachedAt"
    private const val EXTRA_PAYLOAD_PRESENT = "quietlyRulePayloadPresent"

    private val STRING_ARRAY_KEYS = listOf(
        "timeRuleIds",
        "timeRuleNames",
        "locIds",
        "locNames",
        "appRuleIds",
        "appRuleNames",
        "appPackages",
        "activityRuleIds",
        "activityRuleNames",
        "activityTypes"
    )

    private val STRING_VALUE_KEYS = listOf("automationRulesJson", "calendarBusyWindowsJson")

    private val INT_ARRAY_KEYS = listOf(
        "startHours",
        "startMinutes",
        "endHours",
        "endMinutes",
        "timeRepeatModes",
        "timeRepeatDaysMasks",
        "rads"
    )

    private val DOUBLE_ARRAY_KEYS = listOf("lats", "lngs")

    private val BOOLEAN_ARRAY_KEYS = listOf(
        "timeAllowStarredContacts",
        "timeAllowRepeatCallers",
        "locAllowStarredContacts",
        "locAllowRepeatCallers",
        "appAllowStarredContacts",
        "appAllowRepeatCallers",
        "activityAllowStarredContacts",
        "activityAllowRepeatCallers"
    )

    fun markPayloadPresent(intent: Intent) {
        intent.putExtra(EXTRA_PAYLOAD_PRESENT, true)
    }

    fun hasRulePayload(intent: Intent?): Boolean {
        if (intent == null) return false
        if (intent.getBooleanExtra(EXTRA_PAYLOAD_PRESENT, false)) return true
        return (STRING_ARRAY_KEYS + STRING_VALUE_KEYS + INT_ARRAY_KEYS + DOUBLE_ARRAY_KEYS + BOOLEAN_ARRAY_KEYS)
            .any { intent.hasExtra(it) }
    }

    fun saveFromIntent(context: Context, intent: Intent) {
        val payload = JSONObject()
        STRING_ARRAY_KEYS.forEach { key ->
            payload.put(key, JSONArray(intent.getStringArrayExtra(key)?.toList() ?: emptyList<String>()))
        }
        STRING_VALUE_KEYS.forEach { key ->
            payload.put(key, intent.getStringExtra(key) ?: "")
        }
        INT_ARRAY_KEYS.forEach { key ->
            payload.put(key, JSONArray((intent.getIntArrayExtra(key) ?: intArrayOf()).toList()))
        }
        DOUBLE_ARRAY_KEYS.forEach { key ->
            payload.put(key, JSONArray((intent.getDoubleArrayExtra(key) ?: doubleArrayOf()).toList()))
        }
        BOOLEAN_ARRAY_KEYS.forEach { key ->
            payload.put(key, JSONArray((intent.getBooleanArrayExtra(key) ?: booleanArrayOf()).toList()))
        }

        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PAYLOAD_JSON, payload.toString())
            .putLong(KEY_CACHED_AT, System.currentTimeMillis())
            .apply()

        Log.d(
            "DndRuleCache",
            "Rule payload cached: time=${intent.getStringArrayExtra("timeRuleIds")?.size ?: 0}, location=${intent.getStringArrayExtra("locIds")?.size ?: 0}, app=${intent.getStringArrayExtra("appRuleIds")?.size ?: 0}, activity=${intent.getStringArrayExtra("activityRuleIds")?.size ?: 0}, groupedJsonLength=${intent.getStringExtra("automationRulesJson")?.length ?: 0}, calendarJsonLength=${intent.getStringExtra("calendarBusyWindowsJson")?.length ?: 0}"
        )
    }

    fun restoreIntent(context: Context): Intent? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val payloadText = prefs.getString(KEY_PAYLOAD_JSON, null)
        if (payloadText.isNullOrBlank()) {
            Log.w("DndRuleCache", "No cached rule payload found.")
            return null
        }

        return try {
            val payload = JSONObject(payloadText)
            Intent(context, DndForegroundService::class.java).apply {
                action = ACTION_RESTORE_FROM_CACHE
                markPayloadPresent(this)
                STRING_ARRAY_KEYS.forEach { key ->
                    putExtra(key, payload.optJSONArray(key).toStringArray())
                }
                STRING_VALUE_KEYS.forEach { key ->
                    putExtra(key, payload.optString(key, ""))
                }
                INT_ARRAY_KEYS.forEach { key ->
                    putExtra(key, payload.optJSONArray(key).toIntArray())
                }
                DOUBLE_ARRAY_KEYS.forEach { key ->
                    putExtra(key, payload.optJSONArray(key).toDoubleArray())
                }
                BOOLEAN_ARRAY_KEYS.forEach { key ->
                    putExtra(key, payload.optJSONArray(key).toBooleanArray())
                }
            }.also {
                Log.d(
                    "DndRuleCache",
                    "Cached rule payload restored: cachedAt=${prefs.getLong(KEY_CACHED_AT, 0L)}, location=${it.getStringArrayExtra("locIds")?.size ?: 0}, groupedJsonLength=${it.getStringExtra("automationRulesJson")?.length ?: 0}, calendarJsonLength=${it.getStringExtra("calendarBusyWindowsJson")?.length ?: 0}"
                )
            }
        } catch (e: Exception) {
            Log.e("DndRuleCache", "Failed to restore cached rule payload: exception=${e::class.java.simpleName}, message=${e.message}")
            null
        }
    }

    private fun JSONArray?.toStringArray(): Array<String> {
        if (this == null) return emptyArray()
        return Array(length()) { index -> optString(index) }
    }

    private fun JSONArray?.toIntArray(): IntArray {
        if (this == null) return intArrayOf()
        return IntArray(length()) { index -> optInt(index) }
    }

    private fun JSONArray?.toDoubleArray(): DoubleArray {
        if (this == null) return doubleArrayOf()
        return DoubleArray(length()) { index -> optDouble(index) }
    }

    private fun JSONArray?.toBooleanArray(): BooleanArray {
        if (this == null) return booleanArrayOf()
        return BooleanArray(length()) { index -> optBoolean(index) }
    }
}
