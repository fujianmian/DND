package com.example.dnd_auto_app

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent

class GeofenceBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val geofencingEvent = GeofencingEvent.fromIntent(intent)
        
        if (geofencingEvent == null || geofencingEvent.hasError()) return

        val transition = geofencingEvent.geofenceTransition
        val prefs = context.getSharedPreferences("DndPrefs", Context.MODE_PRIVATE)
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (transition == Geofence.GEOFENCE_TRANSITION_ENTER) {
            // 1. Save state persistently
            prefs.edit().putBoolean("isInsideGeofence", true).apply()
            
            // 2. Turn on DND immediately
            if (notificationManager.isNotificationPolicyAccessGranted) {
                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
            }
        } else if (transition == Geofence.GEOFENCE_TRANSITION_EXIT) {
            // 1. Save state persistently
            prefs.edit().putBoolean("isInsideGeofence", false).apply()
            
            // 2. Ping service to evaluate using an EXPLICIT intent
            val pingIntent = Intent(DndForegroundService.ACTION_EVALUATE_DND).apply {
                setPackage(context.packageName) // This forces instant delivery
            }
            context.sendBroadcast(pingIntent)
        }
    }
}