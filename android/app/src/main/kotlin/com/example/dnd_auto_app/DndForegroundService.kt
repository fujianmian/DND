package com.example.dnd_auto_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
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

        // 3. Foreground Notification
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("DND Automation Active")
            .setContentText("Monitoring ${activeRules.size} time rule(s) & ${locIds.size} location(s)")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(1, notification)
        }

        // 4. Start Time loop
        timer?.cancel()
        startAutomationLoop()

        return START_REDELIVER_INTENT 
    }

    private fun setupGeofences(ids: Array<String>, lats: DoubleArray, lngs: DoubleArray, rads: IntArray) {
        if (ActivityCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            return // Stop if location permission is missing
        }
        
        val pendingIntent = getGeofencePendingIntent()
        geofencingClient.removeGeofences(pendingIntent) // Clear existing geofences
        isInsideGeofence = false // Reset state on update

        if (ids.isEmpty()) return

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

        geofencingClient.addGeofences(geofencingRequest, pendingIntent)
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
        timer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                checkAndToggleDnd()
            }
        }, 0, 60000)
    }

    private fun checkAndToggleDnd() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!notificationManager.isNotificationPolicyAccessGranted) return

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

        // 🔹 MODIFIED: Read the persistent geofence state from SharedPreferences
        // This prevents the state from resetting to false when the app is swiped away.
        val prefs = getSharedPreferences("DndPrefs", Context.MODE_PRIVATE)
        val isCurrentlyInsideGeofence = prefs.getBoolean("isInsideGeofence", false)

        // 🔹 STAGE 8 LOGIC: Trigger DND if Time matches OR if user is inside a Geofence
        val shouldBeActive = timeRuleMatches || isCurrentlyInsideGeofence
        val currentFilter = notificationManager.currentInterruptionFilter

        if (shouldBeActive && currentFilter != NotificationManager.INTERRUPTION_FILTER_PRIORITY) {
            notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
        } else if (!shouldBeActive && currentFilter != NotificationManager.INTERRUPTION_FILTER_ALL) {
            notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
        }
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