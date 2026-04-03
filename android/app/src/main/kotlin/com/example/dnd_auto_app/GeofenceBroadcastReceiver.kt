package com.example.dnd_auto_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent

class GeofenceBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val geofencingEvent = GeofencingEvent.fromIntent(intent)
        
        if (geofencingEvent == null || geofencingEvent.hasError()) {
            Log.e("GeofenceReceiver", "Error receiving geofence event")
            return
        }

        val transition = geofencingEvent.geofenceTransition
        
        if (transition == Geofence.GEOFENCE_TRANSITION_ENTER) {
            DndForegroundService.isInsideGeofence = true
            // Ping service to re-evaluate DND state immediately
            context.sendBroadcast(Intent(DndForegroundService.ACTION_EVALUATE_DND))
        } else if (transition == Geofence.GEOFENCE_TRANSITION_EXIT) {
            DndForegroundService.isInsideGeofence = false
            context.sendBroadcast(Intent(DndForegroundService.ACTION_EVALUATE_DND))
        }
    }
}