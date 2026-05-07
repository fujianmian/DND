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
import android.os.IBinder
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
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
    private var timer: Timer? = null
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
            checkAndToggleDnd() // Re-evaluate when geofence state changes
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
        // 1. Reconstruct Time Rules
        val startHours = intent?.getIntArrayExtra("startHours") ?: intArrayOf()
        val startMinutes = intent?.getIntArrayExtra("startMinutes") ?: intArrayOf()
        val endHours = intent?.getIntArrayExtra("endHours") ?: intArrayOf()
        val endMinutes = intent?.getIntArrayExtra("endMinutes") ?: intArrayOf()
        val timeRuleIds = intent?.getStringArrayExtra("timeRuleIds") ?: emptyArray()
        val timeRuleNames = intent?.getStringArrayExtra("timeRuleNames") ?: emptyArray()
        val timeAllowStarredContacts = intent?.getBooleanArrayExtra("timeAllowStarredContacts") ?: booleanArrayOf()
        val timeAllowRepeatCallers = intent?.getBooleanArrayExtra("timeAllowRepeatCallers") ?: booleanArrayOf()

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
        val locIds = intent?.getStringArrayExtra("locIds") ?: emptyArray()
        val locNames = intent?.getStringArrayExtra("locNames") ?: emptyArray()
        val lats = intent?.getDoubleArrayExtra("lats") ?: doubleArrayOf()
        val lngs = intent?.getDoubleArrayExtra("lngs") ?: doubleArrayOf()
        val rads = intent?.getIntArrayExtra("rads") ?: intArrayOf()
        val locAllowStarredContacts = intent?.getBooleanArrayExtra("locAllowStarredContacts") ?: booleanArrayOf()
        val locAllowRepeatCallers = intent?.getBooleanArrayExtra("locAllowRepeatCallers") ?: booleanArrayOf()
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
        
        setupGeofences(locIds, lats, lngs, rads)

        // 3. Extract App Usage Rules
        targetAppPackages = intent?.getStringArrayExtra("appPackages") ?: emptyArray()
        val appRuleIds = intent?.getStringArrayExtra("appRuleIds") ?: emptyArray()
        val appRuleNames = intent?.getStringArrayExtra("appRuleNames") ?: emptyArray()
        val appAllowStarredContacts = intent?.getBooleanArrayExtra("appAllowStarredContacts") ?: booleanArrayOf()
        val appAllowRepeatCallers = intent?.getBooleanArrayExtra("appAllowRepeatCallers") ?: booleanArrayOf()
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
        targetActivityTypes = intent?.getStringArrayExtra("activityTypes") ?: emptyArray()
        val activityRuleIds = intent?.getStringArrayExtra("activityRuleIds") ?: emptyArray()
        val activityRuleNames = intent?.getStringArrayExtra("activityRuleNames") ?: emptyArray()
        val activityAllowStarredContacts = intent?.getBooleanArrayExtra("activityAllowStarredContacts") ?: booleanArrayOf()
        val activityAllowRepeatCallers = intent?.getBooleanArrayExtra("activityAllowRepeatCallers") ?: booleanArrayOf()
        targetActivityRules = targetActivityTypes.indices.map { i ->
            DndActivityRule(
                stringAt(activityRuleIds, i, i.toString()),
                stringAt(activityRuleNames, i, "Activity rule ${i + 1}"),
                targetActivityTypes[i],
                boolAt(activityAllowStarredContacts, i),
                boolAt(activityAllowRepeatCallers, i)
            )
        }
        setupActivityRecognition(targetActivityTypes.isNotEmpty())

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
        if (ActivityCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            android.util.Log.e("DndGeofence", "Permission ACCESS_FINE_LOCATION is missing!")
            return 
        }
        
        val pendingIntent = getGeofencePendingIntent()
        geofencingClient.removeGeofences(pendingIntent) 

        // Reset PERSISTENT state
        val prefs = getSharedPreferences("DndPrefs", Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean("isInsideGeofence", false)
            .putStringSet("activeGeofenceIds", emptySet<String>())
            .apply()

        isInsideGeofence = false 

        if (ids.isEmpty()) {
            android.util.Log.d("DndGeofence", "No locations to monitor.")
            return
        }

        val geofenceList = mutableListOf<Geofence>()
        for (i in ids.indices) {
            geofenceList.add(
                Geofence.Builder()
                    .setRequestId(ids[i])
                    .setCircularRegion(lats[i], lngs[i], rads[i].toFloat())
                    .setExpirationDuration(Geofence.NEVER_EXPIRE)
                    .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT)
                    .build()
            )
        }

        val geofencingRequest = GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofences(geofenceList)
            .build()

        geofencingClient.addGeofences(geofencingRequest, pendingIntent).run {
            addOnSuccessListener {
                android.util.Log.d("DndGeofence", "Successfully added ${ids.size} geofences.")
            }
            addOnFailureListener {
                android.util.Log.e("DndGeofence", "Failed to add geofences: ${it.message}")
            }
        }
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
                checkAndToggleDnd()
            }
        }, 0, 3000)
    }

    private fun currentForegroundAppPackage(): String? {
        if (targetAppPackages.isEmpty()) return null

        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val endTime = System.currentTimeMillis()
        val startTime = endTime - 1000 * 60 * 1 // Look at events from the last 1 minute

        val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
        var currentForegroundApp: String? = null
        val event = UsageEvents.Event()

        // Iterate through all events to find the most recent state
        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                currentForegroundApp = event.packageName
            } else if (event.eventType == UsageEvents.Event.ACTIVITY_PAUSED) {
                if (currentForegroundApp == event.packageName) {
                    currentForegroundApp = null
                }
            }
        }

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
        } catch (e: SecurityException) {
            android.util.Log.e("DndExceptions", "Failed to apply DND exception policy: ${e.message}")
        } catch (e: RuntimeException) {
            android.util.Log.e("DndExceptions", "Failed to apply DND exception policy: ${e.message}")
        }
    }

    private fun checkAndToggleDnd() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!notificationManager.isNotificationPolicyAccessGranted) {
            android.util.Log.e("DndExceptions", "DND policy access missing; skipping DND evaluation.")
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
        
        android.util.Log.d("DndActivity", "Evaluating Rules. Current stored Activity Int: $currentActivityInt. Target Types: ${targetActivityTypes.joinToString()}")

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

        if (shouldBeActive) {
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
                android.util.Log.d("DndActivity", "Enabling DND Mode.")
                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
            }
        } else if (!shouldBeActive && currentFilter != NotificationManager.INTERRUPTION_FILTER_ALL) {
            android.util.Log.d("DndActivity", "Disabling DND Mode.")
            notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        android.util.Log.w("DndService", "App swiped away! Requesting OS to keep service alive.")
        
        // Tells Android to restart this Foreground Service if the OS killed it
        val restartServiceIntent = Intent(applicationContext, this.javaClass)
        restartServiceIntent.setPackage(packageName)
        
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
        unregisterReceiver(geofenceUpdateReceiver)
        geofencingClient.removeGeofences(getGeofencePendingIntent())

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (notificationManager.isNotificationPolicyAccessGranted) {
            notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
        }
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
