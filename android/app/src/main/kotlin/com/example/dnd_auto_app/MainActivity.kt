package com.example.dnd_auto_app

import android.app.AppOpsManager
import android.Manifest
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
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
    private val KEYWORD_BYPASS_PREFS = "quietly_keyword_bypass_prefs"
    private val KEYWORD_BYPASS_ENABLED = "keywordBypassEnabled"
    private val KEYWORD_BYPASS_KEYWORDS = "keywordBypassKeywords"
    private val KEYWORD_BYPASS_PACKAGES = "keywordBypassPackages"

    private fun isNotificationListenerEnabled(): Boolean {
        val enabledListeners = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        ) ?: return false
        val expectedComponent = ComponentName(
            this,
            EmergencyNotificationListenerService::class.java
        )

        return enabledListeners.split(":").any { flattenedComponent ->
            val enabledComponent = ComponentName.unflattenFromString(flattenedComponent)
            enabledComponent?.packageName == packageName &&
                enabledComponent.className == expectedComponent.className
        }
    }

    private fun defaultKeywordBypassKeywords(): Set<String> {
        return linkedSetOf("urgent", "emergency", "asap")
    }

    private fun stringListArg(call: MethodCall, name: String): List<String> {
        return call.argument<ArrayList<String>>(name)
            ?.map { it.trim() }
            ?.filter { it.isNotEmpty() }
            ?: emptyList()
    }

    private fun getKeywordBypassSettings(): Map<String, Any> {
        val prefs = getSharedPreferences(KEYWORD_BYPASS_PREFS, Context.MODE_PRIVATE)
        val keywords = if (prefs.contains(KEYWORD_BYPASS_KEYWORDS)) {
            prefs.getStringSet(KEYWORD_BYPASS_KEYWORDS, emptySet()) ?: emptySet()
        } else {
            defaultKeywordBypassKeywords()
        }
        val packages = prefs.getStringSet(KEYWORD_BYPASS_PACKAGES, emptySet()) ?: emptySet()

        return mapOf(
            "enabled" to prefs.getBoolean(KEYWORD_BYPASS_ENABLED, false),
            "keywords" to keywords.toList(),
            "packages" to packages.toList()
        )
    }

    private fun automationPauseStateMap(state: AutomationPauseState): Map<String, Any> {
        return mapOf(
            "automationPaused" to state.automationPaused,
            "pauseUntilMillis" to state.pauseUntilMillis,
            "pausedAtMillis" to state.pausedAtMillis,
            "pauseReason" to state.pauseReason
        )
    }

    private fun pauseDurationMillisArg(call: MethodCall): Long? {
        val args = call.arguments as? Map<*, *> ?: return null
        return (args["durationMillis"] as? Number)?.toLong()
    }

    private fun requestAutomationEvaluation(reason: String) {
        try {
            sendBroadcast(
                Intent(DndForegroundService.ACTION_EVALUATE_DND).apply {
                    setPackage(packageName)
                }
            )
            android.util.Log.d(
                "DndAutomationPause",
                "Immediate automation evaluation broadcast sent. reason=$reason"
            )
        } catch (e: Exception) {
            android.util.Log.e(
                "DndAutomationPause",
                "Failed to send automation evaluation broadcast. reason=$reason, exception=${e::class.java.simpleName}, message=${e.message}"
            )
        }

        val serviceIntent = Intent(this, DndForegroundService::class.java).apply {
            action = CachedRulePayloadStore.ACTION_RESTORE_FROM_CACHE
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
            android.util.Log.d(
                "DndAutomationPause",
                "Automation service evaluation requested. reason=$reason"
            )
        } catch (e: Exception) {
            android.util.Log.e(
                "DndAutomationPause",
                "Failed to request automation service evaluation. reason=$reason, exception=${e::class.java.simpleName}, message=${e.message}"
            )
        }
    }

    private fun getAppDebugInfo(): Map<String, Any> {
        val pm = packageManager
        val appInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getApplicationInfo(packageName, PackageManager.ApplicationInfoFlags.of(0L))
        } else {
            @Suppress("DEPRECATION")
            pm.getApplicationInfo(packageName, 0)
        }
        val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getPackageInfo(
                packageName,
                PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong())
            )
        } else {
            @Suppress("DEPRECATION")
            pm.getPackageInfo(packageName, PackageManager.GET_PERMISSIONS)
        }
        val hasInternetPermission = packageInfo.requestedPermissions
            ?.contains(Manifest.permission.INTERNET) ?: false
        val defaultWebClientIdIdentifier = resources.getIdentifier(
            "default_web_client_id",
            "string",
            packageName
        )
        val hasDefaultWebClientId = defaultWebClientIdIdentifier != 0 &&
            resources.getString(defaultWebClientIdIdentifier).isNotBlank()

        return mapOf(
            "packageName" to packageName,
            "applicationId" to applicationContext.packageName,
            "appLabel" to pm.getApplicationLabel(appInfo).toString(),
            "androidSdkInt" to Build.VERSION.SDK_INT,
            "internetPermissionDeclared" to hasInternetPermission,
            "defaultWebClientIdResourcePresent" to hasDefaultWebClientId
        )
    }

    private fun saveKeywordBypassSettings(call: MethodCall) {
        val enabled = call.argument<Boolean>("enabled") ?: false
        val keywords = stringListArg(call, "keywords").toSet()
        val packages = stringListArg(call, "packages").toSet()

        getSharedPreferences(KEYWORD_BYPASS_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEYWORD_BYPASS_ENABLED, enabled)
            .putStringSet(KEYWORD_BYPASS_KEYWORDS, keywords)
            .putStringSet(KEYWORD_BYPASS_PACKAGES, packages)
            .apply()
    }

    private fun getSelectedAppBypassSettings(): Map<String, Any> {
        val settings = SelectedAppBypassSettingsStore.read(this)
        return mapOf(
            "enabled" to settings.enabled,
            "packages" to settings.packages.toList()
        )
    }

    private fun saveSelectedAppBypassSettings(call: MethodCall) {
        val enabled = call.argument<Boolean>("enabled") ?: false
        val packages = stringListArg(call, "packages").toSet()

        SelectedAppBypassSettingsStore.save(
            context = this,
            enabled = enabled,
            packages = packages
        )
    }

    private fun booleanArrayArg(call: MethodCall, name: String): BooleanArray {
        val values = call.argument<ArrayList<Boolean>>(name) ?: return booleanArrayOf()
        return BooleanArray(values.size) { index -> values[index] }
    }

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
    private fun getBitmapFromDrawable(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable) {
            return drawable.bitmap
        }
        val bitmap = Bitmap.createBitmap(
            drawable.intrinsicWidth.coerceAtLeast(1),
            drawable.intrinsicHeight.coerceAtLeast(1),
            Bitmap.Config.ARGB_8888
        )
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
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
                "isNotificationListenerEnabled" -> {
                    result.success(isNotificationListenerEnabled())
                }
                "openNotificationListenerSettings" -> {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    startActivity(intent)
                    result.success(null)
                }
                "checkNotificationPermission" -> {
                    val isGranted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                    result.success(isGranted)
                }
                "getKeywordBypassSettings" -> {
                    result.success(getKeywordBypassSettings())
                }
                "getSelectedAppBypassSettings" -> {
                    result.success(getSelectedAppBypassSettings())
                }
                "getAutomationDndState" -> {
                    val automationState = AutomationDndStateStore.read(this)
                    result.success(
                        mapOf(
                            "automationDndActive" to automationState.automationDndActive,
                            "activeAutomationRuleNames" to automationState.activeAutomationRuleNames,
                            "lastAutomationDndChangedAt" to automationState.lastAutomationDndChangedAt
                        )
                    )
                }
                "getAutomationPauseState" -> {
                    result.success(automationPauseStateMap(AutomationPauseStateStore.read(this)))
                }
                "pauseAutomation" -> {
                    AutomationPauseStateStore.pause(this, pauseDurationMillisArg(call))
                    requestAutomationEvaluation("pauseAutomation")
                    result.success(automationPauseStateMap(AutomationPauseStateStore.read(this)))
                }
                "resumeAutomation" -> {
                    AutomationPauseStateStore.resume(this)
                    requestAutomationEvaluation("resumeAutomation")
                    result.success(automationPauseStateMap(AutomationPauseStateStore.read(this)))
                }
                "getAppDebugInfo" -> {
                    try {
                        result.success(getAppDebugInfo())
                    } catch (e: Exception) {
                        result.error("APP_DEBUG_INFO_FAILED", e.message, null)
                    }
                }
                "saveKeywordBypassSettings" -> {
                    saveKeywordBypassSettings(call)
                    result.success(null)
                }
                "saveSelectedAppBypassSettings" -> {
                    saveSelectedAppBypassSettings(call)
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
                    val timeRepeatModes = call.argument<ArrayList<Int>>("timeRepeatModes")?.toIntArray() ?: intArrayOf()
                    val timeRepeatDaysMasks = call.argument<ArrayList<Int>>("timeRepeatDaysMasks")?.toIntArray() ?: intArrayOf()
                    val timeRuleIds = call.argument<ArrayList<String>>("timeRuleIds")?.toTypedArray() ?: emptyArray()
                    val timeRuleNames = call.argument<ArrayList<String>>("timeRuleNames")?.toTypedArray() ?: emptyArray()
                    val timeAllowStarredContacts = booleanArrayArg(call, "timeAllowStarredContacts")
                    val timeAllowRepeatCallers = booleanArrayArg(call, "timeAllowRepeatCallers")

                    // 2. Extract Location Rules directly from the arguments
                    val locIds = call.argument<ArrayList<String>>("locIds")?.toTypedArray() ?: emptyArray()
                    val locNames = call.argument<ArrayList<String>>("locNames")?.toTypedArray() ?: emptyArray()
                    val lats = call.argument<ArrayList<Double>>("lats")?.toDoubleArray() ?: doubleArrayOf()
                    val lngs = call.argument<ArrayList<Double>>("lngs")?.toDoubleArray() ?: doubleArrayOf()
                    val rads = call.argument<ArrayList<Int>>("rads")?.toIntArray() ?: intArrayOf()
                    val locAllowStarredContacts = booleanArrayArg(call, "locAllowStarredContacts")
                    val locAllowRepeatCallers = booleanArrayArg(call, "locAllowRepeatCallers")

                    // 3. Extract App Rules
                    val appRuleIds = call.argument<ArrayList<String>>("appRuleIds")?.toTypedArray() ?: emptyArray()
                    val appRuleNames = call.argument<ArrayList<String>>("appRuleNames")?.toTypedArray() ?: emptyArray()
                    val appPackages = call.argument<ArrayList<String>>("appPackages")?.toTypedArray() ?: emptyArray()
                    val appAllowStarredContacts = booleanArrayArg(call, "appAllowStarredContacts")
                    val appAllowRepeatCallers = booleanArrayArg(call, "appAllowRepeatCallers")

                    // 4. Extract Activity Rules
                    val activityRuleIds = call.argument<ArrayList<String>>("activityRuleIds")?.toTypedArray() ?: emptyArray()
                    val activityRuleNames = call.argument<ArrayList<String>>("activityRuleNames")?.toTypedArray() ?: emptyArray()
                    val activityTypes = call.argument<ArrayList<String>>("activityTypes")?.toTypedArray() ?: emptyArray()   
                    val activityAllowStarredContacts = booleanArrayArg(call, "activityAllowStarredContacts")
                    val activityAllowRepeatCallers = booleanArrayArg(call, "activityAllowRepeatCallers")
                    val automationRulesJson = call.argument<String>("automationRulesJson") ?: ""
                    val calendarBusyWindowsJson = call.argument<String>("calendarBusyWindowsJson") ?: "[]"

                    // Pass ALL rules to the Foreground Service
                    val serviceIntent = Intent(this, DndForegroundService::class.java).apply {
                        putExtra("startHours", startHours)
                        putExtra("startMinutes", startMinutes)
                        putExtra("endHours", endHours)
                        putExtra("endMinutes", endMinutes)
                        putExtra("timeRepeatModes", timeRepeatModes)
                        putExtra("timeRepeatDaysMasks", timeRepeatDaysMasks)
                        putExtra("timeRuleIds", timeRuleIds)
                        putExtra("timeRuleNames", timeRuleNames)
                        putExtra("timeAllowStarredContacts", timeAllowStarredContacts)
                        putExtra("timeAllowRepeatCallers", timeAllowRepeatCallers)
                        
                        putExtra("locIds", locIds)
                        putExtra("locNames", locNames)
                        putExtra("lats", lats)
                        putExtra("lngs", lngs)
                        putExtra("rads", rads)
                        putExtra("locAllowStarredContacts", locAllowStarredContacts)
                        putExtra("locAllowRepeatCallers", locAllowRepeatCallers)

                        putExtra("appRuleIds", appRuleIds)
                        putExtra("appRuleNames", appRuleNames)
                        putExtra("appPackages", appPackages)
                        putExtra("appAllowStarredContacts", appAllowStarredContacts)
                        putExtra("appAllowRepeatCallers", appAllowRepeatCallers)

                        putExtra("activityRuleIds", activityRuleIds)
                        putExtra("activityRuleNames", activityRuleNames)
                        putExtra("activityTypes", activityTypes)
                        putExtra("activityAllowStarredContacts", activityAllowStarredContacts)
                        putExtra("activityAllowRepeatCallers", activityAllowRepeatCallers)
                        putExtra("automationRulesJson", automationRulesJson)
                        putExtra("calendarBusyWindowsJson", calendarBusyWindowsJson)
                        CachedRulePayloadStore.markPayloadPresent(this)
                    }
                    CachedRulePayloadStore.saveFromIntent(this, serviceIntent)

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
