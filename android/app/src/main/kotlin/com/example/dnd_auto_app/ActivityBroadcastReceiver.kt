package com.example.dnd_auto_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.Toast
import com.google.android.gms.location.ActivityRecognitionResult
import com.google.android.gms.location.DetectedActivity

class ActivityBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("DndActivity", "BroadcastReceiver fired!")

        if (ActivityRecognitionResult.hasResult(intent)) {
            val result = ActivityRecognitionResult.extractResult(intent)
            val mostProbableActivity = result?.mostProbableActivity

            if (mostProbableActivity != null) {
                val activityName = when (mostProbableActivity.type) {
                    DetectedActivity.IN_VEHICLE -> "IN_VEHICLE"
                    DetectedActivity.ON_BICYCLE -> "ON_BICYCLE"
                    DetectedActivity.ON_FOOT -> "ON_FOOT"
                    DetectedActivity.RUNNING -> "RUNNING"
                    DetectedActivity.STILL -> "STILL"
                    DetectedActivity.TILTING -> "TILTING"
                    DetectedActivity.WALKING -> "WALKING"
                    else -> "UNKNOWN (${mostProbableActivity.type})"
                }

                // Log every update to the console
                Log.d("DndActivity", "Detected: $activityName | Confidence: ${mostProbableActivity.confidence}%")
                
                // Show a visual popup on the screen
                Toast.makeText(context, "$activityName (${mostProbableActivity.confidence}%)", Toast.LENGTH_SHORT).show()

                // Save to preferences if confidence is decent
                if (mostProbableActivity.confidence > 40) { // Lowered to 40% for easier testing
                    val prefs = context.getSharedPreferences("DndPrefs", Context.MODE_PRIVATE)
                    prefs.edit().putInt("currentActivityType", mostProbableActivity.type).apply()
                    
                    Log.d("DndActivity", "Saved $activityName to SharedPreferences. Triggering evaluation.")
                    val updateIntent = Intent(DndForegroundService.ACTION_EVALUATE_DND)
                    context.sendBroadcast(updateIntent)
                }
            }
        } else {
            Log.e("DndActivity", "Received intent, but it contained no ActivityRecognitionResult.")
        }
    }
}