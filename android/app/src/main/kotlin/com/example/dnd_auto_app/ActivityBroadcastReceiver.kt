package com.example.dnd_auto_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.ActivityRecognitionResult

class ActivityBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (ActivityRecognitionResult.hasResult(intent)) {
            val result = ActivityRecognitionResult.extractResult(intent)
            val mostProbableActivity = result?.mostProbableActivity

            // Update globally stored activity if confidence is reasonably high (>50%)
            if (mostProbableActivity != null && mostProbableActivity.confidence > 50) {
                val prefs = context.getSharedPreferences("DndPrefs", Context.MODE_PRIVATE)
                prefs.edit().putInt("currentActivityType", mostProbableActivity.type).apply()
                
                // Trigger the Foreground Service to re-evaluate rules
                val updateIntent = Intent(DndForegroundService.ACTION_EVALUATE_DND)
                context.sendBroadcast(updateIntent)
            }
        }
    }
}