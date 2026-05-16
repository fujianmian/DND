package com.example.dnd_auto_app

import com.google.android.gms.location.DetectedActivity
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ActivityRecognitionUtilsTest {
    @Test
    fun drivingAliasesMapToInVehicle() {
        assertEquals(
            DetectedActivity.IN_VEHICLE,
            detectedActivityTypeForRuleActivity("IN_VEHICLE")
        )
        assertEquals(
            DetectedActivity.IN_VEHICLE,
            detectedActivityTypeForRuleActivity("driving")
        )
        assertEquals(
            DetectedActivity.IN_VEHICLE,
            detectedActivityTypeForRuleActivity("vehicle")
        )
        assertEquals(
            DetectedActivity.IN_VEHICLE,
            detectedActivityTypeForRuleActivity("in_vehicle")
        )
    }

    @Test
    fun activityTriggerMatchesWhenConfidenceMeetsThreshold() {
        val confidences = mapOf(DetectedActivity.IN_VEHICLE to 45)

        assertTrue(activityTriggerMatches("IN_VEHICLE", confidences, threshold = 40))
        assertFalse(activityTriggerMatches("IN_VEHICLE", confidences, threshold = 50))
    }

    @Test
    fun drivingMatchesWhenStillIsMoreProbableButInVehicleMeetsThreshold() {
        val confidences = mapOf(
            DetectedActivity.STILL to 80,
            DetectedActivity.IN_VEHICLE to 45
        )

        assertTrue(activityTriggerMatches("IN_VEHICLE", confidences, threshold = 40))
    }

    @Test
    fun staleSnapshotDoesNotKeepDrivingActive() {
        val confidences = mapOf(DetectedActivity.IN_VEHICLE to 90)

        assertFalse(
            activityTriggerMatches(
                "IN_VEHICLE",
                confidences,
                threshold = 40,
                snapshotAgeMs = ACTIVITY_SNAPSHOT_MAX_AGE_MS + 1
            )
        )
    }

    @Test
    fun walkingRuleAcceptsOnFootConfidence() {
        val confidences = mapOf(
            DetectedActivity.WALKING to 10,
            DetectedActivity.ON_FOOT to 55
        )

        assertTrue(activityTriggerMatches("WALKING", confidences, threshold = 40))
    }

    @Test
    fun unknownRuleActivityDoesNotMatch() {
        val confidences = mapOf(DetectedActivity.IN_VEHICLE to 100)

        assertFalse(activityTriggerMatches("hovering", confidences, threshold = 40))
    }
}
