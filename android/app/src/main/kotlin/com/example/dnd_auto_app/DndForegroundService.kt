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
    val startHour: Int,
    val startMinute: Int,
    val endHour: Int,
    val endMinute: Int
)

class DndForegroundService : Service() {

    private val CHANNEL_ID = "DndServiceChannel"
    private var timer: Timer? = null
    private var activeRules: List<DndRule> = emptyList()
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

override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // 1. Reconstruct Time Rules
        val startHours = intent?.getIntArrayExtra("startHours") ?: intArrayOf()
        val startMinutes = intent?.getIntArrayExtra("startMinutes") ?: intArrayOf()
        val endHours = intent?.getIntArrayExtra("endHours") ?: intArrayOf()
        val endMinutes = intent?.getIntArrayExtra("endMinutes") ?: intArrayOf()

        val newRules = mutableListOf<DndRule>()
        for (i in startHours.indices) {
            newRules.add(DndRule(startHours[i], startMinutes[i], endHours[i], endMinutes[i]))
        }
        activeRules = newRules

        // 2. Extract Location Rules
        val locIds = intent?.getStringArrayExtra("locIds") ?: emptyArray()
        val lats = intent?.getDoubleArrayExtra("lats") ?: doubleArrayOf()
        val lngs = intent?.getDoubleArrayExtra("lngs") ?: doubleArrayOf()
        val rads = intent?.getIntArrayExtra("rads") ?: intArrayOf()
        
        setupGeofences(locIds, lats, lngs, rads)

        // 3. Extract App Usage Rules
        targetAppPackages = intent?.getStringArrayExtra("appPackages") ?: emptyArray()

        // 4. Extract Activity Rules & Setup
        targetActivityTypes = intent?.getStringArrayExtra("activityTypes") ?: emptyArray()
        setupActivityRecognition(targetActivityTypes.isNotEmpty())

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
        prefs.edit().putBoolean("isInsideGeofence", false).apply()

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

    // Checks if the user is currently inside one of the target apps
    private fun isTargetAppInForeground(): Boolean {
        if (targetAppPackages.isEmpty()) return false

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

        return targetAppPackages.contains(currentForegroundApp)
    }

    private fun checkAndToggleDnd() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!notificationManager.isNotificationPolicyAccessGranted) return

        // 1. Time Check
        val calendar = Calendar.getInstance()
        val currentTotal = (calendar.get(Calendar.HOUR_OF_DAY) * 60) + calendar.get(Calendar.MINUTE)
        var timeRuleMatches = false

        for (rule in activeRules) {
            val startTotal = (rule.startHour * 60) + rule.startMinute
            val endTotal = (rule.endHour * 60) + rule.endMinute

            val isMatch = if (startTotal < endTotal) {
                currentTotal in startTotal until endTotal
            } else if (startTotal > endTotal) {
                currentTotal >= startTotal || currentTotal < endTotal
            } else {
                false 
            }

            if (isMatch) {
                timeRuleMatches = true
                break
            }
        }

        // 2. Location Check
        val prefs = getSharedPreferences("DndPrefs", Context.MODE_PRIVATE)
        val isCurrentlyInsideGeofence = prefs.getBoolean("isInsideGeofence", false)

        // 3. App Check
        val isAppRunning = isTargetAppInForeground()

        // 4. Activity Check with Logging
        var isTargetActivityDetected = false
        val currentActivityInt = prefs.getInt("currentActivityType", DetectedActivity.UNKNOWN)
        
        android.util.Log.d("DndActivity", "Evaluating Rules. Current stored Activity Int: $currentActivityInt. Target Types: ${targetActivityTypes.joinToString()}")

        for (target in targetActivityTypes) {
            val matches = when (target) {
                "IN_VEHICLE" -> currentActivityInt == DetectedActivity.IN_VEHICLE
                "ON_BICYCLE" -> currentActivityInt == DetectedActivity.ON_BICYCLE
                "WALKING" -> currentActivityInt == DetectedActivity.WALKING || currentActivityInt == DetectedActivity.ON_FOOT
                "RUNNING" -> currentActivityInt == DetectedActivity.RUNNING
                "STILL" -> currentActivityInt == DetectedActivity.STILL
                "TILTING" -> currentActivityInt == DetectedActivity.TILTING
                else -> false
            }
            if (matches) {
                isTargetActivityDetected = true
                android.util.Log.d("DndActivity", "MATCH FOUND for Activity: $target")
                break
            }
        }

        // 5. Trigger Evaluation
        val shouldBeActive = timeRuleMatches || isCurrentlyInsideGeofence || isAppRunning || isTargetActivityDetected
        val currentFilter = notificationManager.currentInterruptionFilter

        if (shouldBeActive && currentFilter != NotificationManager.INTERRUPTION_FILTER_PRIORITY) {
            android.util.Log.d("DndActivity", "Enabling DND Mode.")
            notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
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