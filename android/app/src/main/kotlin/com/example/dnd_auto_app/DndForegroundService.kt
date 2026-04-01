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

    // Default FYP values updated to include minutes
    private var startHour = 22 // 10 PM
    private var startMinute = 0
    private var endHour = 7    // 7 AM
    private var endMinute = 0

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // 1. Receive the target times from Flutter via Intent (Now includes minutes)
        startHour = intent?.getIntExtra("startHour", 22) ?: 22
        startMinute = intent?.getIntExtra("startMinute", 0) ?: 0
        endHour = intent?.getIntExtra("endHour", 7) ?: 7
        endMinute = intent?.getIntExtra("endMinute", 0) ?: 0

        // Format times nicely for the notification (e.g., 07:05)
        val startTimeStr = String.format("%02d:%02d", startHour, startMinute)
        val endTimeStr = String.format("%02d:%02d", endHour, endMinute)

        // 2. Create the sticky Foreground Notification
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("DND Automation Active")
            .setContentText("Automatically managing DND from $startTimeStr to $endTimeStr")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
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

        return START_STICKY 
    }

    private fun startAutomationLoop() {
        timer?.cancel()
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

        // Get the current hour and minute
        val calendar = Calendar.getInstance()
        val currentHour = calendar.get(Calendar.HOUR_OF_DAY)
        val currentMinute = calendar.get(Calendar.MINUTE)

        // Calculate total minutes for precise comparison
        val currentTotal = (currentHour * 60) + currentMinute
        val startTotal = (startHour * 60) + startMinute
        val endTotal = (endHour * 60) + endMinute

        // Minute-level time logic
        val isDndTime = if (startTotal < endTotal) {
            // Normal daytime schedule (e.g., 14:30 to 14:45)
            currentTotal in startTotal until endTotal
        } else if (startTotal > endTotal) {
            // Overnight schedule (e.g., 22:30 to 07:15)
            currentTotal >= startTotal || currentTotal < endTotal
        } else {
            false // Fallback if start and end are exactly the exact same minute
        }

        val currentFilter = notificationManager.currentInterruptionFilter

        // Apply DND if it's time AND it's not already on
        if (isDndTime) {
            if (currentFilter != NotificationManager.INTERRUPTION_FILTER_PRIORITY) {
                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
            }
        } 
        // Turn off DND if it's NOT time (Safely checking != ALL so it forces it off properly)
        else {
            if (currentFilter != NotificationManager.INTERRUPTION_FILTER_ALL) {
                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
            }
        }
    }

    override fun onDestroy() {
        timer?.cancel()
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