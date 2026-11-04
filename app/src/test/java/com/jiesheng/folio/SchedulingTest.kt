package com.jiesheng.folio

import com.jiesheng.folio.domain.StudyItem
import com.jiesheng.folio.domain.fsrs.fixedIntervalFor
import com.jiesheng.folio.domain.fsrs.fsrsStateFromItem
import com.jiesheng.folio.domain.fsrs.nextDueAt
import com.jiesheng.folio.domain.fsrs.postponeToTomorrow
import com.jiesheng.folio.domain.fsrs.previewForGrades
import com.jiesheng.folio.domain.fsrs.roundFsrsDays
import com.jiesheng.folio.domain.fsrs.scheduleFsrs
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

/** 对应鸿蒙版 tests/scheduling.test.ts */
class SchedulingTest {
    private fun ts(year: Int, month0: Int, day: Int, hour: Int = 0, minute: Int = 0): Long {
        val c = Calendar.getInstance()
        c.set(year, month0, day, hour, minute, 0)
        c.set(Calendar.MILLISECOND, 0)
        return c.timeInMillis
    }

    private val reviewedItem = StudyItem(
        id = "a",
        subjectId = "math",
        title = "导数",
        createdAt = 1,
        scheduleMode = "fsrs",
        curveStage = 2,
        fixedIntervalDays = 3,
        currentIntervalDays = 3,
        nextReviewAt = 1,
        lastReviewedAt = ts(2026, 9, 20),
        reviewCount = 2,
        status = "active",
        fsrsStability = 3.0,
        fsrsDifficulty = 5.0,
        fsrsState = "review",
        fsrsScheduledDays = 3.0,
        fsrsLapses = 1,
        fsrsVersion = 6
    )

    @Test
    fun neverSchedulesToday() {
        assertEquals(1, roundFsrsDays(0.2))
        assertEquals(1, roundFsrsDays(0.8))
        assertEquals(2, roundFsrsDays(2.4))
        assertEquals(3, roundFsrsDays(2.6))
        assertEquals(1, roundFsrsDays(Double.NaN))
        assertEquals(1, roundFsrsDays(Double.POSITIVE_INFINITY))
    }

    @Test
    fun dueDateLandsOnNextLocalMidnight() {
        val now = ts(2026, 9, 22, 22, 30)
        val due = nextDueAt(now, 2)
        val c = Calendar.getInstance().apply { timeInMillis = due }
        assertEquals(24, c.get(Calendar.DAY_OF_MONTH))
        assertEquals(0, c.get(Calendar.HOUR_OF_DAY))
    }

    @Test
    fun schedulesNextReviewAndUpdatesState() {
        val now = ts(2026, 9, 22, 22, 30)
        val result = scheduleFsrs(reviewedItem, 3, now, 0.9, null)
        assertTrue(result.nextIntervalDays >= 1)
        assertEquals(nextDueAt(now, result.nextIntervalDays), result.nextAt)
        assertTrue(result.stability > reviewedItem.fsrsStability)
        assertTrue(result.difficulty in 1.0..10.0)
        assertEquals(2, result.curveStage)
        assertEquals("3", result.rating)
    }

    @Test
    fun previewGivesFourPositiveIntervals() {
        val now = ts(2026, 9, 22, 22, 30)
        val intervals = previewForGrades(reviewedItem, now, 0.9, null)
        assertEquals(4, intervals.size)
        assertTrue(intervals.all { it >= 1 })
        assertTrue(intervals[3] >= intervals[0])
    }

    @Test
    fun overdueBonusSaturatesAtOneAndAHalfIntervals() {
        val now = ts(2026, 9, 22, 22, 30)
        val day = 86_400_000L
        val base = reviewedItem.copy(
            reviewCount = 3,
            fsrsStability = 10.0,
            fsrsDifficulty = 5.0,
            fsrsScheduledDays = 10.0
        )
        fun at(daysAgo: Int): Int = scheduleFsrs(
            base.copy(lastReviewedAt = now - daysAgo * day), 3, now, 0.9, null
        ).nextIntervalDays

        val onTime = at(10)
        val threeLate = at(13)
        val fifteenLate = at(25)
        val sixtyLate = at(70)

        assertTrue(threeLate > onTime)
        assertEquals(fifteenLate, sixtyLate)
        assertTrue(sixtyLate > onTime)
    }

    @Test
    fun capsIntervalAtConfiguredMaximum() {
        val now = ts(2026, 9, 22, 22, 30)
        val day = 86_400_000L
        val item = reviewedItem.copy(
            reviewCount = 4,
            fsrsStability = 200.0,
            fsrsDifficulty = 5.0,
            fsrsScheduledDays = 200.0,
            lastReviewedAt = now - 200 * day
        )
        val uncapped = scheduleFsrs(item, 3, now, 0.9, null).nextIntervalDays
        assertTrue(uncapped > 180)
        val capped = scheduleFsrs(item, 3, now, 0.9, 180).nextIntervalDays
        assertEquals(180, capped)
        assertTrue(capped < uncapped)
        for (value in previewForGrades(item, now, 0.9, 90)) {
            assertTrue(value <= 90)
        }
    }

    @Test
    fun zeroOrInvalidMaximumMeansUnlimited() {
        val now = ts(2026, 9, 22, 22, 30)
        val day = 86_400_000L
        val item = reviewedItem.copy(
            reviewCount = 4,
            fsrsStability = 200.0,
            fsrsScheduledDays = 200.0,
            lastReviewedAt = now - 200 * day
        )
        val uncapped = scheduleFsrs(item, 3, now, 0.9, null).nextIntervalDays
        assertEquals(uncapped, scheduleFsrs(item, 3, now, 0.9, 0).nextIntervalDays)
    }

    @Test
    fun preservesStoredStateForReviewedItemMarkedNew() {
        val now = ts(2026, 9, 22, 22, 30)
        val item = reviewedItem.copy(
            fsrsState = "new",
            fsrsStability = 9.0,
            fsrsDifficulty = 7.0,
            fsrsScheduledDays = 9.0,
            fsrsLapses = 2
        )
        val state = fsrsStateFromItem(item)
        assertEquals("review", state.state)
        assertEquals(9.0, state.stability, 0.0001)
        assertEquals(7.0, state.difficulty, 0.0001)
        assertEquals(2, state.lapses)
        assertEquals(9.0, state.scheduledDays, 0.0001)

        val result = scheduleFsrs(item, 3, now, 0.9, null)
        assertEquals("review", result.state)
        assertTrue(result.stability > 9.0)
        assertTrue(result.difficulty > 6.9)
        assertEquals(2, result.lapses)
    }

    @Test
    fun clampsMissingStoredValuesIntoTheValidRange() {
        val now = ts(2026, 9, 22, 22, 30)
        // Kotlin/JSON 里不会出现 NaN，所以「字段缺失」落地成 0：
        // 和原版 clamp(0, 0.1, 36500) / max(1, 0) 的结果一致。
        val item = reviewedItem.copy(
            fsrsState = "bogus",
            fsrsStability = 0.0,
            fsrsDifficulty = 0.0,
            fsrsScheduledDays = 0.0,
            fsrsLapses = 0
        )
        val state = fsrsStateFromItem(item)
        assertEquals("review", state.state)
        assertEquals(0.1, state.stability, 0.0001)
        assertEquals(1.0, state.difficulty, 0.0001)
        assertEquals(0, state.lapses)
        assertEquals(1.0, state.scheduledDays, 0.0001)

        val result = scheduleFsrs(item, 3, now, 0.9, null)
        assertTrue(result.stability.isFinite())
        assertTrue(result.difficulty.isFinite())
        assertTrue(result.nextIntervalDays >= 1)
    }

    @Test
    fun postponeOnlyMovesTheDueDate() {
        val now = ts(2026, 9, 22)
        val next = postponeToTomorrow(reviewedItem, now)
        assertEquals(reviewedItem.copy(nextReviewAt = nextDueAt(now, 1)), next)
        assertNotEquals(reviewedItem.nextReviewAt, next.nextReviewAt)
    }

    @Test
    fun fixedModePreviewsAndSchedules() {
        val now = ts(2026, 9, 22)
        val fixed = reviewedItem.copy(scheduleMode = "fixed", fixedIntervalDays = 10)
        assertEquals(listOf(1, 5, 10, 15), previewForGrades(fixed, now, 0.9, null))
        assertEquals(10, fixedIntervalFor(fixed, 3))
        val good = scheduleFsrs(fixed, 3, now, 0.9, null)
        assertEquals(10, good.nextIntervalDays)
        assertEquals(nextDueAt(now, 10), good.nextAt)
        assertEquals(reviewedItem.fsrsStability, good.stability, 0.0001)
        assertEquals(15, scheduleFsrs(fixed, 4, now, 0.9, null).nextIntervalDays)
        assertEquals(1, scheduleFsrs(fixed, 1, now, 0.9, null).nextIntervalDays)
    }
}
