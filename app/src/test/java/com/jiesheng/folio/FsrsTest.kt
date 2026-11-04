package com.jiesheng.folio

import com.jiesheng.folio.domain.fsrs.Fsrs
import com.jiesheng.folio.domain.fsrs.FsrsState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 与鸿蒙版 tests/fsrs.test.ts 一一对应的断言。
 * golden 序列 [2, 11, 46, 163, 497] 直接来自原版 fixture。
 */
class FsrsTest {
    @Test
    fun initialStabilityGrowsWithGrade() {
        val again = Fsrs.initialState(1, 1000)
        val hard = Fsrs.initialState(2, 1000)
        val good = Fsrs.initialState(3, 1000)
        val easy = Fsrs.initialState(4, 1000)
        assertTrue(again.stability > 0)
        assertTrue(hard.stability > again.stability)
        assertTrue(good.stability > hard.stability)
        assertTrue(easy.stability > good.stability)
        assertEquals(5.1122, hard.difficulty, 0.001)
        assertEquals(2.1181, good.difficulty, 0.001)
        assertEquals(1.0, easy.difficulty, 0.0001)
    }

    @Test
    fun previewKeepsRetentionOrdering() {
        val state = Fsrs.initialState(3, 1000)
        val p80 = Fsrs.preview(state, 0.0, 0.80, 1000)
        val p90 = Fsrs.preview(state, 0.0, 0.90, 1000)
        val p95 = Fsrs.preview(state, 0.0, 0.95, 1000)
        assertEquals(4, p90.size)
        assertTrue(p90.all { it.intervalDays >= 1 })
        assertTrue(p95[2].intervalDays <= p90[2].intervalDays)
        assertTrue(p80[2].intervalDays >= p90[2].intervalDays)
    }

    @Test
    fun againIncrementsLapsesAndEntersRelearning() {
        val state = Fsrs.initialState(3, 1000)
        val next = Fsrs.review(state, 1, 3.0, 0.90, 2000)
        assertEquals("relearning", next.state)
        assertEquals(1, next.lapses)
    }

    @Test
    fun newCardUsesFirstRatingBranch() {
        val fresh = FsrsState(0.0, 5.0, "new", 0, 0.0, 0)
        val first = Fsrs.review(fresh, 3, 0.0, 0.90, 1000)
        assertEquals("review", first.state)
        assertEquals(2.3065, first.stability, 0.001)
        assertTrue(first.scheduledDays >= 1)
    }

    @Test
    fun followsGoldenRepeatedGoodSequence() {
        var state = FsrsState(0.0, 5.0, "new", 0, 0.0, 1000)
        val intervals = mutableListOf<Int>()
        var elapsed = 0.0
        var now = 1000L
        for (i in 0 until 5) {
            state = Fsrs.review(state, 3, elapsed, 0.90, now)
            intervals.add(state.scheduledDays.toInt())
            elapsed = state.scheduledDays
            now += state.scheduledDays.toLong()
        }
        assertEquals(listOf(2, 11, 46, 163, 497), intervals)
    }

    @Test
    fun successfulReviewDoesNotDecreaseStability() {
        val state = Fsrs.initialState(3, 1000)
        val next = Fsrs.review(state, 3, 3.0, 0.90, 2000)
        assertTrue(next.stability >= state.stability)
        assertEquals("review", next.state)
    }

    @Test
    fun retrievabilityDecays() {
        val state = Fsrs.initialState(3, 1000)
        assertTrue(Fsrs.retrievability(state, 0.0) > Fsrs.retrievability(state, 10.0))
    }
}
