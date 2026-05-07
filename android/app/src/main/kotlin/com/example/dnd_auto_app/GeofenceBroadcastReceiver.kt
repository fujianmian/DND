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

        if (geofencingEvent == null) {
            Log.e("DndGeofence", "Receiver triggered but event is null")
            return
        }

        if (geofencingEvent.hasError()) {
            Log.e("DndGeofence", "Geofence Error Code: ${geofencingEvent.errorCode}")
            return
        }

        val transition = geofencingEvent.geofenceTransition
        val triggeredIds = geofencingEvent.triggeringGeofences?.map { it.requestId } ?: emptyList()
        val prefs = context.getSharedPreferences("DndPrefs", Context.MODE_PRIVATE)
        val activeGeofenceIds = prefs.getStringSet("activeGeofenceIds", emptySet<String>())?.toMutableSet()
            ?: mutableSetOf()

        Log.d("DndGeofence", "Geofence transition $transition for ids: ${triggeredIds.joinToString()}")

        if (transition == Geofence.GEOFENCE_TRANSITION_ENTER) {
            activeGeofenceIds.addAll(triggeredIds)
        } else if (transition == Geofence.GEOFENCE_TRANSITION_EXIT) {
            activeGeofenceIds.removeAll(triggeredIds.toSet())
        } else {
            return
        }

        prefs.edit()
            .putBoolean("isInsideGeofence", activeGeofenceIds.isNotEmpty())
            .putStringSet("activeGeofenceIds", activeGeofenceIds)
            .apply()

        val pingIntent = Intent(DndForegroundService.ACTION_EVALUATE_DND).apply {
            setPackage(context.packageName)
        }
        context.sendBroadcast(pingIntent)
    }
}
