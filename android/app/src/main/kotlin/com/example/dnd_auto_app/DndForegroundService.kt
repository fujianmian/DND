package com.example.dnd_auto_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.util.Calendar
import java.util.Timer
import java.util.TimerTask

// Simple memory structure for rules
data class DndRule(
    val startHour: Int,
    val startMinute: Int,
    val endHour: Int,
    val endMinute: Int
)

class DndForegroundService : Service() {

    private val CHANNEL_ID = "DndServiceChannel"
    private var timer: Timer? = null
    
    // In-memory list to hold all active rules from Flutter
    private var activeRules: List<DndRule> = emptyList()

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // 1. Receive array data from Flutter and reconstruct the rules list
        val startHours = intent?.getIntArrayExtra("startHours") ?: intArrayOf()
        val startMinutes = intent?.getIntArrayExtra("startMinutes") ?: intArrayOf()
        val endHours = intent?.getIntArrayExtra("endHours") ?: intArrayOf()
        val endMinutes = intent?.getIntArrayExtra("endMinutes") ?: intArrayOf()

        val newRules = mutableListOf<DndRule>()
        for (i in startHours.indices) {
            newRules.add(DndRule(startHours[i], startMinutes[i], endHours[i], endMinutes[i]))
        }
        activeRules = newRules

        // 2. Create/Update the sticky Foreground Notification
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("DND Automation Active")
            .setContentText("Monitoring ${activeRules.size} active rule(s)")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .build()

        // 3. Start or update the service in the foreground
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(1, notification)
        }

        // 4. Start the checking loop if not already running
        timer?.cancel()
        startAutomationLoop()

        return START_STICKY 
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

        if (!notificationManager.isNotificationPolicyAccessGranted) {
            return
        }

        val calendar = Calendar.getInstance()
        val currentTotal = (calendar.get(Calendar.HOUR_OF_DAY) * 60) + calendar.get(Calendar.MINUTE)

        var anyRuleMatches = false

        // Loop through all rules to see if ANY rule applies right now
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
                anyRuleMatches = true
                break // Early exit, we found a match so DND must be ON
            }
        }

        val currentFilter = notificationManager.currentInterruptionFilter

        // Apply DND if ANY rule matched AND it's not already on
        if (anyRuleMatches) {
            if (currentFilter != NotificationManager.INTERRUPTION_FILTER_PRIORITY) {
                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
            }
        } 
        // Turn off DND if NO rules matched
        else {
            if (currentFilter != NotificationManager.INTERRUPTION_FILTER_ALL) {
                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
            }
        }
    }

    override fun onDestroy() {
        timer?.cancel()

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (notificationManager.isNotificationPolicyAccessGranted) {
            notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
        }

        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

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