package com.example.dnd_auto_app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.core.app.NotificationCompat
import java.security.MessageDigest
import java.util.Locale

class EmergencyNotificationListenerService : NotificationListenerService() {
    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "Notification listener connected.")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d(TAG, "Notification listener disconnected.")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val postedAt = System.currentTimeMillis()
        val automationState = AutomationDndStateStore.read(this)
        Log.d(
            TAG,
            "Notification listener callback: at=$postedAt, package=${sbn.packageName}, id=${sbn.id}, key=${sbn.key}, postTime=${sbn.postTime}, listenerDelayMs=${postedAt - sbn.postTime}, automationDndActive=${automationState.automationDndActive}, activeAutomationRuleNames=${automationState.activeAutomationRuleNames}, lastAutomationDndChangedAt=${automationState.lastAutomationDndChangedAt}"
        )

        if (!automationState.automationDndActive) {
            Log.d(TAG, "Notification bypass skipped: automation DND inactive. package=${sbn.packageName}")
            return
        }
        if (sbn.packageName == packageName) {
            Log.d(TAG, "Notification bypass skipped: ignoring Quietly notification.")
            return
        }

        if (handleKeywordBypass(sbn)) {
            return
        }
        handlePriorityAppAlert(sbn)
    }

    private fun handleKeywordBypass(sbn: StatusBarNotification): Boolean {
        val settings = KeywordBypassSettingsStore.read(this)
        if (!settings.enabled) {
            Log.d(TAG, "Keyword bypass skipped: setting disabled. package=${sbn.packageName}")
            return false
        }
        if (settings.packages.isEmpty()) {
            Log.d(TAG, "Keyword bypass skipped: no monitored packages configured. package=${sbn.packageName}")
            return false
        }
        if (!settings.packages.contains(sbn.packageName)) {
            Log.d(TAG, "Keyword bypass skipped: package not monitored. package=${sbn.packageName}")
            return false
        }
        Log.d(TAG, "Keyword bypass package monitored. package=${sbn.packageName}, monitoredPackageCount=${settings.packages.size}")

        val extractedText = extractNotificationText(sbn.notification)
        if (extractedText.isBlank()) {
            Log.d(TAG, "Keyword bypass skipped: no readable notification text. package=${sbn.packageName}")
            return false
        }

        val normalizedText = normalizeText(extractedText)
        val matchedKeyword = settings.keywords.firstOrNull { keyword ->
            normalizedText.contains(keyword.lowercase(Locale.ROOT))
        } ?: run {
            Log.d(TAG, "Keyword bypass skipped: no keyword matched. package=${sbn.packageName}, keywordCount=${settings.keywords.size}")
            return false
        }

        val contentIdentity = "${sbn.packageName}:${sha256(normalizedText)}"
        if (isDuplicateSuppressed(sbn.key, contentIdentity)) {
            Log.d(
                TAG,
                "Suppressed duplicate emergency keyword match: at=${System.currentTimeMillis()}, package=${sbn.packageName}, id=${sbn.id}, key=${sbn.key}, keyword=$matchedKeyword, cooldownMs=$COOLDOWN_MS"
            )
            return true
        }

        rememberMatch(sbn.key, contentIdentity)
        Log.d(
            TAG,
            "Emergency keyword match detected: at=${System.currentTimeMillis()}, package=${sbn.packageName}, id=${sbn.id}, key=${sbn.key}, keyword=$matchedKeyword"
        )
        postEmergencyAlert(sbn)
        return true
    }

    private fun handlePriorityAppAlert(sbn: StatusBarNotification) {
        val settings = SelectedAppBypassSettingsStore.read(this)
        val packageSelected = settings.packages.contains(sbn.packageName)
        Log.d(
            TAG,
            "Priority app alert settings: package=${sbn.packageName}, selectedAppBypassEnabled=${settings.enabled}, selectedPackageCount=${settings.packages.size}, packageSelected=$packageSelected"
        )
        if (!settings.enabled) {
            Log.d(TAG, "Priority app alert skipped: setting disabled. package=${sbn.packageName}")
            return
        }
        if (settings.packages.isEmpty()) {
            Log.d(TAG, "Priority app alert skipped: no selected packages configured. package=${sbn.packageName}")
            return
        }
        if (!packageSelected) {
            Log.d(TAG, "Priority app alert skipped: package not selected. package=${sbn.packageName}")
            return
        }
        if (sbn.isOngoing) {
            Log.d(TAG, "Priority app alert skipped: notification is ongoing. package=${sbn.packageName}, id=${sbn.id}, key=${sbn.key}")
            return
        }
        if (isGroupSummary(sbn.notification)) {
            Log.d(TAG, "Priority app alert skipped: notification is group summary. package=${sbn.packageName}, id=${sbn.id}, key=${sbn.key}")
            return
        }

        Log.d(TAG, "Priority app package selected. package=${sbn.packageName}, selectedPackageCount=${settings.packages.size}")
        val sourceIdentity = prioritySourceIdentity(sbn)
        val suppressionReason = priorityAppSuppressionReason(
            sourceIdentity,
            sbn.packageName
        )
        if (suppressionReason != null) {
            Log.d(
                TAG,
                "Suppressed duplicate priority app alert: at=${System.currentTimeMillis()}, package=${sbn.packageName}, id=${sbn.id}, key=${sbn.key}, postTime=${sbn.postTime}, reason=$suppressionReason"
            )
            return
        }

        rememberPriorityAppAlert(sourceIdentity, sbn.packageName)
        postPriorityAppAlert(sbn)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        Log.d(
            TAG,
            "Notification removed: package=${sbn.packageName}, id=${sbn.id}, key=${sbn.key}"
        )
    }

    companion object {
        private const val TAG = "EmergencyBypass"
        private const val EMERGENCY_CHANNEL_ID = "quietly_emergency_alerts"
        private const val EMERGENCY_CHANNEL_NAME = "Quietly emergency alerts"
        private const val PRIORITY_APP_CHANNEL_ID = "quietly_priority_app_alerts_v2"
        private const val PRIORITY_APP_CHANNEL_NAME = "Quietly priority app alerts"
        private const val COOLDOWN_MS = 2 * 60 * 1000L
        private const val PRIORITY_PACKAGE_COOLDOWN_MS = 30 * 1000L
        private val recentNotificationKeyMatches = mutableMapOf<String, Long>()
        private val recentContentMatches = mutableMapOf<String, Long>()
        private val recentPriorityNotificationKeyAlerts = mutableMapOf<String, Long>()
        private val recentPriorityPackageAlerts = mutableMapOf<String, Long>()

        private fun isDuplicateSuppressed(notificationKey: String, contentIdentity: String): Boolean {
            val now = System.currentTimeMillis()
            pruneExpired(now)
            val lastKeyMatch = recentNotificationKeyMatches[notificationKey]
            val lastContentMatch = recentContentMatches[contentIdentity]

            return (lastKeyMatch != null && now - lastKeyMatch < COOLDOWN_MS) ||
                (lastContentMatch != null && now - lastContentMatch < COOLDOWN_MS)
        }

        private fun rememberMatch(notificationKey: String, contentIdentity: String) {
            val now = System.currentTimeMillis()
            pruneExpired(now)
            recentNotificationKeyMatches[notificationKey] = now
            recentContentMatches[contentIdentity] = now
        }

        private fun pruneExpired(now: Long) {
            recentNotificationKeyMatches.entries.removeAll { now - it.value >= COOLDOWN_MS }
            recentContentMatches.entries.removeAll { now - it.value >= COOLDOWN_MS }
        }

        private fun priorityAppSuppressionReason(
            sourceIdentity: String,
            packageName: String
        ): String? {
            val now = System.currentTimeMillis()
            prunePriorityAppExpired(now)
            val lastSourceAlert = recentPriorityNotificationKeyAlerts[sourceIdentity]
            if (lastSourceAlert != null && now - lastSourceAlert < COOLDOWN_MS) {
                return "same notification key/postTime cooldown (${now - lastSourceAlert}ms elapsed, ${COOLDOWN_MS}ms required)"
            }
            val lastPackageAlert = recentPriorityPackageAlerts[packageName]
            if (
                lastPackageAlert != null &&
                now - lastPackageAlert < PRIORITY_PACKAGE_COOLDOWN_MS
            ) {
                return "package cooldown (${now - lastPackageAlert}ms elapsed, ${PRIORITY_PACKAGE_COOLDOWN_MS}ms required)"
            }
            return null
        }

        private fun rememberPriorityAppAlert(sourceIdentity: String, packageName: String) {
            val now = System.currentTimeMillis()
            prunePriorityAppExpired(now)
            recentPriorityNotificationKeyAlerts[sourceIdentity] = now
            recentPriorityPackageAlerts[packageName] = now
        }

        private fun prunePriorityAppExpired(now: Long) {
            recentPriorityNotificationKeyAlerts.entries.removeAll {
                now - it.value >= COOLDOWN_MS
            }
            recentPriorityPackageAlerts.entries.removeAll {
                now - it.value >= PRIORITY_PACKAGE_COOLDOWN_MS
            }
        }
    }

    private fun postEmergencyAlert(sbn: StatusBarNotification) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createEmergencyAlertChannel(notificationManager)

        if (!canPostNotifications()) {
            Log.e(
                TAG,
                "Cannot post emergency alert because POST_NOTIFICATIONS permission is missing."
            )
            return
        }

        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, EMERGENCY_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_quietly_notification)
            .setContentTitle("Quietly Emergency Bypass")
            .setContentText("A monitored app notification matched your emergency keyword while DND was active.")
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText("A monitored app notification matched your emergency keyword while DND was active.")
            )
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setVibrate(longArrayOf(0, 400, 200, 400))
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        try {
            Log.d(
                TAG,
                "Posting Quietly emergency alert: at=${System.currentTimeMillis()}, package=${sbn.packageName}, notificationId=${emergencyNotificationId(sbn)}, DND filter before notify=${notificationManager.currentInterruptionFilter}"
            )
            notificationManager.notify(emergencyNotificationId(sbn), notification)
            Log.d(
                TAG,
                "Emergency alert notify call completed: at=${System.currentTimeMillis()}, package=${sbn.packageName}, id=${sbn.id}, key=${sbn.key}, DND filter after notify=${notificationManager.currentInterruptionFilter}"
            )
        } catch (e: SecurityException) {
            Log.e(TAG, "Failed to post emergency alert due to missing permission: ${e.message}")
        } catch (e: RuntimeException) {
            Log.e(TAG, "Failed to post emergency alert: ${e.message}")
        }
    }

    private fun createEmergencyAlertChannel(notificationManager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        try {
            val channel = NotificationChannel(
                EMERGENCY_CHANNEL_ID,
                EMERGENCY_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Emergency alerts for monitored keyword matches."
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 400, 200, 400)
                setSound(soundUri, audioAttributes)

                if (notificationManager.isNotificationPolicyAccessGranted) {
                    setBypassDnd(true)
                    Log.d(TAG, "Emergency alert channel DND bypass requested.")
                } else {
                    Log.d(TAG, "DND policy access missing; emergency channel bypass not requested.")
                }
            }

            notificationManager.createNotificationChannel(channel)
            val createdChannel = notificationManager.getNotificationChannel(EMERGENCY_CHANNEL_ID)
            Log.d(
                TAG,
                "Emergency alert channel created: id=$EMERGENCY_CHANNEL_ID, importance=${createdChannel?.importance ?: channel.importance}, canBypassDnd=${createdChannel?.canBypassDnd() ?: false}"
            )
        } catch (e: SecurityException) {
            Log.e(TAG, "Failed to create emergency alert channel: ${e.message}")
        } catch (e: RuntimeException) {
            Log.e(TAG, "Failed to create emergency alert channel: ${e.message}")
        }
    }

    private fun postPriorityAppAlert(sbn: StatusBarNotification) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createPriorityAppAlertChannel(notificationManager)

        val canPost = canPostNotifications()
        Log.d(
            TAG,
            "Priority app alert notification permission: package=${sbn.packageName}, postNotificationsGranted=$canPost"
        )
        if (!canPost) {
            Log.e(
                TAG,
                "Cannot post priority app alert because POST_NOTIFICATIONS permission is missing."
            )
            return
        }

        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val bodyText = priorityAppAlertBody(sbn.packageName)
        val notificationId = priorityAppNotificationId(sbn)
        val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        val notification = NotificationCompat.Builder(this, PRIORITY_APP_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_quietly_notification)
            .setContentTitle("Priority app alert")
            .setContentText(bodyText)
            .setStyle(NotificationCompat.BigTextStyle().bigText(bodyText))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setSound(soundUri)
            .setVibrate(longArrayOf(0, 350, 180, 350))
            .setOnlyAlertOnce(false)
            .setShowWhen(true)
            .setWhen(System.currentTimeMillis())
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        try {
            Log.d(
                TAG,
                "Posting Quietly priority app alert: at=${System.currentTimeMillis()}, package=${sbn.packageName}, sourceId=${sbn.id}, key=${sbn.key}, postTime=${sbn.postTime}, notificationId=$notificationId, channelId=$PRIORITY_APP_CHANNEL_ID, soundUri=$soundUri, DND filter before notify=${notificationManager.currentInterruptionFilter}"
            )
            notificationManager.notify(notificationId, notification)
            Log.d(
                TAG,
                "Priority app alert notify call completed: at=${System.currentTimeMillis()}, package=${sbn.packageName}, id=${sbn.id}, key=${sbn.key}, notificationId=$notificationId, DND filter after notify=${notificationManager.currentInterruptionFilter}"
            )
        } catch (e: SecurityException) {
            Log.e(TAG, "Failed to post priority app alert due to missing permission: ${e.message}")
        } catch (e: RuntimeException) {
            Log.e(TAG, "Failed to post priority app alert: ${e.message}")
        }
    }

    private fun createPriorityAppAlertChannel(notificationManager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        try {
            val existingChannel = notificationManager.getNotificationChannelCompat(
                PRIORITY_APP_CHANNEL_ID
            )
            Log.d(
                TAG,
                "Priority app alert channel before create: id=$PRIORITY_APP_CHANNEL_ID, exists=${existingChannel != null}, importance=${existingChannel?.importance ?: "none"}, canBypassDnd=${existingChannel?.canBypassDnd() ?: false}, existingSound=${existingChannel?.sound ?: "none"}, requestedSound=$soundUri, policyAccessGranted=${notificationManager.isNotificationPolicyAccessGranted}"
            )
            val channel = NotificationChannel(
                PRIORITY_APP_CHANNEL_ID,
                PRIORITY_APP_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Quietly alerts for selected app notifications during automation DND."
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 350, 180, 350)
                setSound(soundUri, audioAttributes)

                if (notificationManager.isNotificationPolicyAccessGranted) {
                    setBypassDnd(true)
                    Log.d(TAG, "Priority app alert channel DND bypass requested.")
                } else {
                    Log.d(TAG, "DND policy access missing; priority app channel bypass not requested.")
                }
            }

            notificationManager.createNotificationChannel(channel)
            val createdChannel = notificationManager.getNotificationChannel(
                PRIORITY_APP_CHANNEL_ID
            )
            Log.d(
                TAG,
                "Priority app alert channel created: id=$PRIORITY_APP_CHANNEL_ID, importance=${createdChannel?.importance ?: channel.importance}, canBypassDnd=${createdChannel?.canBypassDnd() ?: false}, sound=${createdChannel?.sound ?: soundUri}"
            )
        } catch (e: SecurityException) {
            Log.e(TAG, "Failed to create priority app alert channel: ${e.message}")
        } catch (e: RuntimeException) {
            Log.e(TAG, "Failed to create priority app alert channel: ${e.message}")
        }
    }

    private fun canPostNotifications(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
    }

    private fun emergencyNotificationId(sbn: StatusBarNotification): Int {
        return 7000 + (sbn.packageName.hashCode() and Int.MAX_VALUE) % 1000
    }

    private fun priorityAppNotificationId(sbn: StatusBarNotification): Int {
        val alertBucket = System.currentTimeMillis() / PRIORITY_PACKAGE_COOLDOWN_MS
        val identity = "${sbn.packageName}:$alertBucket"
        return 8000 + (identity.hashCode() and Int.MAX_VALUE) % 100000
    }

    private fun prioritySourceIdentity(sbn: StatusBarNotification): String {
        return "${sbn.key}:${sbn.postTime}"
    }

    private fun priorityAppAlertBody(packageName: String): String {
        val appLabel = appLabelForPackage(packageName)
        return if (appLabel.isNullOrBlank()) {
            "A selected app sent a notification during Quietly DND."
        } else {
            "$appLabel sent a notification during Quietly DND."
        }
    }

    private fun appLabelForPackage(packageName: String): String? {
        return try {
            val appInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getApplicationInfo(
                    packageName,
                    PackageManager.ApplicationInfoFlags.of(0L)
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getApplicationInfo(packageName, 0)
            }
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            null
        } catch (e: RuntimeException) {
            null
        }
    }

    private fun isGroupSummary(notification: Notification): Boolean {
        return notification.flags and Notification.FLAG_GROUP_SUMMARY != 0
    }

    private fun NotificationManager.getNotificationChannelCompat(
        channelId: String
    ): NotificationChannel? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getNotificationChannel(channelId)
        } else {
            null
        }
    }

    private fun extractNotificationText(notification: Notification): String {
        val extras = notification.extras ?: return ""
        val textParts = mutableListOf<String>()

        addCharSequenceExtra(textParts, extras, Notification.EXTRA_TITLE)
        addCharSequenceExtra(textParts, extras, Notification.EXTRA_TEXT)
        addCharSequenceExtra(textParts, extras, Notification.EXTRA_BIG_TEXT)
        addTextLines(textParts, extras)
        addMessagingStyleText(textParts, extras)

        return textParts.joinToString(" ")
    }

    private fun addCharSequenceExtra(
        textParts: MutableList<String>,
        extras: Bundle,
        key: String
    ) {
        extras.getCharSequence(key)?.toString()?.let {
            if (it.isNotBlank()) textParts.add(it)
        }
    }

    private fun addTextLines(textParts: MutableList<String>, extras: Bundle) {
        extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)?.forEach { line ->
            line?.toString()?.let {
                if (it.isNotBlank()) textParts.add(it)
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun addMessagingStyleText(textParts: MutableList<String>, extras: Bundle) {
        val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES) ?: return
        messages.forEach { message ->
            val messageBundle = message as? Bundle ?: return@forEach
            messageBundle.getCharSequence("text")?.toString()?.let {
                if (it.isNotBlank()) textParts.add(it)
            }
        }
    }

    private fun normalizeText(value: String): String {
        return value
            .lowercase(Locale.ROOT)
            .replace(Regex("\\s+"), " ")
            .trim()
    }

    private fun sha256(value: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(value.toByteArray())
        return digest.joinToString("") { "%02x".format(it) }
    }
}
