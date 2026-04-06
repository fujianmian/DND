package com.example.dnd_auto_app

import android.app.AppOpsManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayList
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Handler
import android.os.Looper
import java.io.ByteArrayOutputStream


class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.dnd_auto_app/dnd"

    private fun getIconBytes(pm: PackageManager, packageName: String): ByteArray? {
        return try {
            val icon = pm.getApplicationIcon(packageName)
            val bitmap = getBitmapFromDrawable(icon)
            val stream = ByteArrayOutputStream()
            // Scale icon down to 72x72 to prevent Memory Issues in Flutter
            val scaledBitmap = Bitmap.createScaledBitmap(bitmap, 72, 72, true)
            scaledBitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            stream.toByteArray()
        } catch (e: Exception) {
            null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            when (call.method) {
                // --- DND PERMISSIONS ---
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

                // --- USAGE STATS PERMISSIONS (For App Triggers) ---
                "checkUsagePermission" -> {
                    val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
                    val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
                    } else {
                        appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
                    }
                    result.success(mode == AppOpsManager.MODE_ALLOWED)
                }
                "openUsageSettings" -> {
                    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    startActivity(intent)
                    result.success(null)
                }
                "getInstalledApps" -> {
                    // Run on a background thread so the UI doesn't freeze while loading icons
                    Thread {
                        try {
                            val pm = packageManager
                            val intent = Intent(Intent.ACTION_MAIN, null)
                            intent.addCategory(Intent.CATEGORY_LAUNCHER)
                            
                            val allApps = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                pm.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0L))
                            } else {
                                pm.queryIntentActivities(intent, 0)
                            }

                            val appList = ArrayList<Map<String, Any>>()
                            for (resolveInfo in allApps) {
                                val packageName = resolveInfo.activityInfo.packageName
                                
                                if (appList.none { it["package"] == packageName }) {
                                    val appName = resolveInfo.loadLabel(pm).toString()
                                    val iconBytes = getIconBytes(pm, packageName)
                                    
                                    val map = mutableMapOf<String, Any>(
                                        "name" to appName,
                                        "package" to packageName
                                    )
                                    if (iconBytes != null) map["icon"] = iconBytes
                                    
                                    appList.add(map)
                                }
                            }
                            appList.sortBy { (it["name"] as String).lowercase() }
                            
                            Handler(Looper.getMainLooper()).post { result.success(appList) }
                        } catch (e: Exception) {
                            Handler(Looper.getMainLooper()).post { result.error("ERROR", e.message, null) }
                        }
                    }.start()
                }

                // --- 🔹 ENHANCEMENT 2: Fetch App Info for Rule List Screen ---
                "getAppInfo" -> {
                    val pkgName = call.argument<String>("packageName") ?: return@setMethodCallHandler result.success(null)
                    try {
                        val pm = packageManager
                        val appInfo = pm.getApplicationInfo(pkgName, 0)
                        val name = pm.getApplicationLabel(appInfo).toString()
                        val iconBytes = getIconBytes(pm, pkgName)
                        
                        val map = mutableMapOf<String, Any>("name" to name)
                        if (iconBytes != null) map["icon"] = iconBytes
                        
                        result.success(map)
                    } catch (e: Exception) {
                        result.success(null)
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

                    // 3. Extract App Rules
                    val appPackages = call.argument<ArrayList<String>>("appPackages")?.toTypedArray() ?: emptyArray()

                    // 4. Pass ALL rules to the Foreground Service
                    val serviceIntent = Intent(this, DndForegroundService::class.java).apply {
                        putExtra("startHours", startHours)
                        putExtra("startMinutes", startMinutes)
                        putExtra("endHours", endHours)
                        putExtra("endMinutes", endMinutes)
                        
                        putExtra("locIds", locIds)
                        putExtra("lats", lats)
                        putExtra("lngs", lngs)
                        putExtra("rads", rads)

                        putExtra("appPackages", appPackages)
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