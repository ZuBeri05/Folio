package com.jiesheng.folio

import com.jiesheng.folio.domain.AppData
import com.jiesheng.folio.domain.ReviewLog
import com.jiesheng.folio.domain.Settings
import com.jiesheng.folio.domain.StudyItem
import com.jiesheng.folio.domain.Subject
import com.jiesheng.folio.domain.fsrs.Migration
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** 对应鸿蒙版 tests/migration.test.ts */
class MigrationTest {
    private val base = StudyItem(
        id = "a", subjectId = "math", title = "导数", createdAt = 1,
        scheduleMode = "curve", curveStage = 2, fixedIntervalDays = 3,
        currentIntervalDays = 4, nextReviewAt = 1000, lastReviewedAt = 500,
        reviewCount = 2, status = "active"
    )

    private val validItem = base.copy(
        scheduleMode = "fsrs", fsrsStability = 9.0, fsrsDifficulty = 7.0,
        fsrsState = "review", fsrsScheduledDays = 9.0, fsrsLapses = 2, fsrsVersion = 6
    )

    private val validLog = ReviewLog(
        id = "l", itemId = "a", reviewedAt = 1, rating = "got",
        previousIntervalDays = 1, nextIntervalDays = 9, nextReviewAt = 9,
        grade = 3, stabilityBefore = 1.0, stabilityAfter = 2.0,
        difficultyBefore = 5.0, difficultyAfter = 5.0,
        elapsedDays = 1, scheduledDays = 9
    )

    private val validSettings = Settings(targetRetention = 0.9)

    private fun makeValidData(
        schema: Int = 2,
        item: StudyItem = validItem,
        log: ReviewLog = validLog,
        settings: Settings = validSettings
    ): AppData = AppData(
        schemaVersion = schema,
        subjects = mutableListOf(Subject("math", "数学", "#E8A21A")),
        items = mutableListOf(item),
        logs = mutableListOf(log),
        settings = settings
    )

    @Test
    fun preservesDueDateAndEstimatesStability() {
        val result = Migration.migrateItem(base)
        assertEquals(1000L, result.nextReviewAt)
        assertEquals("fsrs", result.scheduleMode)
        assertEquals("review", result.fsrsState)
        assertTrue(result.fsrsStability >= 1)
        assertEquals(5.0, result.fsrsDifficulty, 0.0001)
    }

    @Test
    fun keepsFixedIntervalItems() {
        val fixed = base.copy(
            scheduleMode = "fixed", fixedIntervalDays = 7, reviewCount = 0,
            lastReviewedAt = 0, fsrsStability = 0.0, fsrsDifficulty = 5.0,
            fsrsState = "new", fsrsScheduledDays = 0.0, fsrsLapses = 0, fsrsVersion = 6
        )
        assertEquals("fixed", Migration.migrateItem(fixed).scheduleMode)
        assertEquals(7, Migration.migrateItem(fixed).fixedIntervalDays)
        val data = makeValidData()
        data.items[0] = fixed
        assertFalse(Migration.needsMigration(data))
    }

    @Test
    fun leavesUnreviewedItemsNew() {
        val result = Migration.migrateItem(base.copy(reviewCount = 0, lastReviewedAt = 0))
        assertEquals("new", result.fsrsState)
        assertEquals(0.0, result.fsrsStability, 0.0001)
    }

    @Test
    fun doesNotResetAnAlreadyValidFsrsItem() {
        val once = Migration.migrateItem(validItem)
        val twice = Migration.migrateItem(once)
        assertEquals(9.0, once.fsrsStability, 0.0001)
        assertEquals(9.0, twice.fsrsStability, 0.0001)
        assertEquals(7.0, twice.fsrsDifficulty, 0.0001)
        assertEquals(2, twice.fsrsLapses)
        assertEquals(9.0, twice.fsrsScheduledDays, 0.0001)
    }

    @Test
    fun normalizesLegacyScheduleModeOnValidFsrsItem() {
        val migrated = Migration.migrateItem(validItem.copy(scheduleMode = "curve"))
        assertEquals("fsrs", migrated.scheduleMode)
        assertEquals(9.0, migrated.fsrsStability, 0.0001)
        val data = makeValidData()
        data.items[0] = validItem.copy(scheduleMode = "curve")
        assertTrue(Migration.needsMigration(data))
    }

    @Test
    fun detectsLegacyItemsLogsAndSettings() {
        assertFalse(Migration.needsMigration(makeValidData()))

        val legacyItem = makeValidData()
        legacyItem.items[0] = base.copy(fsrsVersion = 6, fsrsState = "new", fsrsStability = 0.0)
        assertTrue(Migration.needsMigration(legacyItem))

        val legacyLog = makeValidData()
        legacyLog.logs[0] = validLog.copy(grade = 0)
        assertTrue(Migration.needsMigration(legacyLog))

        val legacySettings = makeValidData(settings = validSettings.copy(targetRetention = 0.5))
        assertTrue(Migration.needsMigration(legacySettings))

        val legacySchema = makeValidData(schema = 1)
        assertTrue(Migration.needsMigration(legacySchema))
    }

    @Test
    fun repairsRetentionOutsideSupportedRange() {
        val data = makeValidData(settings = validSettings.copy(targetRetention = 0.5))
        assertTrue(Migration.needsMigration(data))
        assertEquals(0.9, Migration.migrateAppData(data).settings.targetRetention, 0.0001)
    }

    @Test
    fun migratesLegacyLogMissingGrade() {
        val data = makeValidData()
        data.logs[0] = validLog.copy(grade = 0, rating = "fuzzy", previousIntervalDays = 2, nextIntervalDays = 4)
        val migrated = Migration.migrateAppData(data)
        assertEquals(2, migrated.logs[0].grade)
        assertEquals(0.0, migrated.logs[0].stabilityBefore, 0.0001)
        assertEquals(2, migrated.logs[0].elapsedDays)
        assertEquals(4, migrated.logs[0].scheduledDays)
    }
}
