package com.example.dnd_auto_app

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.dnd_auto_app/dnd"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            when (call.method) {
                "checkPermission" -> {
                    result.success(notificationManager.isNotificationPolicyAccessGranted)
                }
                "openDndSettings" -> {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                    startActivity(intent)
                    result.success(null)
                }
                "enableDnd" -> {
                    if (notificationManager.isNotificationPolicyAccessGranted) {
                        notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
                        result.success(null)
                    } else {
                        result.error("PERMISSION_DENIED", "DND access not granted", null)
                    }
                }
                "disableDnd" -> {
                    if (notificationManager.isNotificationPolicyAccessGranted) {
                        notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
                        result.success(null)
                    } else {
                        result.error("PERMISSION_DENIED", "DND access not granted", null)
                    }
                }
                
                // --- FOREGROUND SERVICE CONTROLS ---
                
                "startService", "updateRules" -> {
                    // 1. Extract Time Rules directly from the arguments
                    val startHours = call.argument<ArrayList<Int>>("startHours")?.toIntArray() ?: intArrayOf()
                    val startMinutes = call.argument<ArrayList<Int>>("startMinutes")?.toIntArray() ?: intArrayOf()
                    val endHours = call.argument<ArrayList<Int>>("endHours")?.toIntArray() ?: intArrayOf()
                    val endMinutes = call.argument<ArrayList<Int>>("endMinutes")?.toIntArray() ?: intArrayOf()

                    // 2. Extract Location Rules directly from the arguments
                    val locIds = call.argument<ArrayList<String>>("locIds")?.toTypedArray() ?: emptyArray()
                    val lats = call.argument<ArrayList<Double>>("lats")?.toDoubleArray() ?: doubleArrayOf()
                    val lngs = call.argument<ArrayList<Double>>("lngs")?.toDoubleArray() ?: doubleArrayOf()
                    val rads = call.argument<ArrayList<Int>>("rads")?.toIntArray() ?: intArrayOf()

                    // 3. Pass ALL rules to the Foreground Service
                    val serviceIntent = Intent(this, DndForegroundService::class.java).apply {
                        putExtra("startHours", startHours)
                        putExtra("startMinutes", startMinutes)
                        putExtra("endHours", endHours)
                        putExtra("endMinutes", endMinutes)
                        
                        putExtra("locIds", locIds)
                        putExtra("lats", lats)
                        putExtra("lngs", lngs)
                        putExtra("rads", rads)
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && call.method == "startService") {
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }
                    result.success(null)
                }
                "stopService" -> {
                    val serviceIntent = Intent(this, DndForegroundService::class.java)
                    stopService(serviceIntent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}