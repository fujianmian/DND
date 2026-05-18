package com.example.dnd_auto_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.Location
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import java.util.Calendar
import java.util.Timer
import java.util.TimerTask
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityRecognitionClient
import com.google.android.gms.location.DetectedActivity
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Locale

const val MATCH_TYPE_ANY = 0
const val MATCH_TYPE_ALL = 1
const val TRIGGER_TYPE_TIME = 0
const val TRIGGER_TYPE_LOCATION = 1
const val TRIGGER_TYPE_APP = 2
const val TRIGGER_TYPE_ACTIVITY = 3
const val TRIGGER_TYPE_CALENDAR = 4
const val DEFAULT_RULE_PRIORITY = 50
const val REPEAT_EVERY_DAY = 0
const val REPEAT_WEEKDAYS = 1
const val REPEAT_WEEKENDS = 2
const val REPEAT_CUSTOM = 3
const val MASK_EVERY_DAY = 127
const val MASK_WEEKDAYS = 31
const val MASK_WEEKENDS = 96

data class DndRule(
    val id: String,
    val name: String,
    val startHour: Int,
    val startMinute: Int,
    val endHour: Int,
    val endMinute: Int,
    val timeRepeatMode: Int,
    val timeRepeatDaysMask: Int,
    val allowStarredContacts: Boolean,
    val allowRepeatCallers: Boolean
)

data class DndLocationRule(
    val id: String,
    val name: String,
    val latitude: Double,
    val longitude: Double,
    val radius: Int,
    val allowStarredContacts: Boolean,
    val allowRepeatCallers: Boolean
)

data class DndAppRule(
    val id: String,
    val name: String,
    val packageName: String,
    val allowStarredContacts: Boolean,
    val allowRepeatCallers: Boolean
)

data class DndActivityRule(
    val id: String,
    val name: String,
    val activityType: String,
    val confidenceThreshold: Int,
    val allowStarredContacts: Boolean,
    val allowRepeatCallers: Boolean
)

data class AutomationRule(
    val id: String,
    val name: String,
    val enabled: Boolean,
    val matchType: Int,
    val priority: Int,
    val allowStarredContacts: Boolean,
    val allowRepeatCallers: Boolean,
    val triggers: List<AutomationTrigger>
)

data class AutomationTrigger(
    val id: String,
    val triggerType: Int,
    val enabled: Boolean,
    val startHour: Int?,
    val startMinute: Int?,
    val endHour: Int?,
    val endMinute: Int?,
    val timeRepeatMode: Int,
    val timeRepeatDaysMask: Int,
    val latitude: Double?,
    val longitude: Double?,
    val radius: Int?,
    val packageName: String?,
    val activityType: String?,
    val activityConfidenceThreshold: Int
)

data class CalendarBusyWindow(
    val triggerId: String,
    val startMillis: Long,
    val endMillis: Long,
    val isAllDay: Boolean,
    val keywordMatched: Boolean,
    val fetchedAt: Long
)

class DndForegroundService : Service() {

    private val CHANNEL_ID = "DndServiceChannel"
    private val DND_DISABLE_GRACE_MS = 3000L
    private val APP_FOREGROUND_HOLD_MS = 90 * 1000L
    private val LOCATION_REFRESH_INTERVAL_MS = 15 * 1000L
    private val LOCATION_EXIT_BUFFER_MIN_METERS = 25f
    private val LOCATION_ENTER_BUFFER_MAX_METERS = 50f
    private val activeNotificationTitle = "DND Automation Active"
    private val inactiveNotificationTitle = "Quietly is monitoring"
    private val inactiveNotificationText = "No automation rule is active"
    private val pausedNotificationTitle = "Quietly automation paused"
    private var timer: Timer? = null
    private val disableGraceHandler = Handler(Looper.getMainLooper())
    private var pendingDisableRunnable: Runnable? = null
    private var activeRules: List<DndRule> = emptyList()
    private var activeLocationRules: List<DndLocationRule> = emptyList()
    private var targetAppRules: List<DndAppRule> = emptyList()
    private var targetActivityRules: List<DndActivityRule> = emptyList()
    private var groupedAutomationRules: List<AutomationRule> = emptyList()
    private var calendarBusyWindows: List<CalendarBusyWindow> = emptyList()
    private var notificationMonitoringText: String = inactiveNotificationText
    private var targetAppPackages: Array<String> = emptyArray() // Track App Triggers
    private var targetActivityTypes: Array<String> = emptyArray() // Track Activity Triggers
    private var lastConfirmedForegroundPackage: String? = null
    private var lastConfirmedForegroundAtMillis: Long = 0L
    private var lastMatchedAppPackage: String? = null
    private var lastMatchedAppAtMillis: Long = 0L
    private var lastLocationRefreshRequestedAtMillis: Long = 0L
    private var lastActivityRecognitionRegisterRequestedAtMillis: Long = 0L
    private var activityRecognitionShouldMonitor: Boolean = false
    private lateinit var activityRecognitionClient: ActivityRecognitionClient
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    
    private lateinit var geofencingClient: GeofencingClient

    companion object {
        const val ACTION_EVALUATE_DND = "com.example.dnd_auto_app.EVALUATE_DND"
        var isInsideGeofence: Boolean = false // Track location state globally
    }

    private val geofenceUpdateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            android.util.Log.d("DndActivity", "Internal DND evaluation broadcast received: action=${intent?.action}")
            checkAndToggleDnd("internal-broadcast")
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        geofencingClient = LocationServices.getGeofencingClient(this)
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        activityRecognitionClient = ActivityRecognition.getClient(this)

        // Listen for internal broadcasts from the GeofenceBroadcastReceiver
        val filter = IntentFilter(ACTION_EVALUATE_DND)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(geofenceUpdateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(geofenceUpdateReceiver, filter)
        }
    }

    private fun stringAt(values: Array<String>, index: Int, fallback: String): String {
        return values.getOrNull(index) ?: fallback
    }

    private fun boolAt(values: BooleanArray, index: Int): Boolean {
        return values.getOrNull(index) ?: false
    }

    private fun intAt(values: IntArray, index: Int, fallback: Int): Int {
        return values.getOrNull(index) ?: fallback
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val ruleIntent = resolveRulePayloadIntent(intent)
        val hasResolvedRulePayload = ruleIntent != null
        val automationRulesJson = ruleIntent?.getStringExtra("automationRulesJson")
        groupedAutomationRules = parseGroupedAutomationRules(automationRulesJson)
        val calendarBusyWindowsJson = ruleIntent?.getStringExtra("calendarBusyWindowsJson")
        calendarBusyWindows = parseCalendarBusyWindows(calendarBusyWindowsJson)
        android.util.Log.d(
            "DndCalendar",
            "Calendar cache refresh/sync received: hasCalendarPayload=${calendarBusyWindowsJson != null}, nativeWindowCount=${calendarBusyWindows.size}, payloadLength=${calendarBusyWindowsJson?.length ?: 0}"
        )
        val groupedTriggerCount = groupedAutomationRules.sumOf { it.triggers.size }
        android.util.Log.d(
            "DndGroupedRules",
            "Grouped rules stored: rules=${groupedAutomationRules.size}, triggers=$groupedTriggerCount, calendarWindows=${calendarBusyWindows.size}"
        )

        // 1. Reconstruct Time Rules
        val startHours = ruleIntent?.getIntArrayExtra("startHours") ?: intArrayOf()
        val startMinutes = ruleIntent?.getIntArrayExtra("startMinutes") ?: intArrayOf()
        val endHours = ruleIntent?.getIntArrayExtra("endHours") ?: intArrayOf()
        val endMinutes = ruleIntent?.getIntArrayExtra("endMinutes") ?: intArrayOf()
        val timeRepeatModes = ruleIntent?.getIntArrayExtra("timeRepeatModes") ?: intArrayOf()
        val timeRepeatDaysMasks = ruleIntent?.getIntArrayExtra("timeRepeatDaysMasks") ?: intArrayOf()
        val timeRuleIds = ruleIntent?.getStringArrayExtra("timeRuleIds") ?: emptyArray()
        val timeRuleNames = ruleIntent?.getStringArrayExtra("timeRuleNames") ?: emptyArray()
        val timeAllowStarredContacts = ruleIntent?.getBooleanArrayExtra("timeAllowStarredContacts") ?: booleanArrayOf()
        val timeAllowRepeatCallers = ruleIntent?.getBooleanArrayExtra("timeAllowRepeatCallers") ?: booleanArrayOf()

        val newRules = mutableListOf<DndRule>()
        for (i in startHours.indices) {
            newRules.add(
                DndRule(
                    stringAt(timeRuleIds, i, i.toString()),
                    stringAt(timeRuleNames, i, "Time rule ${i + 1}"),
                    startHours[i],
                    startMinutes[i],
                    endHours[i],
                    endMinutes[i],
                    intAt(timeRepeatModes, i, REPEAT_EVERY_DAY),
                    intAt(timeRepeatDaysMasks, i, MASK_EVERY_DAY),
                    boolAt(timeAllowStarredContacts, i),
                    boolAt(timeAllowRepeatCallers, i)
                )
            )
        }
        activeRules = newRules

        // 2. Extract Location Rules
        val locIds = ruleIntent?.getStringArrayExtra("locIds") ?: emptyArray()
        val locNames = ruleIntent?.getStringArrayExtra("locNames") ?: emptyArray()
        val lats = ruleIntent?.getDoubleArrayExtra("lats") ?: doubleArrayOf()
        val lngs = ruleIntent?.getDoubleArrayExtra("lngs") ?: doubleArrayOf()
        val rads = ruleIntent?.getIntArrayExtra("rads") ?: intArrayOf()
        val locAllowStarredContacts = ruleIntent?.getBooleanArrayExtra("locAllowStarredContacts") ?: booleanArrayOf()
        val locAllowRepeatCallers = ruleIntent?.getBooleanArrayExtra("locAllowRepeatCallers") ?: booleanArrayOf()
        val flatLocationRules = locIds.indices.map { i ->
            DndLocationRule(
                locIds[i],
                stringAt(locNames, i, "Location rule ${i + 1}"),
                lats.getOrNull(i) ?: 0.0,
                lngs.getOrNull(i) ?: 0.0,
                rads.getOrNull(i) ?: 0,
                boolAt(locAllowStarredContacts, i),
                boolAt(locAllowRepeatCallers, i)
            )
        }
        val groupedLocationRules = groupedLocationRulesForFlatEvaluator()
        val shouldUseGroupedGeofences = groupedLocationRules.isNotEmpty()
        activeLocationRules = if (shouldUseGroupedGeofences) groupedLocationRules else flatLocationRules

        if (hasResolvedRulePayload) {
            if (shouldUseGroupedGeofences) {
                android.util.Log.d(
                    "DndGeofence",
                    "Geofence registration source=grouped, locationTriggers=${groupedLocationRules.size}. Request IDs are trigger IDs."
                )
                setupGeofences(
                    groupedLocationRules.map { it.id }.toTypedArray(),
                    groupedLocationRules.map { it.latitude }.toDoubleArray(),
                    groupedLocationRules.map { it.longitude }.toDoubleArray(),
                    groupedLocationRules.map { it.radius }.toIntArray()
                )
            } else {
                android.util.Log.d(
                    "DndGeofence",
                    "Geofence registration source=flat fallback, locationRules=${locIds.size}"
                )
                setupGeofences(locIds, lats, lngs, rads)
            }
        } else {
            android.util.Log.w(
                "DndRuleCache",
                "No valid rule payload available during service start. Existing geofence registrations were left untouched."
            )
        }

        // 3. Extract App Usage Rules
        targetAppPackages = ruleIntent?.getStringArrayExtra("appPackages") ?: emptyArray()
        val appRuleIds = ruleIntent?.getStringArrayExtra("appRuleIds") ?: emptyArray()
        val appRuleNames = ruleIntent?.getStringArrayExtra("appRuleNames") ?: emptyArray()
        val appAllowStarredContacts = ruleIntent?.getBooleanArrayExtra("appAllowStarredContacts") ?: booleanArrayOf()
        val appAllowRepeatCallers = ruleIntent?.getBooleanArrayExtra("appAllowRepeatCallers") ?: booleanArrayOf()
        targetAppRules = targetAppPackages.indices.map { i ->
            DndAppRule(
                stringAt(appRuleIds, i, i.toString()),
                stringAt(appRuleNames, i, "App rule ${i + 1}"),
                targetAppPackages[i],
                boolAt(appAllowStarredContacts, i),
                boolAt(appAllowRepeatCallers, i)
            )
        }

        // 4. Extract Activity Rules & Setup
        targetActivityTypes = ruleIntent?.getStringArrayExtra("activityTypes") ?: emptyArray()
        val activityRuleIds = ruleIntent?.getStringArrayExtra("activityRuleIds") ?: emptyArray()
        val activityRuleNames = ruleIntent?.getStringArrayExtra("activityRuleNames") ?: emptyArray()
        val activityAllowStarredContacts = ruleIntent?.getBooleanArrayExtra("activityAllowStarredContacts") ?: booleanArrayOf()
        val activityAllowRepeatCallers = ruleIntent?.getBooleanArrayExtra("activityAllowRepeatCallers") ?: booleanArrayOf()
        val activityConfidenceThresholds = ruleIntent?.getIntArrayExtra("activityConfidenceThresholds") ?: intArrayOf()
        targetActivityRules = targetActivityTypes.indices.map { i ->
            DndActivityRule(
                stringAt(activityRuleIds, i, i.toString()),
                stringAt(activityRuleNames, i, "Activity rule ${i + 1}"),
                targetActivityTypes[i],
                normalizeActivityConfidenceThreshold(intAt(activityConfidenceThresholds, i, DEFAULT_ACTIVITY_CONFIDENCE_THRESHOLD)),
                boolAt(activityAllowStarredContacts, i),
                boolAt(activityAllowRepeatCallers, i)
            )
        }
        if (hasResolvedRulePayload) {
            val groupedActivityTriggerCount = groupedAutomationRules.sumOf { rule ->
                rule.triggers.count { it.enabled && it.triggerType == TRIGGER_TYPE_ACTIVITY }
            }
            val shouldMonitorActivity = targetActivityTypes.isNotEmpty() || groupedActivityTriggerCount > 0
            android.util.Log.d(
                "DndActivity",
                "Activity trigger sync received: flat=${targetActivityTypes.size}, grouped=$groupedActivityTriggerCount, shouldMonitor=$shouldMonitorActivity"
            )
            setupActivityRecognition(shouldMonitorActivity)
        }

        logSyncedRuleExceptions()
        notificationMonitoringText = monitoringNotificationText(locIds)

        // 5. Foreground Notification (Combined correctly)
        val notification = buildForegroundNotification(
            inactiveNotificationTitle,
            notificationMonitoringText
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(1, notification)
        }

        // 6. Start loop
        timer?.cancel()
        startAutomationLoop()

        return START_REDELIVER_INTENT 
    }

    private fun resolveRulePayloadIntent(intent: Intent?): Intent? {
        val action = intent?.action
        val hasPayload = CachedRulePayloadStore.hasRulePayload(intent)
        android.util.Log.d(
            "DndRuleCache",
            "Service start payload check: action=$action, hasPayload=$hasPayload"
        )

        if (hasPayload && intent != null) {
            CachedRulePayloadStore.saveFromIntent(this, intent)
            android.util.Log.d("DndRuleCache", "Using rule payload from service intent. Intentional empty sync is allowed.")
            return intent
        }

        android.util.Log.d("DndRuleCache", "Restore requested because service intent has no rule payload.")
        val restoredIntent = CachedRulePayloadStore.restoreIntent(this)
        if (restoredIntent != null) {
            android.util.Log.d(
                "DndRuleCache",
                "Cached rule payload restored for service start: location=${restoredIntent.getStringArrayExtra("locIds")?.size ?: 0}, groupedJsonLength=${restoredIntent.getStringExtra("automationRulesJson")?.length ?: 0}, calendarJsonLength=${restoredIntent.getStringExtra("calendarBusyWindowsJson")?.length ?: 0}"
            )
        }
        return restoredIntent
    }

    private fun logSyncedRuleExceptions() {
        activeRules.forEach {
            android.util.Log.d(
                "DndExceptions",
                "Time rule received: id=${it.id}, name=${it.name}, timeRepeatMode=${it.timeRepeatMode}, timeRepeatMask=${it.timeRepeatDaysMask}, starred=${it.allowStarredContacts}, repeat=${it.allowRepeatCallers}"
            )
        }
        activeLocationRules.forEach {
            android.util.Log.d(
                "DndExceptions",
                "Location rule received: id=${it.id}, name=${it.name}, starred=${it.allowStarredContacts}, repeat=${it.allowRepeatCallers}"
            )
        }
        targetAppRules.forEach {
            android.util.Log.d(
                "DndExceptions",
                "App rule received: id=${it.id}, name=${it.name}, package=${it.packageName}, starred=${it.allowStarredContacts}, repeat=${it.allowRepeatCallers}"
            )
        }
        targetActivityRules.forEach {
            android.util.Log.d(
                "DndExceptions",
                "Activity rule received: id=${it.id}, name=${it.name}, activity=${it.activityType}, threshold=${it.confidenceThreshold}, starred=${it.allowStarredContacts}, repeat=${it.allowRepeatCallers}"
            )
        }
    }

    private fun monitoringNotificationText(locIds: Array<String>): String {
        if (groupedAutomationRules.isNotEmpty()) {
            android.util.Log.d(
                "DndActivity",
                "Foreground notification inactive state: monitoring ${groupedAutomationRules.size} grouped automation rule(s)"
            )
        } else {
            android.util.Log.d(
                "DndActivity",
                "Foreground notification inactive state: monitoring ${activeRules.size} time(s), ${locIds.size} loc(s), ${targetAppPackages.size} app(s) & ${targetActivityTypes.size} act(s)"
            )
        }
        return inactiveNotificationText
    }

    private fun notificationTitleForDecision(shouldBeActive: Boolean): String {
        return if (shouldBeActive) activeNotificationTitle else inactiveNotificationTitle
    }

    private fun notificationTextForDecision(
        shouldBeActive: Boolean,
        matchingRuleNames: List<String>
    ): String {
        if (!shouldBeActive) return notificationMonitoringText

        val activeRuleNames = matchingRuleNames
            .filter { it.isNotBlank() }
            .distinct()

        return if (activeRuleNames.isEmpty()) {
            "Automation active"
        } else if (activeRuleNames.size == 1) {
            "Active: ${activeRuleNames.first()}"
        } else {
            "Active: ${activeRuleNames.first()} + ${activeRuleNames.size - 1} more"
        }
    }

    private fun buildForegroundNotification(title: String, contentText: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(contentText)
            .setSmallIcon(R.drawable.ic_quietly_notification)
            .setOngoing(true)
            .build()
    }

    private fun updateForegroundNotification(title: String, contentText: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(1, buildForegroundNotification(title, contentText))
        android.util.Log.d(
            "DndActivity",
            "Foreground notification updated: title=$title, contentText=$contentText"
        )
    }

    private fun parseGroupedAutomationRules(automationRulesJson: String?): List<AutomationRule> {
        if (automationRulesJson.isNullOrBlank()) {
            android.util.Log.d("DndGroupedRules", "automationRulesJson missing or blank; grouped rules unavailable.")
            return emptyList()
        }

        android.util.Log.d(
            "DndGroupedRules",
            "automationRulesJson present: length=${automationRulesJson.length}"
        )

        return try {
            val rulesJson = JSONArray(automationRulesJson)
            val parsedRules = mutableListOf<AutomationRule>()
            var skippedRules = 0
            var skippedTriggers = 0

            for (ruleIndex in 0 until rulesJson.length()) {
                val ruleJson = rulesJson.optJSONObject(ruleIndex)
                if (ruleJson == null) {
                    skippedRules += 1
                    android.util.Log.w("DndGroupedRules", "Skipping invalid grouped rule at index=$ruleIndex: not an object.")
                    continue
                }

                val ruleId = ruleJson.optString("id").takeIf { it.isNotBlank() }
                val ruleName = ruleJson.optString("name").takeIf { it.isNotBlank() }
                if (ruleId == null || ruleName == null) {
                    skippedRules += 1
                    android.util.Log.w(
                        "DndGroupedRules",
                        "Skipping invalid grouped rule at index=$ruleIndex: hasId=${ruleId != null}, hasName=${ruleName != null}."
                    )
                    continue
                }

                val triggersJson = ruleJson.optJSONArray("triggers")
                if (triggersJson == null) {
                    skippedRules += 1
                    android.util.Log.w("DndGroupedRules", "Skipping grouped rule $ruleId ($ruleName): triggers array missing.")
                    continue
                }

                val triggers = mutableListOf<AutomationTrigger>()
                for (triggerIndex in 0 until triggersJson.length()) {
                    val triggerJson = triggersJson.optJSONObject(triggerIndex)
                    if (triggerJson == null) {
                        skippedTriggers += 1
                        android.util.Log.w(
                            "DndGroupedRules",
                            "Skipping invalid trigger for rule $ruleId at index=$triggerIndex: not an object."
                        )
                        continue
                    }

                    val trigger = parseGroupedAutomationTrigger(ruleId, triggerIndex, triggerJson)
                    if (trigger == null) {
                        skippedTriggers += 1
                    } else {
                        triggers.add(trigger)
                    }
                }

                parsedRules.add(
                    AutomationRule(
                        id = ruleId,
                        name = ruleName,
                        enabled = ruleJson.optBoolean("enabled", true),
                        matchType = parseMatchType(
                            ruleId,
                            ruleJson.optInt("matchType", MATCH_TYPE_ANY)
                        ),
                        priority = parsePriority(ruleId, ruleJson),
                        allowStarredContacts = ruleJson.optBoolean("allowStarredContacts", false),
                        allowRepeatCallers = ruleJson.optBoolean("allowRepeatCallers", false),
                        triggers = triggers
                    )
                )
            }

            val triggerCount = parsedRules.sumOf { it.triggers.size }
            android.util.Log.d(
                "DndGroupedRules",
                "automationRulesJson parsed successfully: rules=${parsedRules.size}, triggers=$triggerCount, skippedRules=$skippedRules, skippedTriggers=$skippedTriggers"
            )
            parsedRules
        } catch (e: Exception) {
            android.util.Log.e(
                "DndGroupedRules",
                "Failed to parse automationRulesJson; flat payload fallback remains active. exception=${e::class.java.simpleName}, message=${e.message}"
            )
            emptyList()
        }
    }

    private fun parseGroupedAutomationTrigger(
        ruleId: String,
        triggerIndex: Int,
        triggerJson: JSONObject
    ): AutomationTrigger? {
        val triggerId = triggerJson.optString("id").takeIf { it.isNotBlank() }
        if (triggerId == null || !triggerJson.has("triggerType") || !triggerJson.has("enabled")) {
            android.util.Log.w(
                "DndGroupedRules",
                "Skipping invalid trigger for rule $ruleId at index=$triggerIndex: hasId=${triggerId != null}, hasTriggerType=${triggerJson.has("triggerType")}, hasEnabled=${triggerJson.has("enabled")}."
            )
            return null
        }

        val triggerType = triggerJson.optInt("triggerType", -1)
        if (triggerType !in TRIGGER_TYPE_TIME..TRIGGER_TYPE_CALENDAR) {
            android.util.Log.w(
                "DndGroupedRules",
                "Skipping invalid trigger $triggerId for rule $ruleId: triggerType=$triggerType."
            )
            return null
        }
        val rawRepeatMode = triggerJson.optInt("timeRepeatMode", REPEAT_EVERY_DAY)
        val timeRepeatMode = normalizeTimeRepeatMode(rawRepeatMode)
        val rawRepeatMask = if (triggerJson.has("timeRepeatDaysMask") && !triggerJson.isNull("timeRepeatDaysMask")) {
            triggerJson.optInt("timeRepeatDaysMask")
        } else {
            maskForRepeatMode(timeRepeatMode)
        }
        val timeRepeatDaysMask = normalizedMaskForRepeatMode(timeRepeatMode, rawRepeatMask)
        if (triggerType == TRIGGER_TYPE_TIME && timeRepeatMode == REPEAT_CUSTOM && timeRepeatDaysMask == 0) {
            android.util.Log.w(
                "DndGroupedRules",
                "Grouped time trigger has custom repeat with no selected days: triggerId=$triggerId, ruleId=$ruleId."
            )
        }

        return AutomationTrigger(
            id = triggerId,
            triggerType = triggerType,
            enabled = triggerJson.optBoolean("enabled", true),
            startHour = optionalInt(triggerJson, "startHour"),
            startMinute = optionalInt(triggerJson, "startMinute"),
            endHour = optionalInt(triggerJson, "endHour"),
            endMinute = optionalInt(triggerJson, "endMinute"),
            timeRepeatMode = timeRepeatMode,
            timeRepeatDaysMask = timeRepeatDaysMask,
            latitude = optionalDouble(triggerJson, "latitude"),
            longitude = optionalDouble(triggerJson, "longitude"),
            radius = optionalInt(triggerJson, "radius"),
            packageName = optionalString(triggerJson, "packageName"),
            activityType = optionalString(triggerJson, "activityType"),
            activityConfidenceThreshold = normalizeActivityConfidenceThreshold(
                optionalInt(triggerJson, "confidenceThreshold")
            )
        )
    }

    private fun parseCalendarBusyWindows(calendarBusyWindowsJson: String?): List<CalendarBusyWindow> {
        if (calendarBusyWindowsJson.isNullOrBlank()) {
            android.util.Log.d("DndCalendar", "calendarBusyWindowsJson missing or blank; no cached calendar windows.")
            return emptyList()
        }

        return try {
            val windowsJson = JSONArray(calendarBusyWindowsJson)
            val windows = mutableListOf<CalendarBusyWindow>()
            var skippedWindows = 0
            var allDayWindowCount = 0

            for (index in 0 until windowsJson.length()) {
                val windowJson = windowsJson.optJSONObject(index)
                if (windowJson == null) {
                    skippedWindows += 1
                    continue
                }

                val triggerId = windowJson.optString("triggerId").takeIf { it.isNotBlank() }
                val startMillis = windowJson.optLong("startMillis", 0L)
                val endMillis = windowJson.optLong("endMillis", 0L)
                if (triggerId == null || startMillis <= 0L || endMillis <= startMillis) {
                    skippedWindows += 1
                    android.util.Log.w(
                        "DndCalendar",
                        "Skipping invalid calendar window at index=$index: hasTriggerId=${triggerId != null}, startMillis=$startMillis, endMillis=$endMillis"
                    )
                    continue
                }

                windows.add(
                    CalendarBusyWindow(
                        triggerId = triggerId,
                        startMillis = startMillis,
                        endMillis = endMillis,
                        isAllDay = windowJson.optBoolean("isAllDay", false),
                        keywordMatched = windowJson.optBoolean("keywordMatched", true),
                        fetchedAt = windowJson.optLong("fetchedAt", 0L)
                    )
                )
                if (windowJson.optBoolean("isAllDay", false)) {
                    allDayWindowCount += 1
                    android.util.Log.d(
                        "DndCalendar",
                        "Parsed all-day calendar window: triggerId=$triggerId, startMillis=$startMillis, endMillis=$endMillis"
                    )
                }
            }

            android.util.Log.d(
                "DndCalendar",
                "calendarBusyWindowsJson parsed: windows=${windows.size}, allDayWindows=$allDayWindowCount, skipped=$skippedWindows"
            )
            windows
        } catch (e: Exception) {
            android.util.Log.e(
                "DndCalendar",
                "Failed to parse calendarBusyWindowsJson; calendar triggers inactive. exception=${e::class.java.simpleName}, message=${e.message}"
            )
            emptyList()
        }
    }

    private fun parseMatchType(ruleId: String, matchType: Int): Int {
        if (matchType == MATCH_TYPE_ANY || matchType == MATCH_TYPE_ALL) return matchType
        android.util.Log.w(
            "DndGroupedRules",
            "Unknown matchType=$matchType for grouped rule $ruleId; falling back to ANY."
        )
        return MATCH_TYPE_ANY
    }

    private fun parsePriority(ruleId: String, ruleJson: JSONObject): Int {
        if (!ruleJson.has("priority") || ruleJson.isNull("priority")) {
            android.util.Log.d(
                "DndGroupedRules",
                "Grouped rule $ruleId missing priority; defaulting to $DEFAULT_RULE_PRIORITY."
            )
            return DEFAULT_RULE_PRIORITY
        }

        val priority = ruleJson.optInt("priority", DEFAULT_RULE_PRIORITY)
        if (priority <= 0) {
            android.util.Log.w(
                "DndGroupedRules",
                "Grouped rule $ruleId has invalid priority=$priority; defaulting to $DEFAULT_RULE_PRIORITY."
            )
            return DEFAULT_RULE_PRIORITY
        }
        return priority
    }

    private fun optionalInt(json: JSONObject, key: String): Int? {
        return if (json.has(key) && !json.isNull(key)) json.optInt(key) else null
    }

    private fun optionalDouble(json: JSONObject, key: String): Double? {
        return if (json.has(key) && !json.isNull(key)) json.optDouble(key) else null
    }

    private fun optionalString(json: JSONObject, key: String): String? {
        return if (json.has(key) && !json.isNull(key)) {
            json.optString(key).takeIf { it.isNotBlank() }
        } else {
            null
        }
    }

    private fun normalizeTimeRepeatMode(mode: Int): Int {
        return when (mode) {
            REPEAT_EVERY_DAY, REPEAT_WEEKDAYS, REPEAT_WEEKENDS, REPEAT_CUSTOM -> mode
            else -> REPEAT_EVERY_DAY
        }
    }

    private fun maskForRepeatMode(mode: Int): Int {
        return when (normalizeTimeRepeatMode(mode)) {
            REPEAT_WEEKDAYS -> MASK_WEEKDAYS
            REPEAT_WEEKENDS -> MASK_WEEKENDS
            REPEAT_CUSTOM -> 0
            else -> MASK_EVERY_DAY
        }
    }

    private fun normalizedMaskForRepeatMode(mode: Int, mask: Int): Int {
        return when (normalizeTimeRepeatMode(mode)) {
            REPEAT_WEEKDAYS -> MASK_WEEKDAYS
            REPEAT_WEEKENDS -> MASK_WEEKENDS
            REPEAT_CUSTOM -> mask and MASK_EVERY_DAY
            else -> MASK_EVERY_DAY
        }
    }

    private fun dayBitForCalendarDay(calendarDay: Int): Int {
        return when (calendarDay) {
            Calendar.MONDAY -> 1 shl 0
            Calendar.TUESDAY -> 1 shl 1
            Calendar.WEDNESDAY -> 1 shl 2
            Calendar.THURSDAY -> 1 shl 3
            Calendar.FRIDAY -> 1 shl 4
            Calendar.SATURDAY -> 1 shl 5
            Calendar.SUNDAY -> 1 shl 6
            else -> 0
        }
    }

    private fun repeatMatchesDay(mode: Int, mask: Int, dayBit: Int): Boolean {
        val repeatMask = normalizedMaskForRepeatMode(mode, mask)
        return dayBit != 0 && (repeatMask and dayBit) != 0
    }

    private fun groupedLocationRulesForFlatEvaluator(): List<DndLocationRule> {
        val locationRules = groupedAutomationRules
            .filter { it.enabled }
            .flatMap { rule ->
                rule.triggers
                    .filter { it.enabled && it.triggerType == TRIGGER_TYPE_LOCATION }
                    .mapNotNull { trigger ->
                        val latitude = trigger.latitude
                        val longitude = trigger.longitude
                        val radius = trigger.radius
                        if (latitude == null || longitude == null || radius == null) {
                            android.util.Log.w(
                                "DndGeofence",
                                "Skipping grouped location trigger ${trigger.id} for rule ${rule.id}: missing latitude/longitude/radius."
                            )
                            null
                        } else {
                            DndLocationRule(
                                id = trigger.id,
                                name = rule.name,
                                latitude = latitude,
                                longitude = longitude,
                                radius = radius,
                                allowStarredContacts = rule.allowStarredContacts,
                                allowRepeatCallers = rule.allowRepeatCallers
                            )
                        }
                    }
            }

        android.util.Log.d(
            "DndGeofence",
            "Grouped location trigger count=${locationRules.size}"
        )
        return locationRules
    }

    private fun setupActivityRecognition(shouldMonitor: Boolean) {
        activityRecognitionShouldMonitor = shouldMonitor
        val pendingIntent = activityRecognitionPendingIntent(this)

        if (shouldMonitor) {
            removeLegacyActivityRecognitionPendingIntent()
            lastActivityRecognitionRegisterRequestedAtMillis = System.currentTimeMillis()
            android.util.Log.d(
                "DndActivity",
                "Attempting to register Activity Recognition: intervalMs=$ACTIVITY_UPDATE_INTERVAL_MS, requestCode=$ACTIVITY_RECOGNITION_REQUEST_CODE, action=$ACTION_ACTIVITY_RECOGNITION_UPDATE, mutable=true"
            )
            val hasPermission = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
                ActivityCompat.checkSelfPermission(this, android.Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED

            if (hasPermission) {
                val task = activityRecognitionClient.requestActivityUpdates(
                    ACTIVITY_UPDATE_INTERVAL_MS,
                    pendingIntent
                )

                task.addOnSuccessListener {
                    android.util.Log.d("DndActivity", "SUCCESS: Activity updates registered with Google Play Services.")
                }
                task.addOnFailureListener { e ->
                    val statusCode = (e as? ApiException)?.statusCode
                    val statusText = statusCode?.let { ", statusCode=$it" } ?: ""
                    android.util.Log.e(
                        "DndActivity",
                        "FAILED to register activity updates: exception=${e::class.java.simpleName}$statusText, message=${e.message}"
                    )
                }
            } else {
                android.util.Log.e(
                    "DndActivity",
                    "PERMISSION DENIED: ACTIVITY_RECOGNITION permission is missing; activity/driving triggers cannot run."
                )
            }
        } else {
            android.util.Log.d(
                "DndActivity",
                "Removing activity updates: reason=no-enabled-activity-rules, requestCode=$ACTIVITY_RECOGNITION_REQUEST_CODE, action=$ACTION_ACTIVITY_RECOGNITION_UPDATE"
            )
            activityRecognitionClient.removeActivityUpdates(pendingIntent)
                .addOnSuccessListener {
                    android.util.Log.d("DndActivity", "Activity updates removed successfully.")
                }
                .addOnFailureListener { e ->
                    val statusCode = (e as? ApiException)?.statusCode
                    val statusText = statusCode?.let { ", statusCode=$it" } ?: ""
                    android.util.Log.e(
                        "DndActivity",
                        "FAILED to remove activity updates: exception=${e::class.java.simpleName}$statusText, message=${e.message}"
                    )
                }
        }
    }

    private fun removeLegacyActivityRecognitionPendingIntent() {
        val legacyPendingIntent = legacyActivityRecognitionPendingIntent(this)
        activityRecognitionClient.removeActivityUpdates(legacyPendingIntent)
            .addOnSuccessListener {
                android.util.Log.d(
                    "DndActivity",
                    "Legacy activity updates removed before action-based registration."
                )
            }
            .addOnFailureListener { e ->
                val statusCode = (e as? ApiException)?.statusCode
                val statusText = statusCode?.let { ", statusCode=$it" } ?: ""
                android.util.Log.d(
                    "DndActivity",
                    "Legacy activity update remove before registration returned: exception=${e::class.java.simpleName}$statusText, message=${e.message}"
                )
            }
    }

    private fun setupGeofences(ids: Array<String>, lats: DoubleArray, lngs: DoubleArray, rads: IntArray) {
        val requestedCount = ids.size
        android.util.Log.d(
            "DndGeofence",
            "Geofence setup requested: count=$requestedCount, initialTriggerEnter=true"
        )

        if (ActivityCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            android.util.Log.e(
                "DndGeofence",
                "Geofence registration skipped: ACCESS_FINE_LOCATION is missing. Existing active geofence state preserved."
            )
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            ActivityCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_BACKGROUND_LOCATION) != PackageManager.PERMISSION_GRANTED
        ) {
            android.util.Log.w(
                "DndGeofence",
                "ACCESS_BACKGROUND_LOCATION is missing. Geofences will be registered, but background delivery may not work reliably."
            )
        }
        
        val pendingIntent = getGeofencePendingIntent()

        if (ids.isEmpty()) {
            android.util.Log.d("DndGeofence", "No enabled location rules to monitor. Removing registered geofences and clearing active state.")
            removeRegisteredGeofences(
                pendingIntent,
                "no-enabled-location-rules",
                clearStateOnSuccess = true
            )
            return
        }

        val geofenceList = mutableListOf<Geofence>()
        val registeredGeofenceIds = mutableSetOf<String>()
        for (i in ids.indices) {
            val latitude = lats.getOrNull(i)
            val longitude = lngs.getOrNull(i)
            val radius = rads.getOrNull(i)
            if (latitude == null || longitude == null || radius == null) {
                android.util.Log.w(
                    "DndGeofence",
                    "Skipping malformed geofence at index=$i: id=${ids[i]}, hasLat=${latitude != null}, hasLng=${longitude != null}, hasRadius=${radius != null}"
                )
                continue
            }
            val ruleName = activeLocationRules.firstOrNull { it.id == ids[i] }?.name ?: "unknown"
            android.util.Log.d(
                "DndGeofence",
                "Preparing geofence: id=${ids[i]}, name=$ruleName, radius=${radius}m"
            )
            registeredGeofenceIds.add(ids[i])
            geofenceList.add(
                Geofence.Builder()
                    .setRequestId(ids[i])
                    .setCircularRegion(latitude, longitude, radius.toFloat())
                    .setExpirationDuration(Geofence.NEVER_EXPIRE)
                    .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT)
                    .build()
            )
        }

        if (geofenceList.isEmpty()) {
            android.util.Log.w("DndGeofence", "No valid geofences were built. Existing active geofence state preserved.")
            return
        }

        val geofencingRequest = GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofences(geofenceList)
            .build()

        val registerGeofences: () -> Unit = {
            geofencingClient.addGeofences(geofencingRequest, pendingIntent).run {
                addOnSuccessListener {
                    pruneActiveGeofenceStateToRegisteredIds(
                        registeredGeofenceIds,
                        "registration-success"
                    )
                    refreshActiveGeofenceStateFromCurrentLocation(
                        "registration-success",
                        force = true
                    )
                    android.util.Log.d(
                        "DndGeofence",
                        "Geofence registration succeeded: requested=$requestedCount, registered=${geofenceList.size}, initialTriggerEnter=true"
                    )
                }
                addOnFailureListener { exception ->
                    android.util.Log.e(
                        "DndGeofence",
                        "Geofence registration failed: requested=$requestedCount, built=${geofenceList.size}, initialTriggerEnter=true, ${geofenceExceptionDetails(exception)}. Previous active geofence state preserved."
                    )
                }
            }
        }

        removeRegisteredGeofences(
            pendingIntent,
            "refresh-before-register",
            clearStateOnSuccess = false,
            afterComplete = registerGeofences
        )
    }

    private fun removeRegisteredGeofences(
        pendingIntent: PendingIntent,
        reason: String,
        clearStateOnSuccess: Boolean,
        afterComplete: (() -> Unit)? = null
    ) {
        android.util.Log.d(
            "DndGeofence",
            "Geofence remove requested: reason=$reason, clearStateOnSuccess=$clearStateOnSuccess"
        )
        geofencingClient.removeGeofences(pendingIntent)
            .addOnSuccessListener {
                android.util.Log.d("DndGeofence", "Geofence remove succeeded: reason=$reason")
                if (clearStateOnSuccess) {
                    clearActiveGeofenceState("remove-success:$reason")
                }
                afterComplete?.invoke()
            }
            .addOnFailureListener { exception ->
                android.util.Log.e(
                    "DndGeofence",
                    "Geofence remove failed: reason=$reason, ${geofenceExceptionDetails(exception)}"
                )
                afterComplete?.invoke()
            }
    }

    private fun clearActiveGeofenceState(reason: String) {
        val prefs = getSharedPreferences("DndPrefs", Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean("isInsideGeofence", false)
            .putStringSet("activeGeofenceIds", emptySet<String>())
            .apply()

        isInsideGeofence = false
        android.util.Log.d("DndGeofence", "Active geofence state cleared: reason=$reason")
    }

    private fun pruneActiveGeofenceStateToRegisteredIds(
        registeredIds: Set<String>,
        reason: String
    ) {
        val prefs = getSharedPreferences("DndPrefs", Context.MODE_PRIVATE)
        val activeIds = prefs.getStringSet("activeGeofenceIds", emptySet<String>()) ?: emptySet()
        val prunedIds = activeIds.intersect(registeredIds)

        prefs.edit()
            .putBoolean("isInsideGeofence", prunedIds.isNotEmpty())
            .putStringSet("activeGeofenceIds", prunedIds)
            .apply()

        isInsideGeofence = prunedIds.isNotEmpty()
        android.util.Log.d(
            "DndGeofence",
            "Active geofence state pruned: reason=$reason, before=${activeIds.joinToString()}, registered=${registeredIds.joinToString()}, after=${prunedIds.joinToString()}"
        )
    }

    private fun geofenceExceptionDetails(exception: Exception): String {
        val statusCode = (exception as? ApiException)?.statusCode
        val statusText = statusCode?.let { ", statusCode=$it" } ?: ""
        return "exception=${exception::class.java.simpleName}$statusText, message=${exception.message}"
    }

    private fun getGeofencePendingIntent(): PendingIntent {
        val intent = Intent(this, GeofenceBroadcastReceiver::class.java)
        return PendingIntent.getBroadcast(
            this, 0, intent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
    }

    private fun refreshActiveGeofenceStateFromCurrentLocation(
        source: String,
        force: Boolean = false
    ) {
        if (activeLocationRules.isEmpty()) return

        if (ActivityCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            android.util.Log.w(
                "DndGeofence",
                "Location refresh skipped: ACCESS_FINE_LOCATION is missing. source=$source"
            )
            return
        }

        val now = System.currentTimeMillis()
        if (!force && now - lastLocationRefreshRequestedAtMillis < LOCATION_REFRESH_INTERVAL_MS) {
            return
        }
        lastLocationRefreshRequestedAtMillis = now

        android.util.Log.d(
            "DndGeofence",
            "Location refresh requested: source=$source, force=$force, locationRuleCount=${activeLocationRules.size}"
        )

        val cancellationToken = CancellationTokenSource()
        fusedLocationClient
            .getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, cancellationToken.token)
            .addOnSuccessListener { location ->
                if (location == null) {
                    android.util.Log.w(
                        "DndGeofence",
                        "Location refresh returned null: source=$source"
                    )
                    return@addOnSuccessListener
                }

                updateActiveGeofenceStateFromLocation(location, source)
                checkAndToggleDnd("location-refresh:$source", allowDisableGrace = false)
            }
            .addOnFailureListener { exception ->
                android.util.Log.w(
                    "DndGeofence",
                    "Location refresh failed: source=$source, exception=${exception::class.java.simpleName}, message=${exception.message}"
                )
            }
    }

    private fun updateActiveGeofenceStateFromLocation(location: Location, source: String) {
        val prefs = getSharedPreferences("DndPrefs", Context.MODE_PRIVATE)
        val previousIds = prefs.getStringSet("activeGeofenceIds", emptySet<String>()) ?: emptySet()
        val nextIds = mutableSetOf<String>()
        val accuracyMeters = if (location.hasAccuracy()) location.accuracy.coerceAtLeast(0f) else 0f
        val enterBufferMeters = accuracyMeters.coerceAtMost(LOCATION_ENTER_BUFFER_MAX_METERS)
        val exitBufferMeters = accuracyMeters.coerceAtLeast(LOCATION_EXIT_BUFFER_MIN_METERS)

        activeLocationRules.forEach { rule ->
            val distanceMeters = distanceMeters(
                location.latitude,
                location.longitude,
                rule.latitude,
                rule.longitude
            )
            val wasActive = previousIds.contains(rule.id)
            val isActive = if (wasActive) {
                distanceMeters <= rule.radius + exitBufferMeters
            } else {
                distanceMeters <= rule.radius + enterBufferMeters
            }

            android.util.Log.d(
                "DndGeofence",
                "Location rule distance evaluated: source=$source, id=${rule.id}, name=${rule.name}, distance=${"%.1f".format(distanceMeters)}m, radius=${rule.radius}m, accuracy=${"%.1f".format(accuracyMeters)}m, wasActive=$wasActive, active=$isActive"
            )

            if (isActive) {
                nextIds.add(rule.id)
            }
        }

        prefs.edit()
            .putBoolean("isInsideGeofence", nextIds.isNotEmpty())
            .putStringSet("activeGeofenceIds", nextIds)
            .apply()

        isInsideGeofence = nextIds.isNotEmpty()
        android.util.Log.d(
            "DndGeofence",
            "Active geofence state refreshed from location: source=$source, before=${previousIds.joinToString()}, after=${nextIds.joinToString()}, lat=${location.latitude}, lng=${location.longitude}, accuracy=${"%.1f".format(accuracyMeters)}m"
        )
    }

    private fun distanceMeters(
        startLatitude: Double,
        startLongitude: Double,
        endLatitude: Double,
        endLongitude: Double
    ): Float {
        val result = FloatArray(1)
        Location.distanceBetween(
            startLatitude,
            startLongitude,
            endLatitude,
            endLongitude,
            result
        )
        return result[0]
    }

    private fun startAutomationLoop() {
        timer = Timer()
        // Reduced polling to 10 seconds so game launching detects quickly
        timer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                checkAndToggleDnd("timer")
            }
        }, 0, 3000)
    }

    @Suppress("DEPRECATION")
    private fun currentForegroundAppPackage(
        shouldCheck: Boolean = targetAppPackages.isNotEmpty()
    ): String? {
        if (!shouldCheck) return null

        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val endTime = System.currentTimeMillis()
        val startTime = endTime - 1000 * 60 * 10 // Covers apps that stay open quietly without new resume events.
        val appTargets = appTriggerTargetPackages()

        val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
        var currentForegroundApp: String? = null
        var currentForegroundEventTime = 0L
        val event = UsageEvents.Event()

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            if (
                event.eventType == UsageEvents.Event.ACTIVITY_RESUMED ||
                event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND
            ) {
                currentForegroundApp = event.packageName
                currentForegroundEventTime = event.timeStamp
            }
        }

        if (!currentForegroundApp.isNullOrBlank()) {
            lastConfirmedForegroundPackage = currentForegroundApp
            lastConfirmedForegroundAtMillis = currentForegroundEventTime
        }

        val directMatch = currentForegroundApp != null && appTargets.contains(currentForegroundApp)
        if (directMatch) {
            rememberMatchedApp(currentForegroundApp, currentForegroundEventTime)
        }

        val heldPackage = heldAppForegroundPackage(
            now = endTime,
            currentForegroundPackage = currentForegroundApp,
            appTargets = appTargets
        )
        val resolvedForegroundPackage = heldPackage ?: currentForegroundApp
        val lastConfirmedAgeMs = if (lastConfirmedForegroundAtMillis > 0L) {
            endTime - lastConfirmedForegroundAtMillis
        } else {
            -1L
        }
        val lastMatchedAgeMs = if (lastMatchedAppAtMillis > 0L) {
            endTime - lastMatchedAppAtMillis
        } else {
            -1L
        }

        android.util.Log.d(
            "DndActivity",
            "App foreground source=usage-events, rawForeground=$currentForegroundApp, rawEventTime=$currentForegroundEventTime, resolvedForeground=$resolvedForegroundPackage, heldPackage=$heldPackage, lastConfirmedForeground=$lastConfirmedForegroundPackage, lastConfirmedAgeMs=$lastConfirmedAgeMs, lastMatchedApp=$lastMatchedAppPackage, lastMatchedAgeMs=$lastMatchedAgeMs, holdMs=$APP_FOREGROUND_HOLD_MS, targetAppPackages=${appTargets.joinToString()}, groupedRules=${groupedAutomationRules.size}"
        )
        return resolvedForegroundPackage
    }

    private fun appTriggerTargetPackages(): Set<String> {
        val groupedTargets = groupedAutomationRules
            .flatMap { rule -> rule.triggers }
            .filter { trigger -> trigger.enabled && trigger.triggerType == TRIGGER_TYPE_APP }
            .mapNotNull { trigger -> trigger.packageName }
        return (targetAppPackages.toList() + groupedTargets)
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .toSet()
    }

    private fun rememberMatchedApp(packageName: String, matchedAtMillis: Long) {
        lastMatchedAppPackage = packageName
        lastMatchedAppAtMillis = if (matchedAtMillis > 0L) {
            matchedAtMillis
        } else {
            System.currentTimeMillis()
        }
    }

    private fun heldAppForegroundPackage(
        now: Long,
        currentForegroundPackage: String?,
        appTargets: Set<String>
    ): String? {
        val lastMatched = lastMatchedAppPackage ?: return null
        if (!appTargets.contains(lastMatched)) return null

        val matchedAgeMs = now - lastMatchedAppAtMillis
        if (lastMatchedAppAtMillis <= 0L || matchedAgeMs > APP_FOREGROUND_HOLD_MS) {
            android.util.Log.d(
                "DndActivity",
                "App foreground hold expired: lastMatchedApp=$lastMatched, matchedAgeMs=$matchedAgeMs, holdMs=$APP_FOREGROUND_HOLD_MS, currentForegroundPackage=$currentForegroundPackage"
            )
            return null
        }

        if (currentForegroundPackage.isNullOrBlank()) {
            android.util.Log.d(
                "DndActivity",
                "App foreground hold used: reason=no recent usage event, heldPackage=$lastMatched, matchedAgeMs=$matchedAgeMs"
            )
            return lastMatched
        }

        if (isTransientForegroundPackage(currentForegroundPackage)) {
            android.util.Log.d(
                "DndActivity",
                "App foreground hold used: reason=transient foreground package, rawForeground=$currentForegroundPackage, heldPackage=$lastMatched, matchedAgeMs=$matchedAgeMs"
            )
            return lastMatched
        }

        if (currentForegroundPackage != lastMatched) {
            android.util.Log.d(
                "DndActivity",
                "App foreground hold not used: different real foreground package=$currentForegroundPackage, lastMatchedApp=$lastMatched"
            )
        }
        return null
    }

    private fun isTransientForegroundPackage(packageName: String): Boolean {
        return packageName == this.packageName ||
            packageName == "android" ||
            packageName == "com.android.systemui" ||
            packageName == "com.google.android.permissioncontroller" ||
            packageName == "com.android.permissioncontroller" ||
            packageName.contains("launcher", ignoreCase = true)
    }

    private fun timeWindowMatches(
        currentTotal: Int,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        timeRepeatMode: Int = REPEAT_EVERY_DAY,
        timeRepeatDaysMask: Int = MASK_EVERY_DAY,
        currentTimeMillis: Long = System.currentTimeMillis(),
        triggerId: String = "flat"
    ): Boolean {
        val startTotal = (startHour * 60) + startMinute
        val endTotal = (endHour * 60) + endMinute
        val repeatMode = normalizeTimeRepeatMode(timeRepeatMode)
        val repeatMask = normalizedMaskForRepeatMode(repeatMode, timeRepeatDaysMask)

        if (startTotal == endTotal) {
            android.util.Log.d(
                "DndTime",
                "Time trigger evaluated: triggerId=$triggerId, start=${"%02d:%02d".format(startHour, startMinute)}, end=${"%02d:%02d".format(endHour, endMinute)}, repeatMode=$repeatMode, repeatMask=$repeatMask, dayBit=0, currentTotal=$currentTotal, matched=false"
            )
            return false
        }

        if (repeatMode == REPEAT_CUSTOM && repeatMask == 0) {
            android.util.Log.w(
                "DndTime",
                "Time trigger inactive because custom repeat has no selected days: triggerId=$triggerId"
            )
            return false
        }

        val calendar = Calendar.getInstance().apply { timeInMillis = currentTimeMillis }
        val currentDayBit = dayBitForCalendarDay(calendar.get(Calendar.DAY_OF_WEEK))
        calendar.add(Calendar.DAY_OF_YEAR, -1)
        val previousDayBit = dayBitForCalendarDay(calendar.get(Calendar.DAY_OF_WEEK))

        val matched: Boolean
        val dayBitUsed: Int
        if (startTotal < endTotal) {
            dayBitUsed = currentDayBit
            matched = currentTotal in startTotal until endTotal &&
                repeatMatchesDay(repeatMode, repeatMask, dayBitUsed)
        } else {
            if (currentTotal >= startTotal) {
                dayBitUsed = currentDayBit
                matched = repeatMatchesDay(repeatMode, repeatMask, dayBitUsed)
            } else if (currentTotal < endTotal) {
                dayBitUsed = previousDayBit
                matched = repeatMatchesDay(repeatMode, repeatMask, dayBitUsed)
            } else {
                dayBitUsed = currentDayBit
                matched = false
            }
        }

        android.util.Log.d(
            "DndTime",
            "Time trigger evaluated: triggerId=$triggerId, start=${"%02d:%02d".format(startHour, startMinute)}, end=${"%02d:%02d".format(endHour, endMinute)}, repeatMode=$repeatMode, repeatMask=$repeatMask, dayBit=$dayBitUsed, currentTotal=$currentTotal, matched=$matched"
        )
        return matched
    }

    private fun activityConfidenceByType(prefs: android.content.SharedPreferences): Map<Int, Int> {
        return KNOWN_DETECTED_ACTIVITY_TYPES.associateWith { activityType ->
            prefs.getInt(activityConfidencePrefKey(activityType), 0)
        }
    }

    private fun activitySnapshotAgeMs(prefs: android.content.SharedPreferences): Long? {
        val updatedAt = prefs.getLong(ACTIVITY_SNAPSHOT_UPDATED_AT_PREF, 0L)
        if (updatedAt <= 0L) return null
        return System.currentTimeMillis() - updatedAt
    }

    private fun refreshActivityRecognitionIfStale(
        source: String,
        snapshotAgeMs: Long?
    ) {
        if (!activityRecognitionShouldMonitor) return
        if (activitySnapshotIsFresh(snapshotAgeMs, ACTIVITY_REREGISTER_STALE_MS)) return

        val now = System.currentTimeMillis()
        val registerAgeMs = if (lastActivityRecognitionRegisterRequestedAtMillis > 0L) {
            now - lastActivityRecognitionRegisterRequestedAtMillis
        } else {
            Long.MAX_VALUE
        }
        if (registerAgeMs < ACTIVITY_REREGISTER_STALE_MS) return

        android.util.Log.w(
            "DndActivity",
            "Activity updates stale; refreshing registration. source=$source, snapshotAgeMs=${snapshotAgeMs ?: "none"}, lastRegisterAgeMs=${if (registerAgeMs == Long.MAX_VALUE) "none" else registerAgeMs}, staleThresholdMs=$ACTIVITY_REREGISTER_STALE_MS"
        )
        setupActivityRecognition(true)
    }

    private fun applyDndPolicy(
        notificationManager: NotificationManager,
        allowStarredContacts: Boolean,
        allowRepeatCallers: Boolean,
        matchingRuleNames: List<String>
    ) {
        val hasAccess = notificationManager.isNotificationPolicyAccessGranted
        android.util.Log.d(
            "DndExceptions",
            "Policy access granted=$hasAccess; applying starred=$allowStarredContacts, repeat=$allowRepeatCallers from matches=${matchingRuleNames.joinToString()}"
        )

        if (!hasAccess) {
            android.util.Log.e("DndExceptions", "Cannot apply DND exception policy because notification policy access is missing.")
            return
        }

        var priorityCategories = 0
        val priorityCallSenders = if (allowStarredContacts) {
            priorityCategories = priorityCategories or NotificationManager.Policy.PRIORITY_CATEGORY_CALLS
            NotificationManager.Policy.PRIORITY_SENDERS_STARRED
        } else {
            NotificationManager.Policy.PRIORITY_SENDERS_ANY
        }

        if (allowRepeatCallers) {
            priorityCategories = priorityCategories or NotificationManager.Policy.PRIORITY_CATEGORY_REPEAT_CALLERS
        }

        val policy = NotificationManager.Policy(
            priorityCategories,
            priorityCallSenders,
            NotificationManager.Policy.PRIORITY_SENDERS_ANY
        )

        try {
            notificationManager.setNotificationPolicy(policy)
            android.util.Log.d(
                "DndExceptions",
                "DND policy applied for matches=${matchingRuleNames.joinToString()}, starred=$allowStarredContacts, repeat=$allowRepeatCallers"
            )
        } catch (e: SecurityException) {
            android.util.Log.e("DndExceptions", "Failed to apply DND exception policy: ${e.message}")
        } catch (e: RuntimeException) {
            android.util.Log.e("DndExceptions", "Failed to apply DND exception policy: ${e.message}")
        }
    }

    private fun cancelPendingDisableIfAny(
        source: String,
        timeMatched: Boolean,
        locationMatched: Boolean,
        appMatched: Boolean,
        activityMatched: Boolean,
        calendarMatched: Boolean
    ) {
        val runnable = pendingDisableRunnable ?: return
        disableGraceHandler.removeCallbacks(runnable)
        pendingDisableRunnable = null
        android.util.Log.d(
            "DndActivity",
            "DND disable cancelled: rule matched again. source=$source, timeMatched=$timeMatched, locationMatched=$locationMatched, appMatched=$appMatched, activityMatched=$activityMatched, calendarMatched=$calendarMatched"
        )
    }

    private fun scheduleDisableAfterGrace(
        source: String,
        timeMatched: Boolean,
        locationMatched: Boolean,
        appMatched: Boolean,
        activityMatched: Boolean,
        calendarMatched: Boolean,
        currentForegroundPackage: String?,
        isCurrentlyInsideGeofence: Boolean,
        activeGeofenceIds: Set<String>,
        currentActivityInt: Int
    ) {
        if (pendingDisableRunnable != null) {
            android.util.Log.d(
                "DndActivity",
                "DND disable already pending: source=$source, graceMs=$DND_DISABLE_GRACE_MS, timeMatched=$timeMatched, locationMatched=$locationMatched, appMatched=$appMatched, activityMatched=$activityMatched, calendarMatched=$calendarMatched"
            )
            return
        }

        val runnable = Runnable {
            pendingDisableRunnable = null
            checkAndToggleDnd("disable-grace", allowDisableGrace = false)
        }
        pendingDisableRunnable = runnable
        android.util.Log.d(
            "DndActivity",
            "DND disable delayed: no matching rules, waiting grace period. source=$source, graceMs=$DND_DISABLE_GRACE_MS, timeMatched=$timeMatched, locationMatched=$locationMatched, appMatched=$appMatched, activityMatched=$activityMatched, calendarMatched=$calendarMatched, currentForegroundPackage=$currentForegroundPackage, isInsideGeofence=$isCurrentlyInsideGeofence, activeGeofenceIds=${activeGeofenceIds.joinToString()}, currentActivityInt=$currentActivityInt"
        )
        disableGraceHandler.postDelayed(runnable, DND_DISABLE_GRACE_MS)
    }

    private fun checkAndToggleDnd(
        source: String,
        allowDisableGrace: Boolean = true
    ) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val expiredPauseCleared = AutomationPauseStateStore.clearIfExpired(this)
        if (expiredPauseCleared) {
            android.util.Log.d(
                "DndAutomationPause",
                "Expired automation pause cleared; continuing normal evaluation. source=$source"
            )
        }
        val pauseState = AutomationPauseStateStore.read(this)
        if (pauseState.automationPaused) {
            pendingDisableRunnable?.let { disableGraceHandler.removeCallbacks(it) }
            pendingDisableRunnable = null
            android.util.Log.d(
                "DndAutomationPause",
                "Automation pause active; skipping rule evaluation. source=$source, pauseUntilMillis=${pauseState.pauseUntilMillis}, pausedAtMillis=${pauseState.pausedAtMillis}, reason=${pauseState.pauseReason}"
            )
            applyAutomationPausedState(notificationManager, source, pauseState)
            return
        }

        if (!notificationManager.isNotificationPolicyAccessGranted) {
            android.util.Log.e("DndExceptions", "DND policy access missing; skipping DND evaluation. source=$source")
            pendingDisableRunnable?.let { disableGraceHandler.removeCallbacks(it) }
            pendingDisableRunnable = null
            AutomationDndStateStore.write(this, false, "")
            return
        }

        if (groupedAutomationRules.isNotEmpty()) {
            android.util.Log.d(
                "DndGroupedRules",
                "Using grouped automation evaluation: source=$source, groupedRuleCount=${groupedAutomationRules.size}"
            )
            checkAndToggleDndGrouped(notificationManager, source, allowDisableGrace)
        } else {
            android.util.Log.d(
                "DndGroupedRules",
                "Using flat fallback automation evaluation: source=$source"
            )
            checkAndToggleDndFlatFallback(notificationManager, source, allowDisableGrace)
        }
    }

    private fun applyAutomationPausedState(
        notificationManager: NotificationManager,
        source: String,
        pauseState: AutomationPauseState
    ) {
        val automationState = AutomationDndStateStore.read(this)
        val filterBefore = notificationManager.currentInterruptionFilter
        var automationDndTurnedOff = false

        if (automationState.automationDndActive) {
            if (notificationManager.isNotificationPolicyAccessGranted) {
                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
                automationDndTurnedOff = true
            } else {
                android.util.Log.e(
                    "DndAutomationPause",
                    "Cannot exit automation DND during pause because DND policy access is missing. source=$source"
                )
            }
            AutomationDndStateStore.write(this, false, "")
        }

        val filterAfter = notificationManager.currentInterruptionFilter
        updateForegroundNotification(
            pausedNotificationTitle,
            pausedNotificationText(pauseState)
        )
        android.util.Log.d(
            "DndAutomationPause",
            "Paused state applied: source=$source, automationWasActive=${automationState.automationDndActive}, automationDndTurnedOff=$automationDndTurnedOff, pauseUntilMillis=${pauseState.pauseUntilMillis}, filterBefore=$filterBefore, filterAfter=$filterAfter"
        )
    }

    private fun pausedNotificationText(pauseState: AutomationPauseState): String {
        val pauseUntilMillis = pauseState.pauseUntilMillis
        if (pauseUntilMillis <= 0L) return "Paused until resumed"

        val timeText = SimpleDateFormat("HH:mm", Locale.getDefault())
            .format(java.util.Date(pauseUntilMillis))
        return "Paused until $timeText"
    }

    private fun checkAndToggleDndGrouped(
        notificationManager: NotificationManager,
        source: String,
        allowDisableGrace: Boolean
    ) {
        refreshActiveGeofenceStateFromCurrentLocation(source)
        val prefs = getSharedPreferences("DndPrefs", Context.MODE_PRIVATE)
        val isCurrentlyInsideGeofence = prefs.getBoolean("isInsideGeofence", false)
        val activeGeofenceIds = prefs.getStringSet("activeGeofenceIds", emptySet<String>()) ?: emptySet()
        val currentActivityInt = prefs.getInt("currentActivityType", DetectedActivity.UNKNOWN)
        val currentActivityConfidence = prefs.getInt("currentActivityConfidence", 0)
        val activityConfidences = activityConfidenceByType(prefs)
        val activitySnapshotAgeMillis = activitySnapshotAgeMs(prefs)
        refreshActivityRecognitionIfStale(source, activitySnapshotAgeMillis)
        val calendar = Calendar.getInstance()
        val currentTotal = (calendar.get(Calendar.HOUR_OF_DAY) * 60) + calendar.get(Calendar.MINUTE)
        val currentTimeMillis = System.currentTimeMillis()
        val hasGroupedAppTrigger = groupedAutomationRules.any { rule ->
            rule.enabled && rule.triggers.any { it.enabled && it.triggerType == TRIGGER_TYPE_APP }
        }
        val currentForegroundPackage = currentForegroundAppPackage(shouldCheck = hasGroupedAppTrigger)

        val activeParentRules = mutableListOf<AutomationRule>()
        var timeMatched = false
        var locationMatched = false
        var appMatched = false
        var activityMatched = false
        var calendarMatched = false

        for (rule in groupedAutomationRules) {
            if (!rule.enabled) {
                android.util.Log.d(
                    "DndGroupedRules",
                    "Grouped rule skipped: id=${rule.id}, name=${rule.name}, reason=disabled"
                )
                continue
            }

            val enabledTriggers = rule.triggers.filter { it.enabled }
            if (enabledTriggers.isEmpty()) {
                android.util.Log.d(
                    "DndGroupedRules",
                    "Grouped rule inactive: id=${rule.id}, name=${rule.name}, reason=no-enabled-triggers"
                )
                continue
            }

            val effectiveMatchType = when (rule.matchType) {
                MATCH_TYPE_ANY, MATCH_TYPE_ALL -> rule.matchType
                else -> {
                    android.util.Log.w(
                        "DndGroupedRules",
                        "Unknown matchType=${rule.matchType} during evaluation for rule ${rule.id}; falling back to ANY."
                    )
                    MATCH_TYPE_ANY
                }
            }

            val triggerResults = enabledTriggers.map { trigger ->
                val result = evaluateGroupedTrigger(
                    trigger,
                    currentTotal,
                    currentTimeMillis,
                    activeGeofenceIds,
                    currentForegroundPackage,
                    currentActivityInt,
                    activityConfidences,
                    activitySnapshotAgeMillis
                )
                if (result) {
                    when (trigger.triggerType) {
                        TRIGGER_TYPE_TIME -> timeMatched = true
                        TRIGGER_TYPE_LOCATION -> locationMatched = true
                        TRIGGER_TYPE_APP -> appMatched = true
                        TRIGGER_TYPE_ACTIVITY -> activityMatched = true
                        TRIGGER_TYPE_CALENDAR -> calendarMatched = true
                    }
                }
                android.util.Log.d(
                    "DndGroupedRules",
                    "Grouped trigger evaluated: ruleId=${rule.id}, ruleName=${rule.name}, triggerId=${trigger.id}, type=${triggerTypeName(trigger.triggerType)}, result=$result"
                )
                result
            }

            val ruleActive = if (effectiveMatchType == MATCH_TYPE_ALL) {
                triggerResults.all { it }
            } else {
                triggerResults.any { it }
            }

            android.util.Log.d(
                "DndGroupedRules",
                "Grouped rule evaluated: id=${rule.id}, name=${rule.name}, matchType=${matchTypeName(effectiveMatchType)}, triggerCount=${enabledTriggers.size}, active=$ruleActive"
            )

            if (ruleActive) {
                activeParentRules.add(rule)
            }
        }

        val sortedActiveParentRules = sortActiveParentRules(activeParentRules)
        val primaryRule = sortedActiveParentRules.firstOrNull()
        val matchingRuleNames = sortedActiveParentRules.map { it.name }.distinct()
        val shouldBeActive = sortedActiveParentRules.isNotEmpty()
        val allowStarredContacts = primaryRule?.allowStarredContacts ?: false
        val allowRepeatCallers = primaryRule?.allowRepeatCallers ?: false
        val currentFilter = notificationManager.currentInterruptionFilter

        android.util.Log.d(
            "DndGroupedRules",
            "Grouped evaluation result: source=$source, shouldBeActive=$shouldBeActive, activeParentRules=${matchingRuleNames.joinToString()}, primary=${primaryRule?.name ?: "none"}, primaryPriority=${primaryRule?.priority ?: "none"}, primaryStarred=$allowStarredContacts, primaryRepeat=$allowRepeatCallers, timeMatched=$timeMatched, locationMatched=$locationMatched, appMatched=$appMatched, activityMatched=$activityMatched, calendarMatched=$calendarMatched, currentForegroundPackage=$currentForegroundPackage, isInsideGeofence=$isCurrentlyInsideGeofence, activeGeofenceIds=${activeGeofenceIds.joinToString()}, currentActivity=${detectedActivityName(currentActivityInt)}, currentActivityConfidence=$currentActivityConfidence, activitySnapshotAgeMs=${activitySnapshotAgeMillis ?: "none"}, activitySnapshotFresh=${activitySnapshotIsFresh(activitySnapshotAgeMillis)}, calendarWindows=${calendarBusyWindows.size}"
        )

        if (primaryRule != null) {
            android.util.Log.d(
                "DndExceptions",
                "Grouped primary rule selected: id=${primaryRule.id}, name=${primaryRule.name}, priority=${primaryRule.priority}, starred=${primaryRule.allowStarredContacts}, repeat=${primaryRule.allowRepeatCallers}, alsoActive=${matchingRuleNames.drop(1).joinToString()}"
            )
        }

        applyAutomationDecision(
            notificationManager,
            source,
            allowDisableGrace,
            shouldBeActive,
            matchingRuleNames,
            allowStarredContacts,
            allowRepeatCallers,
            timeMatched,
            locationMatched,
            appMatched,
            activityMatched,
            calendarMatched,
            currentForegroundPackage,
            isCurrentlyInsideGeofence,
            activeGeofenceIds,
            currentActivityInt,
            currentFilter
        )
    }

    private fun sortActiveParentRules(activeParentRules: List<AutomationRule>): List<AutomationRule> {
        return activeParentRules.sortedWith { left, right ->
            val priorityCompare = right.priority.compareTo(left.priority)
            if (priorityCompare != 0) return@sortedWith priorityCompare

            val leftNumericId = left.id.toLongOrNull()
            val rightNumericId = right.id.toLongOrNull()
            if (leftNumericId != null && rightNumericId != null) {
                val numericCompare = leftNumericId.compareTo(rightNumericId)
                if (numericCompare != 0) return@sortedWith numericCompare
            }

            left.id.compareTo(right.id)
        }
    }

    private fun evaluateGroupedTrigger(
        trigger: AutomationTrigger,
        currentTotal: Int,
        currentTimeMillis: Long,
        activeGeofenceIds: Set<String>,
        currentForegroundPackage: String?,
        currentActivityInt: Int,
        activityConfidences: Map<Int, Int>,
        activitySnapshotAgeMs: Long?
    ): Boolean {
        return when (trigger.triggerType) {
            TRIGGER_TYPE_TIME -> {
                val startHour = trigger.startHour
                val startMinute = trigger.startMinute
                val endHour = trigger.endHour
                val endMinute = trigger.endMinute
                if (startHour == null || startMinute == null || endHour == null || endMinute == null) {
                    android.util.Log.w(
                        "DndGroupedRules",
                        "Grouped time trigger inactive because time fields are incomplete: triggerId=${trigger.id}"
                    )
                    false
                } else {
                    timeWindowMatches(
                        currentTotal,
                        startHour,
                        startMinute,
                        endHour,
                        endMinute,
                        trigger.timeRepeatMode,
                        trigger.timeRepeatDaysMask,
                        currentTimeMillis,
                        trigger.id
                    )
                }
            }
            TRIGGER_TYPE_LOCATION -> {
                val matched = activeGeofenceIds.contains(trigger.id)
                android.util.Log.d(
                    "DndGeofence",
                    "Grouped location trigger evaluated: triggerId=${trigger.id}, matched=$matched, activeGeofenceIds=${activeGeofenceIds.joinToString()}"
                )
                matched
            }
            TRIGGER_TYPE_APP -> {
                val packageName = trigger.packageName
                val matched = packageName != null && packageName == currentForegroundPackage
                val reason = when {
                    packageName == null -> "missing trigger package"
                    currentForegroundPackage == null -> "no resolved foreground package"
                    matched -> "package matched"
                    else -> "foreground package differs"
                }
                android.util.Log.d(
                    "DndActivity",
                    "Grouped app trigger evaluated: triggerId=${trigger.id}, targetPackage=$packageName, currentForegroundPackage=$currentForegroundPackage, matched=$matched, reason=$reason, lastMatchedApp=$lastMatchedAppPackage, lastMatchedAt=$lastMatchedAppAtMillis"
                )
                matched
            }
            TRIGGER_TYPE_ACTIVITY -> {
                val activityType = trigger.activityType
                val threshold = trigger.activityConfidenceThreshold
                val confidence = activityTriggerConfidence(activityType, activityConfidences)
                val targetType = detectedActivityTypeForRuleActivity(activityType)
                val matched = activityTriggerMatches(
                    activityType,
                    activityConfidences,
                    threshold,
                    activitySnapshotAgeMs
                )
                val reason = when {
                    activityType == null -> "missing activity type"
                    targetType == null -> "unknown activity type"
                    !activitySnapshotIsFresh(activitySnapshotAgeMs) -> "activity snapshot stale or missing"
                    matched -> "confidence met threshold"
                    else -> "confidence below threshold"
                }
                android.util.Log.d(
                    "DndActivity",
                    "Grouped activity trigger evaluated: triggerId=${trigger.id}, targetActivity=$activityType, targetDetected=${targetType?.let { detectedActivityName(it) } ?: "unknown"}, threshold=$threshold, targetConfidence=$confidence, currentMostProbable=${detectedActivityName(currentActivityInt)}, snapshotAgeMs=${activitySnapshotAgeMs ?: "none"}, matched=$matched, reason=$reason"
                )
                matched
            }
            TRIGGER_TYPE_CALENDAR -> calendarTriggerMatches(trigger.id, currentTimeMillis)
            else -> {
                android.util.Log.w(
                    "DndGroupedRules",
                    "Grouped trigger inactive because triggerType is unknown: triggerId=${trigger.id}, triggerType=${trigger.triggerType}"
                )
                false
            }
        }
    }

    private fun calendarTriggerMatches(triggerId: String, currentTimeMillis: Long): Boolean {
        val windowsForTrigger = calendarBusyWindows.filter { window ->
            window.triggerId == triggerId
        }
        val matchingWindows = windowsForTrigger.filter { window ->
            window.triggerId == triggerId &&
                currentTimeMillis >= window.startMillis &&
                currentTimeMillis < window.endMillis
        }
        val matched = matchingWindows.isNotEmpty()
        val allDayMatchingWindowExists = matchingWindows.any { it.isAllDay }
        val newestFetchedAt = matchingWindows.maxOfOrNull { it.fetchedAt } ?: 0L
        val fetchedAgeMinutes = if (newestFetchedAt > 0L) {
            (currentTimeMillis - newestFetchedAt).coerceAtLeast(0L) / 60000L
        } else {
            -1L
        }
        android.util.Log.d(
            "DndCalendar",
            "Calendar trigger evaluated: triggerId=$triggerId, windowsForTrigger=${windowsForTrigger.size}, currentTimeMillis=$currentTimeMillis, matched=$matched, matchingWindowCount=${matchingWindows.size}, allDayMatchingWindowExists=$allDayMatchingWindowExists, fetchedAgeMinutes=$fetchedAgeMinutes"
        )
        return matched
    }

    private fun triggerTypeName(triggerType: Int): String {
        return when (triggerType) {
            TRIGGER_TYPE_TIME -> "time"
            TRIGGER_TYPE_LOCATION -> "location"
            TRIGGER_TYPE_APP -> "app"
            TRIGGER_TYPE_ACTIVITY -> "activity"
            TRIGGER_TYPE_CALENDAR -> "calendar"
            else -> "unknown"
        }
    }

    private fun matchTypeName(matchType: Int): String {
        return if (matchType == MATCH_TYPE_ALL) "ALL" else "ANY"
    }

    private fun checkAndToggleDndFlatFallback(
        notificationManager: NotificationManager,
        source: String,
        allowDisableGrace: Boolean
    ) {
        refreshActiveGeofenceStateFromCurrentLocation(source)
        // 1. Time Check
        val calendar = Calendar.getInstance()
        val currentTotal = (calendar.get(Calendar.HOUR_OF_DAY) * 60) + calendar.get(Calendar.MINUTE)
        val currentTimeMillis = calendar.timeInMillis
        val matchingTimeRules = activeRules.filter { rule ->
            timeWindowMatches(
                currentTotal,
                rule.startHour,
                rule.startMinute,
                rule.endHour,
                rule.endMinute,
                rule.timeRepeatMode,
                rule.timeRepeatDaysMask,
                currentTimeMillis,
                rule.id
            )
        }

        // 2. Location Check
        val prefs = getSharedPreferences("DndPrefs", Context.MODE_PRIVATE)
        val isCurrentlyInsideGeofence = prefs.getBoolean("isInsideGeofence", false)
        val activeGeofenceIds = prefs.getStringSet("activeGeofenceIds", emptySet<String>()) ?: emptySet()
        val matchingLocationRules = if (isCurrentlyInsideGeofence && activeGeofenceIds.isEmpty()) {
            activeLocationRules
        } else {
            activeLocationRules.filter { activeGeofenceIds.contains(it.id) }
        }

        // 3. App Check
        val currentForegroundPackage = currentForegroundAppPackage()
        val matchingAppRules = targetAppRules.filter { it.packageName == currentForegroundPackage }
        targetAppRules.forEach { rule ->
            val matched = rule.packageName == currentForegroundPackage
            val reason = when {
                currentForegroundPackage == null -> "no resolved foreground package"
                matched -> "package matched"
                else -> "foreground package differs"
            }
            android.util.Log.d(
                "DndActivity",
                "Flat app trigger evaluated: ruleId=${rule.id}, ruleName=${rule.name}, targetPackage=${rule.packageName}, currentForegroundPackage=$currentForegroundPackage, matched=$matched, reason=$reason, lastMatchedApp=$lastMatchedAppPackage, lastMatchedAt=$lastMatchedAppAtMillis"
            )
        }

        // 4. Activity Check with Logging
        val currentActivityInt = prefs.getInt("currentActivityType", DetectedActivity.UNKNOWN)
        val currentActivityConfidence = prefs.getInt("currentActivityConfidence", 0)
        val activityConfidences = activityConfidenceByType(prefs)
        val activitySnapshotAgeMillis = activitySnapshotAgeMs(prefs)
        refreshActivityRecognitionIfStale(source, activitySnapshotAgeMillis)
        
        android.util.Log.d(
            "DndActivity",
            "Evaluating activity rules. source=$source, currentMostProbable=${detectedActivityName(currentActivityInt)}, currentActivityConfidence=$currentActivityConfidence, activitySnapshotAgeMs=${activitySnapshotAgeMillis ?: "none"}, activitySnapshotFresh=${activitySnapshotIsFresh(activitySnapshotAgeMillis)}, targetActivityTypes=${targetActivityTypes.joinToString()}"
        )

        val matchingActivityRules = targetActivityRules.filter {
            activityTriggerMatches(
                it.activityType,
                activityConfidences,
                it.confidenceThreshold,
                activitySnapshotAgeMillis
            )
        }
        targetActivityRules.forEach { rule ->
            val threshold = rule.confidenceThreshold
            val confidence = activityTriggerConfidence(rule.activityType, activityConfidences)
            val targetType = detectedActivityTypeForRuleActivity(rule.activityType)
            val matched = activityTriggerMatches(
                rule.activityType,
                activityConfidences,
                threshold,
                activitySnapshotAgeMillis
            )
            val reason = when {
                targetType == null -> "unknown activity type"
                !activitySnapshotIsFresh(activitySnapshotAgeMillis) -> "activity snapshot stale or missing"
                matched -> "confidence met threshold"
                else -> "confidence below threshold"
            }
            android.util.Log.d(
                "DndActivity",
                "Flat activity trigger evaluated: ruleId=${rule.id}, ruleName=${rule.name}, targetActivity=${rule.activityType}, targetDetected=${targetType?.let { detectedActivityName(it) } ?: "unknown"}, threshold=$threshold, targetConfidence=$confidence, currentMostProbable=${detectedActivityName(currentActivityInt)}, snapshotAgeMs=${activitySnapshotAgeMillis ?: "none"}, matched=$matched, reason=$reason"
            )
        }

        // 5. Trigger Evaluation
        val matchingRuleNames =
            matchingTimeRules.map { it.name } +
            matchingLocationRules.map { it.name } +
            matchingAppRules.map { it.name } +
            matchingActivityRules.map { it.name }
        val shouldBeActive = matchingRuleNames.isNotEmpty()
        val currentFilter = notificationManager.currentInterruptionFilter
        val timeMatched = matchingTimeRules.isNotEmpty()
        val locationMatched = matchingLocationRules.isNotEmpty()
        val appMatched = matchingAppRules.isNotEmpty()
        val activityMatched = matchingActivityRules.isNotEmpty()
        android.util.Log.d(
            "DndActivity",
            "DND evaluation result: source=$source, shouldBeActive=$shouldBeActive, currentFilter=$currentFilter, timeMatched=$timeMatched, locationMatched=$locationMatched, appMatched=$appMatched, activityMatched=$activityMatched, currentForegroundPackage=$currentForegroundPackage, isInsideGeofence=$isCurrentlyInsideGeofence, activeGeofenceIds=${activeGeofenceIds.joinToString()}, targetAppPackages=${targetAppPackages.joinToString()}, matches=${matchingRuleNames.joinToString()}"
        )

        val allowStarredContacts =
            matchingTimeRules.any { it.allowStarredContacts } ||
            matchingLocationRules.any { it.allowStarredContacts } ||
            matchingAppRules.any { it.allowStarredContacts } ||
            matchingActivityRules.any { it.allowStarredContacts }
        val allowRepeatCallers =
            matchingTimeRules.any { it.allowRepeatCallers } ||
            matchingLocationRules.any { it.allowRepeatCallers } ||
            matchingAppRules.any { it.allowRepeatCallers } ||
            matchingActivityRules.any { it.allowRepeatCallers }

        applyAutomationDecision(
            notificationManager,
            source,
            allowDisableGrace,
            shouldBeActive,
            matchingRuleNames,
            allowStarredContacts,
            allowRepeatCallers,
            timeMatched,
            locationMatched,
            appMatched,
            activityMatched,
            false,
            currentForegroundPackage,
            isCurrentlyInsideGeofence,
            activeGeofenceIds,
            currentActivityInt,
            currentFilter
        )
    }

    private fun applyAutomationDecision(
        notificationManager: NotificationManager,
        source: String,
        allowDisableGrace: Boolean,
        shouldBeActive: Boolean,
        matchingRuleNames: List<String>,
        allowStarredContacts: Boolean,
        allowRepeatCallers: Boolean,
        timeMatched: Boolean,
        locationMatched: Boolean,
        appMatched: Boolean,
        activityMatched: Boolean,
        calendarMatched: Boolean,
        currentForegroundPackage: String?,
        isCurrentlyInsideGeofence: Boolean,
        activeGeofenceIds: Set<String>,
        currentActivityInt: Int,
        currentFilter: Int
    ) {
        if (shouldBeActive) {
            cancelPendingDisableIfAny(
                source,
                timeMatched,
                locationMatched,
                appMatched,
                activityMatched,
                calendarMatched
            )
            val activeRuleNamesText = matchingRuleNames.joinToString()

            android.util.Log.d(
                "DndExceptions",
                "Active rule exception policy: source=$source, starred=$allowStarredContacts, repeat=$allowRepeatCallers, activeRules=$activeRuleNamesText"
            )
            android.util.Log.d(
                "DndActivity",
                "Active automation rule names calculated: $activeRuleNamesText"
            )

            applyDndPolicy(
                notificationManager,
                allowStarredContacts,
                allowRepeatCallers,
                matchingRuleNames
            )

            if (currentFilter != NotificationManager.INTERRUPTION_FILTER_PRIORITY) {
                if (calendarMatched) {
                    android.util.Log.d(
                        "DndCalendar",
                        "DND state changed because of calendar trigger: enabling automation DND. source=$source, activeRules=$activeRuleNamesText"
                    )
                }
                android.util.Log.d("DndActivity", "DND enabled by automation.")
                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
            }
            AutomationDndStateStore.write(this, true, activeRuleNamesText)
            updateForegroundNotification(
                notificationTitleForDecision(shouldBeActive = true),
                notificationTextForDecision(
                    shouldBeActive = true,
                    matchingRuleNames = matchingRuleNames
                )
            )
        } else {
            if (allowDisableGrace && currentFilter != NotificationManager.INTERRUPTION_FILTER_ALL) {
                scheduleDisableAfterGrace(
                    source,
                    timeMatched,
                    locationMatched,
                    appMatched,
                    activityMatched,
                    calendarMatched,
                    currentForegroundPackage,
                    isCurrentlyInsideGeofence,
                    activeGeofenceIds,
                    currentActivityInt
                )
                return
            }

            if (currentFilter != NotificationManager.INTERRUPTION_FILTER_ALL) {
                android.util.Log.d(
                    "DndCalendar",
                    "DND state changed after calendar re-evaluation: disabling automation DND because no rules match. source=$source, calendarMatched=$calendarMatched"
                )
                android.util.Log.d(
                    "DndActivity",
                    "DND disabled after grace period: still no matching rules. source=$source, timeMatched=$timeMatched, locationMatched=$locationMatched, appMatched=$appMatched, activityMatched=$activityMatched, calendarMatched=$calendarMatched, currentForegroundPackage=$currentForegroundPackage, lastMatchedApp=$lastMatchedAppPackage, lastMatchedAppAt=$lastMatchedAppAtMillis, isInsideGeofence=$isCurrentlyInsideGeofence, activeGeofenceIds=${activeGeofenceIds.joinToString()}, targetAppPackages=${appTriggerTargetPackages().joinToString()}, currentActivityInt=$currentActivityInt"
                )
                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
            }
            AutomationDndStateStore.write(this, false, "")
            updateForegroundNotification(
                notificationTitleForDecision(shouldBeActive = false),
                notificationTextForDecision(
                    shouldBeActive = false,
                    matchingRuleNames = emptyList()
                )
            )
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        android.util.Log.w("DndService", "App swiped away! Requesting OS to keep service alive.")
        
        // Tells Android to restart this Foreground Service if the OS killed it
        val restartServiceIntent = Intent(applicationContext, this.javaClass).apply {
            action = CachedRulePayloadStore.ACTION_RESTORE_FROM_CACHE
            setPackage(packageName)
        }
        android.util.Log.d("DndRuleCache", "Service restart scheduled from onTaskRemoved with restore-from-cache action.")
        
        val restartServicePendingIntent = PendingIntent.getService(
            applicationContext,
            1,
            restartServiceIntent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val alarmService = applicationContext.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        alarmService.set(
            android.app.AlarmManager.ELAPSED_REALTIME,
            android.os.SystemClock.elapsedRealtime() + 1000, // Restart after 1 second
            restartServicePendingIntent
        )
    }

    override fun onDestroy() {
        timer?.cancel()
        pendingDisableRunnable?.let { disableGraceHandler.removeCallbacks(it) }
        pendingDisableRunnable = null
        unregisterReceiver(geofenceUpdateReceiver)
        removeRegisteredGeofences(
            getGeofencePendingIntent(),
            "service-destroy",
            clearStateOnSuccess = false
        )

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (notificationManager.isNotificationPolicyAccessGranted) {
            notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
        }
        AutomationDndStateStore.write(this, false, "")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "DND Automation Service",
                NotificationManager.IMPORTANCE_LOW 
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(serviceChannel)
        }
    }
}
