package com.example.dnd_auto_app

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log // 🔹 Added for debugging
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent

class GeofenceBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val geofencingEvent = GeofencingEvent.fromIntent(intent)
        
        if (geofencingEvent == null) {
            Log.e("DndGeofence", "Receiver triggered but event is null")
            return
        }

        if (geofencingEvent.hasError()) {
            Log.e("DndGeofence", "Geofence Error Code: ${geofencingEvent.errorCode}")
            return
        }

        val transition = geofencingEvent.geofenceTransition
        Log.d("DndGeofence", "🚀 GEOFENCE TRANSITION FIRED: Type $transition")

        val prefs = context.getSharedPreferences("DndPrefs", Context.MODE_PRIVATE)
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (transition == Geofence.GEOFENCE_TRANSITION_ENTER) {
            Log.d("DndGeofence", "📍 ENTER event received. Turning DND ON.")
            // 1. Save state persistently
            prefs.edit().putBoolean("isInsideGeofence", true).apply()
            
            // 2. Turn on DND immediately
            if (notificationManager.isNotificationPolicyAccessGranted) {
                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
                Log.d("DndGeofence", "✅ DND Successfully turned ON")
            } else {
                Log.e("DndGeofence", "❌ DND Permission missing!")
            }
            
        } else if (transition == Geofence.GEOFENCE_TRANSITION_EXIT) {
            Log.d("DndGeofence", "🚶 EXIT event received. Pinging service to turn DND OFF.")
            // 1. Save state persistently
            prefs.edit().putBoolean("isInsideGeofence", false).apply()
            
            // 2. Ping service to evaluate using an EXPLICIT intent
            val pingIntent = Intent(DndForegroundService.ACTION_EVALUATE_DND).apply {
                setPackage(context.packageName) 
            }
            context.sendBroadcast(pingIntent)
        }
    }
}