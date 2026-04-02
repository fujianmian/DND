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
                    // Extract the list of rules mapped in Flutter
                    val rulesList = call.argument<List<Map<String, Int>>>("rules") ?: emptyList()
                    
                    // Break down maps into arrays for safe Intent passing
                    val startHours = rulesList.map { it["startHour"] ?: 0 }.toIntArray()
                    val startMinutes = rulesList.map { it["startMinute"] ?: 0 }.toIntArray()
                    val endHours = rulesList.map { it["endHour"] ?: 0 }.toIntArray()
                    val endMinutes = rulesList.map { it["endMinute"] ?: 0 }.toIntArray()

                    val serviceIntent = Intent(this, DndForegroundService::class.java).apply {
                        putExtra("startHours", startHours)
                        putExtra("startMinutes", startMinutes)
                        putExtra("endHours", endHours)
                        putExtra("endMinutes", endMinutes)
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && call.method == "startService") {
                        startForegroundService(serviceIntent)
                    } else {
                        // Using startService on an existing Foreground Service acts as an update
                        // triggering onStartCommand again without tearing it down
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