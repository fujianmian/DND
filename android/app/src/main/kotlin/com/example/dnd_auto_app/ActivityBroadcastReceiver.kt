package com.example.dnd_auto_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.app.ActivityCompat
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityRecognitionResult

class ActivityBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_ACTIVITY_RECOGNITION_DEBUG_REGISTER) {
            registerDiagnosticActivityRecognition(context)
            return
        }
        if (intent.action == ACTION_ACTIVITY_RECOGNITION_DEBUG_REMOVE) {
            removeDiagnosticActivityRecognition(context)
            return
        }
        if (intent.action == ACTION_ACTIVITY_RECOGNITION_DEBUG_SIMULATE) {
            simulateDiagnosticActivitySnapshot(context, intent)
            return
        }

        val hasResult = ActivityRecognitionResult.hasResult(intent)
        Log.w(
            "DndActivity",
            "ActivityBroadcastReceiver onReceive reached: action=${intent.action}, component=${intent.component}, hasActivityResult=$hasResult"
        )
        Log.d(
            "DndActivity",
            "BroadcastReceiver fired: action=${intent.action}, hasActivityResult=$hasResult"
        )

        if (!hasResult) {
            Log.e("DndActivity", "Received intent, but it contained no ActivityRecognitionResult.")
            return
        }

        val result = ActivityRecognitionResult.extractResult(intent)
        val mostProbableActivity = result?.mostProbableActivity
        if (result == null || mostProbableActivity == null) {
            Log.e("DndActivity", "ActivityRecognitionResult was empty.")
            return
        }

        val confidencesByType = result.probableActivities
            .groupBy { it.type }
            .mapValues { entry -> entry.value.maxOf { it.confidence } }
        val activityName = detectedActivityName(mostProbableActivity.type)
        val detectedSummary = result.probableActivities.joinToString { activity ->
            "${detectedActivityName(activity.type)}=${activity.confidence}%"
        }

        Log.d(
            "DndActivity",
            "Detected activities: count=${result.probableActivities.size}, mostProbable=$activityName (${mostProbableActivity.confidence}%), all=[$detectedSummary]"
        )

        val savedAt = System.currentTimeMillis()
        val prefs = context.getSharedPreferences("DndPrefs", Context.MODE_PRIVATE)
        val editor = prefs.edit()
            .putInt("currentActivityType", mostProbableActivity.type)
            .putInt("currentActivityConfidence", mostProbableActivity.confidence)
            .putLong(ACTIVITY_SNAPSHOT_UPDATED_AT_PREF, savedAt)

        KNOWN_DETECTED_ACTIVITY_TYPES.forEach { activityType ->
            editor.putInt(
                activityConfidencePrefKey(activityType),
                confidencesByType[activityType] ?: 0
            )
        }
        editor.apply()

        Log.d(
            "DndActivity",
            "Saved activity confidence snapshot at $savedAt. Triggering DND evaluation."
        )

        val updateIntent = Intent(DndForegroundService.ACTION_EVALUATE_DND)
        updateIntent.setPackage(context.packageName)
        context.sendBroadcast(updateIntent)
    }

    private fun registerDiagnosticActivityRecognition(context: Context) {
        val pendingResult = goAsync()
        val appContext = context.applicationContext
        val permissionGranted = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            ActivityCompat.checkSelfPermission(
                appContext,
                android.Manifest.permission.ACTIVITY_RECOGNITION
            ) == PackageManager.PERMISSION_GRANTED
        val playServicesStatus = GoogleApiAvailability.getInstance()
            .isGooglePlayServicesAvailable(appContext)
        val powerManager = appContext.getSystemService(Context.POWER_SERVICE) as PowerManager
        val ignoringBatteryOptimizations = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            powerManager.isIgnoringBatteryOptimizations(appContext.packageName)
        } else {
            true
        }
        val pendingIntent = activityRecognitionPendingIntent(appContext)

        Log.w(
            "DndActivity",
            "Diagnostic Activity Recognition register requested: permissionGranted=$permissionGranted, playServicesStatus=$playServicesStatus (${playServicesStatusName(playServicesStatus)}), batteryOptimizationIgnored=$ignoringBatteryOptimizations, requestCode=$ACTIVITY_RECOGNITION_REQUEST_CODE, action=$ACTION_ACTIVITY_RECOGNITION_UPDATE, mutable=true"
        )

        if (!permissionGranted) {
            Log.e("DndActivity", "Diagnostic Activity Recognition register skipped: ACTIVITY_RECOGNITION permission missing.")
            pendingResult.finish()
            return
        }

        ActivityRecognition.getClient(appContext)
            .requestActivityUpdates(ACTIVITY_UPDATE_INTERVAL_MS, pendingIntent)
            .addOnSuccessListener {
                Log.w("DndActivity", "Diagnostic Activity Recognition register SUCCESS.")
                pendingResult.finish()
            }
            .addOnFailureListener { e ->
                val statusCode = (e as? ApiException)?.statusCode
                val statusText = statusCode?.let { ", statusCode=$it" } ?: ""
                Log.e(
                    "DndActivity",
                    "Diagnostic Activity Recognition register FAILED: exception=${e::class.java.simpleName}$statusText, message=${e.message}"
                )
                pendingResult.finish()
            }
    }

    private fun removeDiagnosticActivityRecognition(context: Context) {
        val pendingResult = goAsync()
        val appContext = context.applicationContext
        val pendingIntent = activityRecognitionPendingIntent(appContext)
        Log.w(
            "DndActivity",
            "Diagnostic Activity Recognition remove requested: requestCode=$ACTIVITY_RECOGNITION_REQUEST_CODE, action=$ACTION_ACTIVITY_RECOGNITION_UPDATE"
        )
        ActivityRecognition.getClient(appContext)
            .removeActivityUpdates(pendingIntent)
            .addOnSuccessListener {
                Log.w("DndActivity", "Diagnostic Activity Recognition remove SUCCESS.")
                pendingResult.finish()
            }
            .addOnFailureListener { e ->
                val statusCode = (e as? ApiException)?.statusCode
                val statusText = statusCode?.let { ", statusCode=$it" } ?: ""
                Log.e(
                    "DndActivity",
                    "Diagnostic Activity Recognition remove FAILED: exception=${e::class.java.simpleName}$statusText, message=${e.message}"
                )
                pendingResult.finish()
            }
    }

    private fun simulateDiagnosticActivitySnapshot(context: Context, intent: Intent) {
        val appContext = context.applicationContext
        val requestedActivity = intent.getStringExtra("activity")
        val confidence = intent.getIntExtra("confidence", DEFAULT_ACTIVITY_CONFIDENCE_THRESHOLD)
            .coerceIn(0, 100)

        Log.w(
            "DndActivity",
            "Debug simulate broadcast received: activity=$requestedActivity, confidence=$confidence, debug=${BuildConfig.DEBUG}"
        )

        if (!BuildConfig.DEBUG) {
            Log.w("DndActivity", "Debug activity simulation disabled in non-debug build.")
            return
        }

        val activityType = detectedActivityTypeForRuleActivity(requestedActivity)
        if (activityType == null) {
            Log.e(
                "DndActivity",
                "Debug simulated activity snapshot ignored: unknown activity=$requestedActivity"
            )
            return
        }

        val savedAt = System.currentTimeMillis()
        val prefs = appContext.getSharedPreferences("DndPrefs", Context.MODE_PRIVATE)
        val editor = prefs.edit()
            .putInt("currentActivityType", activityType)
            .putInt("currentActivityConfidence", confidence)
            .putLong(ACTIVITY_SNAPSHOT_UPDATED_AT_PREF, savedAt)

        KNOWN_DETECTED_ACTIVITY_TYPES.forEach { knownType ->
            editor.putInt(
                activityConfidencePrefKey(knownType),
                if (knownType == activityType) confidence else 0
            )
        }
        editor.apply()

        val activityName = detectedActivityName(activityType)
        Log.w(
            "DndActivity",
            "Debug simulated activity snapshot: activity=$activityName, detectedType=$activityType, confidence=$confidence, timestamp=$savedAt"
        )
        Log.w("DndActivity", "Triggering DND evaluation from simulated activity.")

        val updateIntent = Intent(DndForegroundService.ACTION_EVALUATE_DND)
        updateIntent.setPackage(appContext.packageName)
        appContext.sendBroadcast(updateIntent)
    }

    private fun playServicesStatusName(status: Int): String {
        return when (status) {
            ConnectionResult.SUCCESS -> "SUCCESS"
            ConnectionResult.SERVICE_MISSING -> "SERVICE_MISSING"
            ConnectionResult.SERVICE_VERSION_UPDATE_REQUIRED -> "SERVICE_VERSION_UPDATE_REQUIRED"
            ConnectionResult.SERVICE_DISABLED -> "SERVICE_DISABLED"
            ConnectionResult.SERVICE_INVALID -> "SERVICE_INVALID"
            else -> "status=$status"
        }
    }
}
