package com.example.dnd_auto_app

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.DetectedActivity

const val DEFAULT_ACTIVITY_CONFIDENCE_THRESHOLD = 40
const val ACTIVITY_SNAPSHOT_MAX_AGE_MS = 5 * 60 * 1000L
const val ACTIVITY_UPDATE_INTERVAL_MS = 10_000L
const val ACTIVITY_REREGISTER_STALE_MS = 60 * 1000L
const val ACTIVITY_RECOGNITION_REQUEST_CODE = 1001
const val ACTION_ACTIVITY_RECOGNITION_UPDATE = "com.example.dnd_auto_app.ACTIVITY_RECOGNITION_UPDATE"
const val ACTION_ACTIVITY_RECOGNITION_DEBUG_REGISTER =
    "com.example.dnd_auto_app.ACTIVITY_RECOGNITION_DEBUG_REGISTER"
const val ACTION_ACTIVITY_RECOGNITION_DEBUG_REMOVE =
    "com.example.dnd_auto_app.ACTIVITY_RECOGNITION_DEBUG_REMOVE"
const val ACTION_ACTIVITY_RECOGNITION_DEBUG_SIMULATE =
    "com.example.dnd_auto_app.ACTIVITY_RECOGNITION_DEBUG_SIMULATE"
const val ACTIVITY_CONFIDENCE_PREF_PREFIX = "activityConfidence."
const val ACTIVITY_SNAPSHOT_UPDATED_AT_PREF = "currentActivitySnapshotUpdatedAt"

val KNOWN_DETECTED_ACTIVITY_TYPES = listOf(
    DetectedActivity.IN_VEHICLE,
    DetectedActivity.ON_BICYCLE,
    DetectedActivity.ON_FOOT,
    DetectedActivity.RUNNING,
    DetectedActivity.STILL,
    DetectedActivity.TILTING,
    DetectedActivity.WALKING,
    DetectedActivity.UNKNOWN
)

fun detectedActivityName(activityType: Int): String {
    return when (activityType) {
        DetectedActivity.IN_VEHICLE -> "IN_VEHICLE"
        DetectedActivity.ON_BICYCLE -> "ON_BICYCLE"
        DetectedActivity.ON_FOOT -> "ON_FOOT"
        DetectedActivity.RUNNING -> "RUNNING"
        DetectedActivity.STILL -> "STILL"
        DetectedActivity.TILTING -> "TILTING"
        DetectedActivity.WALKING -> "WALKING"
        DetectedActivity.UNKNOWN -> "UNKNOWN"
        else -> "UNKNOWN ($activityType)"
    }
}

fun activityConfidencePrefKey(activityType: Int): String {
    return "$ACTIVITY_CONFIDENCE_PREF_PREFIX$activityType"
}

fun activityRecognitionUpdateIntent(context: Context): Intent {
    return Intent(context, ActivityBroadcastReceiver::class.java).apply {
        action = ACTION_ACTIVITY_RECOGNITION_UPDATE
        setPackage(context.packageName)
    }
}

fun activityRecognitionPendingIntent(context: Context): PendingIntent {
    return PendingIntent.getBroadcast(
        context,
        ACTIVITY_RECOGNITION_REQUEST_CODE,
        activityRecognitionUpdateIntent(context),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
    )
}

fun legacyActivityRecognitionPendingIntent(context: Context): PendingIntent {
    return PendingIntent.getBroadcast(
        context,
        ACTIVITY_RECOGNITION_REQUEST_CODE,
        Intent(context, ActivityBroadcastReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
    )
}

fun detectedActivityTypeForRuleActivity(ruleActivityType: String?): Int? {
    return when (ruleActivityType?.trim()?.uppercase()) {
        "IN_VEHICLE", "IN VEHICLE", "DRIVING", "VEHICLE" -> DetectedActivity.IN_VEHICLE
        "ON_BICYCLE", "BICYCLE", "CYCLING" -> DetectedActivity.ON_BICYCLE
        "ON_FOOT" -> DetectedActivity.ON_FOOT
        "WALKING", "WALK", "ON_FOOT_OR_WALKING" -> DetectedActivity.WALKING
        "RUNNING", "RUN" -> DetectedActivity.RUNNING
        "STILL", "STATIONARY" -> DetectedActivity.STILL
        "TILTING" -> DetectedActivity.TILTING
        "UNKNOWN" -> DetectedActivity.UNKNOWN
        else -> null
    }
}

fun normalizeActivityConfidenceThreshold(threshold: Int?): Int {
    return threshold?.takeIf { it in 1..100 } ?: DEFAULT_ACTIVITY_CONFIDENCE_THRESHOLD
}

fun activitySnapshotIsFresh(
    snapshotAgeMs: Long?,
    maxAgeMs: Long = ACTIVITY_SNAPSHOT_MAX_AGE_MS
): Boolean {
    if (snapshotAgeMs == null) return false
    return snapshotAgeMs in 0..maxAgeMs
}

fun activityTriggerConfidence(
    ruleActivityType: String?,
    confidenceByType: Map<Int, Int>
): Int {
    val targetType = detectedActivityTypeForRuleActivity(ruleActivityType) ?: return 0
    val directConfidence = confidenceByType[targetType] ?: 0

    return when (targetType) {
        DetectedActivity.WALKING -> maxOf(
            directConfidence,
            confidenceByType[DetectedActivity.ON_FOOT] ?: 0
        )
        else -> directConfidence
    }
}

fun activityTriggerMatches(
    ruleActivityType: String?,
    confidenceByType: Map<Int, Int>,
    threshold: Int = DEFAULT_ACTIVITY_CONFIDENCE_THRESHOLD,
    snapshotAgeMs: Long? = 0L
): Boolean {
    return activitySnapshotIsFresh(snapshotAgeMs) &&
        activityTriggerConfidence(ruleActivityType, confidenceByType) >=
            normalizeActivityConfidenceThreshold(threshold)
}
