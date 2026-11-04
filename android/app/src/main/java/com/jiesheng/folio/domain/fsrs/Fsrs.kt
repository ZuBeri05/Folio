package com.jiesheng.folio.domain.fsrs

import kotlin.math.exp
import kotlin.math.pow

/**
 * FSRS-6，逐行对齐鸿蒙版 domain/fsrs/Fsrs.ts。
 * 权重、公式、取整顺序都不能改，否则同一个条目排出来的日期会和原版不一样。
 */
object Fsrs {
    val W: DoubleArray = doubleArrayOf(
        0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334,
        3.0194, 0.001, 1.8722, 0.1666, 0.796, 1.4835,
        0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425,
        0.0912, 0.0658, 0.1542
    )

    private val DECAY: Double = -W[20]
    private val FACTOR: Double = 0.9.pow(1 / DECAY) - 1

    fun decay(): Double = DECAY

    fun retrievability(state: FsrsState, elapsedDays: Double): Double {
        val elapsed = maxOf(0.0, elapsedDays)
        return (1 + FACTOR * elapsed / maxOf(0.1, state.stability)).pow(DECAY)
    }

    fun initialState(grade: Int, now: Long): FsrsState {
        val g = clampGrade(grade)
        return FsrsState(
            stability = W[g - 1],
            difficulty = clamp(W[4] - exp(W[5] * (g - 1)) + 1, 1.0, 10.0),
            state = if (g == 1) "learning" else "review",
            lapses = 0,
            scheduledDays = 0.0,
            lastReviewedAt = now
        )
    }

    private fun nextDifficulty(difficulty: Double, grade: Int): Double {
        val initialEasy = clamp(W[4] - exp(W[5] * 3) + 1, 1.0, 10.0)
        val next = W[7] * initialEasy + (1 - W[7]) * (difficulty - W[6] * (grade - 3))
        return clamp(next, 1.0, 10.0)
    }

    private fun nextStability(state: FsrsState, grade: Int, elapsedDays: Double): Double {
        val r = retrievability(state, elapsedDays)
        val d = state.difficulty
        val s = state.stability
        if (grade == 1) {
            return W[11] * d.pow(-W[12]) * ((s + 1).pow(W[13]) - 1) * exp(W[14] * (1 - r))
        }
        val hardFactor = if (grade == 2) W[15] else 1.0
        val easyFactor = if (grade == 4) W[16] else 1.0
        val growth = exp(W[8]) * (11 - d) * s.pow(-W[9]) *
            (exp(W[10] * (1 - r)) - 1) * hardFactor * easyFactor + 1
        return s * growth
    }

    private fun intervalFor(stability: Double, retention: Double): Int {
        val raw = stability / FACTOR * (retention.pow(1 / DECAY) - 1)
        return maxOf(1, Math.round(raw).toInt())
    }

    fun review(
        state: FsrsState,
        grade: Int,
        elapsedDays: Double,
        retention: Double,
        now: Long
    ): FsrsState {
        val g = clampGrade(grade)
        val safeRetention = clamp(retention, 0.80, 0.95)
        val base = if (state.state == "new") initialState(g, now) else clampState(state)
        if (state.state == "new") {
            val interval = intervalFor(base.stability, safeRetention)
            return FsrsState(
                stability = base.stability,
                difficulty = base.difficulty,
                state = base.state,
                lapses = base.lapses,
                scheduledDays = interval.toDouble(),
                lastReviewedAt = now
            )
        }
        val stability = clamp(nextStability(base, g, elapsedDays), 0.1, 36500.0)
        val difficulty = nextDifficulty(base.difficulty, g)
        val interval = intervalFor(stability, safeRetention)
        return FsrsState(
            stability = stability,
            difficulty = difficulty,
            state = if (g == 1) "relearning" else "review",
            lapses = base.lapses + if (g == 1) 1 else 0,
            scheduledDays = interval.toDouble(),
            lastReviewedAt = now
        )
    }

    fun preview(
        state: FsrsState,
        elapsedDays: Double,
        retention: Double,
        now: Long
    ): List<FsrsPreview> {
        val result = mutableListOf<FsrsPreview>()
        for (grade in 1..4) {
            result.add(FsrsPreview(grade, review(state, grade, elapsedDays, retention, now).scheduledDays.toInt()))
        }
        return result
    }

    fun clamp(value: Double, low: Double, high: Double): Double =
        minOf(high, maxOf(low, value))

    fun clampGrade(grade: Int): Int = Math.round(clamp(grade.toDouble(), 1.0, 4.0)).toInt()

    fun clampState(state: FsrsState): FsrsState = FsrsState(
        stability = clamp(state.stability, 0.1, 36500.0),
        difficulty = clamp(state.difficulty, 1.0, 10.0),
        state = if (state.state in VALID_STATES) state.state else "review",
        lapses = maxOf(0, Math.round(state.lapses.toDouble()).toInt()),
        scheduledDays = maxOf(0.0, Math.round(state.scheduledDays).toDouble()),
        lastReviewedAt = state.lastReviewedAt
    )

    private val VALID_STATES = listOf("new", "learning", "review", "relearning")
}

data class FsrsState(
    val stability: Double,
    val difficulty: Double,
    val state: String,
    val lapses: Int,
    val scheduledDays: Double,
    val lastReviewedAt: Long
)

data class FsrsPreview(
    val grade: Int,
    val intervalDays: Int
)
