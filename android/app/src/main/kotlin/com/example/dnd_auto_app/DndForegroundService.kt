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

class DndForegroundService : Service() {

    private val CHANNEL_ID = "DndServiceChannel"
    private var timer: Timer? = null

    // Default FYP values (we will pass actual values from Flutter later)
    private var startHour = 22 // 10 PM
    private var endHour = 7    // 7 AM

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // 1. Receive the target times from Flutter via Intent
        startHour = intent?.getIntExtra("startHour", 22) ?: 22
        endHour = intent?.getIntExtra("endHour", 7) ?: 7

        // 2. Create the sticky Foreground Notification
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("DND Automation Active")
            .setContentText("Automatically managing DND from $startHour:00 to $endHour:00")
            .setSmallIcon(android.R.drawable.ic_dialog_info) // Default Android icon
            .setOngoing(true)
            .build()

        // 3. Start the service in the foreground (With Android 14+ support)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) { // API 34+
            startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(1, notification)
        }

        // 4. Start the checking loop
        startAutomationLoop()

        // Restart service automatically if the system kills it to save memory
        return START_STICKY 
    }

    private fun startAutomationLoop() {
        timer?.cancel() // Cancel any existing timer
        timer = Timer()

        // Run this check every 1 minute (60,000 milliseconds)
        timer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                checkAndToggleDnd()
            }
        }, 0, 60000)
    }

    private fun checkAndToggleDnd() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Safety check: Make sure the user actually granted DND permission
        if (!notificationManager.isNotificationPolicyAccessGranted) {
            return
        }

        // Get the current hour of the day (0-23)
        val currentHour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)

        // Simple time logic
        val isDndTime = if (startHour < endHour) {
            currentHour in startHour until endHour
        } else {
            // Handles overnight times (e.g., 22 PM to 7 AM)
            currentHour >= startHour || currentHour < endHour
        }

        val currentFilter = notificationManager.currentInterruptionFilter

        // Apply DND if it's time AND it's not already on
        if (isDndTime) {
            if (currentFilter != NotificationManager.INTERRUPTION_FILTER_PRIORITY) {
                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
            }
        } 
        // Turn off DND if it's NOT time AND it is currently on
        else {
            if (currentFilter == NotificationManager.INTERRUPTION_FILTER_PRIORITY) {
                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
            }
        }
    }

    override fun onDestroy() {
        // Stop the timer when the service is destroyed
        timer?.cancel()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        // We return null because this is a "Started Service", not a "Bound Service"
        return null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "DND Automation Service",
                NotificationManager.IMPORTANCE_LOW // Low importance so it doesn't vibrate constantly
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(serviceChannel)
        }
    }
}