package com.jiesheng.folio

import com.jiesheng.folio.domain.FocusSession
import com.jiesheng.folio.domain.ReviewLog
import com.jiesheng.folio.domain.focus.breakMinutesFor
import com.jiesheng.folio.domain.focus.cycleSummary
import com.jiesheng.folio.domain.focus.durationParts
import com.jiesheng.folio.domain.focus.formatClock
import com.jiesheng.folio.domain.focus.remainingMs
import com.jiesheng.folio.domain.focus.summarize
import com.jiesheng.folio.domain.focus.todayCount
import com.jiesheng.folio.domain.focus.todayMinutes
import com.jiesheng.folio.domain.focus.weekBuckets
import com.jiesheng.folio.domain.startOfDayTs
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Calendar

/** 对应鸿蒙版 tests/focus.test.ts */
class FocusTest {
    private fun ts(year: Int, month0: Int, day: Int, hour: Int, minute: Int = 0): Long {
        val c = Calendar.getInstance()
        c.set(year, month0, day, hour, minute, 0)
        c.set(Calendar.MILLISECOND, 0)
        return c.timeInMillis
    }

    private fun log(reviewedAt: Long, grade: Int): ReviewLog = ReviewLog(
        id = "l", itemId = "a", reviewedAt = reviewedAt, rating = "got",
        previousIntervalDays = 1, nextIntervalDays = 2, nextReviewAt = 3,
        grade = grade, stabilityBefore = 0.0, stabilityAfter = 0.0,
        difficultyBefore = 0.0, difficultyAfter = 0.0,
        elapsedDays = 1, scheduledDays = 2
    )

    @Test
    fun clockCountsDownAndClampsAtZero() {
        assertEquals(1000L, remainingMs(1000, 0))
        assertEquals(600L, remainingMs(1000, 400))
        assertEquals(0L, remainingMs(1000, 1000))
        assertEquals(0L, remainingMs(1000, 5000))
    }

    @Test
    fun clockFormatsAsMinutesAndSeconds() {
        assertEquals("25:00", formatClock(25 * 60 * 1000L))
        assertEquals("24:35", formatClock(24 * 60 * 1000L + 35 * 1000))
        assertEquals("00:09", formatClock(9000))
        assertEquals("00:00", formatClock(0))
        // 还剩 400ms 时显示 00:01，不能提前显示 00:00
        assertEquals("00:01", formatClock(400))
    }

    @Test
    fun summaryCountsOnlyReviewsInsideWindow() {
        val start = ts(2026, 10, 2, 20)
        val end = start + 25 * 60 * 1000L
        val logs = listOf(
            log(start - 1000, 3),
            log(start, 3),
            log(start + 60000, 1),
            log(start + 120000, 4),
            log(end, 2),
            log(end + 1000, 4)
        )
        val summary = summarize(start, end, logs)
        assertEquals(4, summary.itemCount)
        assertEquals(2, summary.remembered)
        assertEquals(25, summary.minutes)
    }

    @Test
    fun summaryDropsSessionsUnderAMinuteAndRoundsUp() {
        val start = ts(2026, 10, 2, 20)
        assertEquals(0, summarize(start, start + 20000, emptyList()).minutes)
        assertEquals(2, summarize(start, start + 90000, emptyList()).minutes)
        assertEquals(1, summarize(start, start + 61000, emptyList()).minutes)
    }

    @Test
    fun aggregatesTodayAndTheWeek() {
        val now = ts(2026, 10, 4, 21)
        val today = startOfDayTs(now)
        val sessions = listOf(
            session(today + 10 * 3600000L, 25),
            session(today + 11 * 3600000L, 45),
            session(today - 86400000L, 25),
            session(today - 3 * 86400000L, 50)
        )
        assertEquals(70, todayMinutes(sessions, now))
        assertEquals(2, todayCount(sessions, now))

        val buckets = weekBuckets(sessions, now)
        assertEquals(7, buckets.size)
        assertEquals(0, buckets[0])
        assertEquals(25, buckets[1])
        assertEquals(70, buckets[2])
        assertEquals(0, buckets[6])
    }

    @Test
    fun splitsMinutesIntoHours() {
        assertArrayEquals(intArrayOf(0, 0), durationParts(0))
        assertArrayEquals(intArrayOf(0, 25), durationParts(25))
        assertArrayEquals(intArrayOf(1, 15), durationParts(75))
        assertArrayEquals(intArrayOf(0, 0), durationParts(-5))
    }

    @Test
    fun longBreakComesEveryFourthRound() {
        assertEquals(5, breakMinutesFor(1))
        assertEquals(5, breakMinutesFor(2))
        assertEquals(5, breakMinutesFor(3))
        assertEquals(15, breakMinutesFor(4))
        assertEquals(5, breakMinutesFor(5))
        assertEquals(15, breakMinutesFor(8))
        assertEquals(5, breakMinutesFor(0))
    }

    @Test
    fun cycleSummaryOnlyAddsSessionsAfterTheCycleStart() {
        val now = ts(2026, 10, 4, 21)
        val sessions = listOf(
            session(now - 7200000, 30, 4, 3),
            session(now - 3600000, 30, 6, 5),
            session(now - 600000, 5, 2, 1)
        )
        val cycle = cycleSummary(sessions, now - 3600000)
        assertEquals(2, cycle.segments)
        assertEquals(35, cycle.minutes)
        assertEquals(8, cycle.itemCount)
        assertEquals(6, cycle.remembered)
    }

    @Test
    fun emptyCycleIsAllZero() {
        val cycle = cycleSummary(emptyList(), 0)
        assertEquals(0, cycle.segments)
        assertEquals(0, cycle.minutes)
        assertEquals(0, cycle.itemCount)
    }

    private fun session(startedAt: Long, minutes: Int, items: Int = 0, remembered: Int = 0): FocusSession =
        FocusSession(
            id = "s", startedAt = startedAt, endedAt = startedAt + minutes * 60000L,
            plannedMinutes = minutes, minutes = minutes, itemCount = items,
            remembered = remembered, completed = true
        )
}
