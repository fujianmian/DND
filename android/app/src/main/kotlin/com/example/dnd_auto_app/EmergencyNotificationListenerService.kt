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
            Log.d(TAG, "Keyword bypass skipped: automation DND inactive. package=${sbn.packageName}")
            return
        }
        if (sbn.packageName == packageName) {
            Log.d(TAG, "Keyword bypass skipped: ignoring Quietly notification.")
            return
        }

        val settings = KeywordBypassSettingsStore.read(this)
        if (!settings.enabled) {
            Log.d(TAG, "Keyword bypass skipped: setting disabled. package=${sbn.packageName}")
            return
        }
        if (settings.packages.isEmpty()) {
            Log.d(TAG, "Keyword bypass skipped: no monitored packages configured. package=${sbn.packageName}")
            return
        }
        if (!settings.packages.contains(sbn.packageName)) {
            Log.d(TAG, "Keyword bypass skipped: package not monitored. package=${sbn.packageName}")
            return
        }
        Log.d(TAG, "Keyword bypass package monitored. package=${sbn.packageName}, monitoredPackageCount=${settings.packages.size}")

        val extractedText = extractNotificationText(sbn.notification)
        if (extractedText.isBlank()) {
            Log.d(TAG, "Keyword bypass skipped: no readable notification text. package=${sbn.packageName}")
            return
        }

        val normalizedText = normalizeText(extractedText)
        val matchedKeyword = settings.keywords.firstOrNull { keyword ->
            normalizedText.contains(keyword.lowercase(Locale.ROOT))
        } ?: run {
            Log.d(TAG, "Keyword bypass skipped: no keyword matched. package=${sbn.packageName}, keywordCount=${settings.keywords.size}")
            return
        }

        val contentIdentity = "${sbn.packageName}:${sha256(normalizedText)}"
        if (isDuplicateSuppressed(sbn.key, contentIdentity)) {
            Log.d(
                TAG,
                "Suppressed duplicate emergency keyword match: at=${System.currentTimeMillis()}, package=${sbn.packageName}, id=${sbn.id}, key=${sbn.key}, keyword=$matchedKeyword, cooldownMs=$COOLDOWN_MS"
            )
            return
        }

        rememberMatch(sbn.key, contentIdentity)
        Log.d(
            TAG,
            "Emergency keyword match detected: at=${System.currentTimeMillis()}, package=${sbn.packageName}, id=${sbn.id}, key=${sbn.key}, keyword=$matchedKeyword"
        )
        postEmergencyAlert(sbn)
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
        private const val COOLDOWN_MS = 2 * 60 * 1000L
        private val recentNotificationKeyMatches = mutableMapOf<String, Long>()
        private val recentContentMatches = mutableMapOf<String, Long>()

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
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
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

    private fun canPostNotifications(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
    }

    private fun emergencyNotificationId(sbn: StatusBarNotification): Int {
        return 7000 + (sbn.packageName.hashCode() and Int.MAX_VALUE) % 1000
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
