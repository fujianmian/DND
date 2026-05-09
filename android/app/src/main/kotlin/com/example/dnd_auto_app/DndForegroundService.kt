package com.example.dnd_auto_app

import android.app.NotificationChannel
import android.app.NotificationManager
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
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import java.util.Calendar
import java.util.Timer
import java.util.TimerTask
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityRecognitionClient
import com.google.android.gms.location.DetectedActivity

data class DndRule(
    val id: String,
    val name: String,
    val startHour: Int,
    val startMinute: Int,
    val endHour: Int,
    val endMinute: Int,
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
    val allowStarredContacts: Boolean,
    val allowRepeatCallers: Boolean
)

class DndForegroundService : Service() {

    private val CHANNEL_ID = "DndServiceChannel"
    private val DND_DISABLE_GRACE_MS = 3000L
    private var timer: Timer? = null
    private val disableGraceHandler = Handler(Looper.getMainLooper())
    private var pendingDisableRunnable: Runnable? = null
    private var activeRules: List<DndRule> = emptyList()
    private var activeLocationRules: List<DndLocationRule> = emptyList()
    private var targetAppRules: List<DndAppRule> = emptyList()
    private var targetActivityRules: List<DndActivityRule> = emptyList()
    private var targetAppPackages: Array<String> = emptyArray() // Track App Triggers
    private var targetActivityTypes: Array<String> = emptyArray() // Track Activity Triggers
    private lateinit var activityRecognitionClient: ActivityRecognitionClient
    
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

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val ruleIntent = resolveRulePayloadIntent(intent)
        val hasResolvedRulePayload = ruleIntent != null

        // 1. Reconstruct Time Rules
        val startHours = ruleIntent?.getIntArrayExtra("startHours") ?: intArrayOf()
        val startMinutes = ruleIntent?.getIntArrayExtra("startMinutes") ?: intArrayOf()
        val endHours = ruleIntent?.getIntArrayExtra("endHours") ?: intArrayOf()
        val endMinutes = ruleIntent?.getIntArrayExtra("endMinutes") ?: intArrayOf()
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
        activeLocationRules = locIds.indices.map { i ->
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

        if (hasResolvedRulePayload) {
            setupGeofences(locIds, lats, lngs, rads)
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
        targetActivityRules = targetActivityTypes.indices.map { i ->
            DndActivityRule(
                stringAt(activityRuleIds, i, i.toString()),
                stringAt(activityRuleNames, i, "Activity rule ${i + 1}"),
                targetActivityTypes[i],
                boolAt(activityAllowStarredContacts, i),
                boolAt(activityAllowRepeatCallers, i)
            )
        }
        if (hasResolvedRulePayload) {
            setupActivityRecognition(targetActivityTypes.isNotEmpty())
        }

        logSyncedRuleExceptions()

        // 5. Foreground Notification (Combined correctly)
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("DND Automation Active")
            .setContentText("Monitoring ${activeRules.size} time(s), ${locIds.size} loc(s), ${targetAppPackages.size} app(s) & ${targetActivityTypes.size} act(s)")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .build()

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
                "Cached rule payload restored for service start: location=${restoredIntent.getStringArrayExtra("locIds")?.size ?: 0}"
            )
        }
        return restoredIntent
    }

    private fun logSyncedRuleExceptions() {
        activeRules.forEach {
            android.util.Log.d(
                "DndExceptions",
                "Time rule received: id=${it.id}, name=${it.name}, starred=${it.allowStarredContacts}, repeat=${it.allowRepeatCallers}"
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
                "Activity rule received: id=${it.id}, name=${it.name}, activity=${it.activityType}, starred=${it.allowStarredContacts}, repeat=${it.allowRepeatCallers}"
            )
        }
    }

    private fun setupActivityRecognition(shouldMonitor: Boolean) {
        val intent = Intent(this, ActivityBroadcastReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this, 1001, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        if (shouldMonitor) {
            android.util.Log.d("DndActivity", "Attempting to register Activity Recognition...")
            if (ActivityCompat.checkSelfPermission(this, android.Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED) {
                
                // Request updates and attach success/failure listeners
                val task = activityRecognitionClient.requestActivityUpdates(3000, pendingIntent) // Polling every 3 seconds for testing
                
                task.addOnSuccessListener {
                    android.util.Log.d("DndActivity", "SUCCESS: Activity updates registered with Google Play Services.")
                }
                task.addOnFailureListener { e ->
                    android.util.Log.e("DndActivity", "FAILED to register activity updates: ${e.message}")
                }
            } else {
                android.util.Log.e("DndActivity", "PERMISSION DENIED: ACTIVITY_RECOGNITION permission is missing.")
            }
        } else {
            android.util.Log.d("DndActivity", "Removing activity updates (No activity rules active).")
            activityRecognitionClient.removeActivityUpdates(pendingIntent)
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
                    clearActiveGeofenceState("registration-success")
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
    private fun currentForegroundAppPackage(): String? {
        if (targetAppPackages.isEmpty()) return null

        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val endTime = System.currentTimeMillis()
        val startTime = endTime - 1000 * 60 * 1 // Look at events from the last 1 minute

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

        android.util.Log.d(
            "DndActivity",
            "Current foreground package=$currentForegroundApp, eventTime=$currentForegroundEventTime, targetAppPackages=${targetAppPackages.joinToString()}"
        )
        return currentForegroundApp
    }

    private fun activityMatches(ruleActivityType: String, currentActivityInt: Int): Boolean {
        return when (ruleActivityType) {
            "IN_VEHICLE" -> currentActivityInt == DetectedActivity.IN_VEHICLE
            "ON_BICYCLE" -> currentActivityInt == DetectedActivity.ON_BICYCLE
            "WALKING" -> currentActivityInt == DetectedActivity.WALKING || currentActivityInt == DetectedActivity.ON_FOOT
            "RUNNING" -> currentActivityInt == DetectedActivity.RUNNING
            "STILL" -> currentActivityInt == DetectedActivity.STILL
            "TILTING" -> currentActivityInt == DetectedActivity.TILTING
            else -> false
        }
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
        activityMatched: Boolean
    ) {
        val runnable = pendingDisableRunnable ?: return
        disableGraceHandler.removeCallbacks(runnable)
        pendingDisableRunnable = null
        android.util.Log.d(
            "DndActivity",
            "DND disable cancelled: rule matched again. source=$source, timeMatched=$timeMatched, locationMatched=$locationMatched, appMatched=$appMatched, activityMatched=$activityMatched"
        )
    }

    private fun scheduleDisableAfterGrace(
        source: String,
        timeMatched: Boolean,
        locationMatched: Boolean,
        appMatched: Boolean,
        activityMatched: Boolean,
        currentForegroundPackage: String?,
        isCurrentlyInsideGeofence: Boolean,
        activeGeofenceIds: Set<String>,
        currentActivityInt: Int
    ) {
        if (pendingDisableRunnable != null) {
            android.util.Log.d(
                "DndActivity",
                "DND disable already pending: source=$source, graceMs=$DND_DISABLE_GRACE_MS, timeMatched=$timeMatched, locationMatched=$locationMatched, appMatched=$appMatched, activityMatched=$activityMatched"
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
            "DND disable delayed: no matching rules, waiting grace period. source=$source, graceMs=$DND_DISABLE_GRACE_MS, timeMatched=$timeMatched, locationMatched=$locationMatched, appMatched=$appMatched, activityMatched=$activityMatched, currentForegroundPackage=$currentForegroundPackage, isInsideGeofence=$isCurrentlyInsideGeofence, activeGeofenceIds=${activeGeofenceIds.joinToString()}, currentActivityInt=$currentActivityInt"
        )
        disableGraceHandler.postDelayed(runnable, DND_DISABLE_GRACE_MS)
    }

    private fun checkAndToggleDnd(
        source: String,
        allowDisableGrace: Boolean = true
    ) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!notificationManager.isNotificationPolicyAccessGranted) {
            android.util.Log.e("DndExceptions", "DND policy access missing; skipping DND evaluation. source=$source")
            pendingDisableRunnable?.let { disableGraceHandler.removeCallbacks(it) }
            pendingDisableRunnable = null
            AutomationDndStateStore.write(this, false, "")
            return
        }

        // 1. Time Check
        val calendar = Calendar.getInstance()
        val currentTotal = (calendar.get(Calendar.HOUR_OF_DAY) * 60) + calendar.get(Calendar.MINUTE)
        val matchingTimeRules = activeRules.filter { rule ->
            val startTotal = (rule.startHour * 60) + rule.startMinute
            val endTotal = (rule.endHour * 60) + rule.endMinute

            if (startTotal < endTotal) {
                currentTotal in startTotal until endTotal
            } else if (startTotal > endTotal) {
                currentTotal >= startTotal || currentTotal < endTotal
            } else {
                false
            }
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

        // 4. Activity Check with Logging
        val currentActivityInt = prefs.getInt("currentActivityType", DetectedActivity.UNKNOWN)
        
        android.util.Log.d("DndActivity", "Evaluating Rules. source=$source, currentActivityInt=$currentActivityInt, targetActivityTypes=${targetActivityTypes.joinToString()}")

        val matchingActivityRules = targetActivityRules.filter {
            activityMatches(it.activityType, currentActivityInt)
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

        if (shouldBeActive) {
            cancelPendingDisableIfAny(
                source,
                timeMatched,
                locationMatched,
                appMatched,
                activityMatched
            )
            val activeRuleNamesText = matchingRuleNames.joinToString()
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

            applyDndPolicy(
                notificationManager,
                allowStarredContacts,
                allowRepeatCallers,
                matchingRuleNames
            )

            if (currentFilter != NotificationManager.INTERRUPTION_FILTER_PRIORITY) {
                android.util.Log.d("DndActivity", "DND enabled by automation.")
                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
            }
            AutomationDndStateStore.write(this, true, activeRuleNamesText)
        } else {
            if (allowDisableGrace && currentFilter != NotificationManager.INTERRUPTION_FILTER_ALL) {
                scheduleDisableAfterGrace(
                    source,
                    timeMatched,
                    locationMatched,
                    appMatched,
                    activityMatched,
                    currentForegroundPackage,
                    isCurrentlyInsideGeofence,
                    activeGeofenceIds,
                    currentActivityInt
                )
                return
            }

            if (currentFilter != NotificationManager.INTERRUPTION_FILTER_ALL) {
                android.util.Log.d(
                    "DndActivity",
                    "DND disabled after grace period: still no matching rules. source=$source, time=false, location=false, app=false, activity=false, currentForegroundPackage=$currentForegroundPackage, isInsideGeofence=$isCurrentlyInsideGeofence, activeGeofenceIds=${activeGeofenceIds.joinToString()}, targetAppPackages=${targetAppPackages.joinToString()}, currentActivityInt=$currentActivityInt"
                )
                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
            }
            AutomationDndStateStore.write(this, false, "")
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
