package com.jiesheng.folio.domain.fsrs

import com.jiesheng.folio.domain.DAY_MS
import com.jiesheng.folio.domain.StudyItem
import com.jiesheng.folio.domain.startOfDayTs

/** 逾期超过「计划间隔 × 这个系数」后，多出来的部分不再计入 FSRS */
private const val OVERDUE_SLACK = 1.5

data class FsrsScheduleResult(
    val nextAt: Long,
    val nextIntervalDays: Int,
    val curveStage: Int,
    val rating: String,
    val stability: Double,
    val difficulty: Double,
    val state: String,
    val lapses: Int,
    val scheduledDays: Int
)

fun roundFsrsDays(raw: Double): Int {
    if (!raw.isFinite()) {
        return 1
    }
    return maxOf(1, Math.round(raw).toInt())
}

fun nextDueAt(now: Long, days: Int): Long {
    val c = java.util.Calendar.getInstance()
    c.timeInMillis = now
    c.set(java.util.Calendar.HOUR_OF_DAY, 0)
    c.set(java.util.Calendar.MINUTE, 0)
    c.set(java.util.Calendar.SECOND, 0)
    c.set(java.util.Calendar.MILLISECOND, 0)
    c.add(java.util.Calendar.DAY_OF_MONTH, maxOf(1, days))
    return c.timeInMillis
}

private fun safeRetention(value: Double): Double {
    if (!value.isFinite()) {
        return 0.90
    }
    return minOf(0.95, maxOf(0.80, value))
}

private fun safeGrade(value: Int): Int = Math.round(minOf(4.0, maxOf(1.0, value.toDouble()))).toInt()

private fun clamp(value: Double, low: Double, high: Double): Double = minOf(high, maxOf(low, value))

private fun safeState(value: String): String =
    if (value == "learning" || value == "review" || value == "relearning") value else "review"

private fun safeDays(value: Double): Int {
    if (!value.isFinite()) {
        return 1
    }
    return roundFsrsDays(value)
}

private fun elapsedDays(item: StudyItem, now: Long): Double {
    if (!item.lastReviewedAt.toDouble().isFinite() || item.lastReviewedAt <= 0L) {
        return 0.0
    }
    val raw = maxOf(0, Math.round((startOfDayTs(now) - startOfDayTs(item.lastReviewedAt)).toDouble() / DAY_MS).toInt())
    // 逾期奖励封顶：交给 FSRS 的「晚了多久」最多按计划间隔的 1.5 倍算
    val planned = if (item.fsrsScheduledDays > 0) {
        item.fsrsScheduledDays
    } else {
        item.currentIntervalDays.toDouble()
    }
    if (planned <= 0.0) {
        return raw.toDouble()
    }
    return minOf(raw.toDouble(), Math.round(planned * OVERDUE_SLACK).toDouble())
}

fun fsrsStateFromItem(item: StudyItem): FsrsState {
    val reviewCount = item.reviewCount
    val storedState = item.lastReviewedAt
    if (reviewCount <= 0) {
        return FsrsState(
            stability = 0.0,
            difficulty = 5.0,
            state = "new",
            lapses = 0,
            scheduledDays = 0.0,
            lastReviewedAt = storedState
        )
    }
    val fallbackInterval = item.currentIntervalDays.toDouble()
    val stability = if (item.fsrsStability.isFinite()) {
        clamp(item.fsrsStability, 0.1, 36500.0)
    } else {
        clamp(roundFsrsDays(fallbackInterval).toDouble(), 0.1, 36500.0)
    }
    val difficulty = if (item.fsrsDifficulty.isFinite()) clamp(item.fsrsDifficulty, 1.0, 10.0) else 5.0
    val scheduledDays = if (item.fsrsScheduledDays.isFinite()) {
        maxOf(1.0, item.fsrsScheduledDays)
    } else {
        maxOf(1.0, stability)
    }
    val lapses = maxOf(0, item.fsrsLapses)
    return FsrsState(
        stability = stability,
        difficulty = difficulty,
        state = safeState(item.fsrsState),
        lapses = lapses,
        scheduledDays = scheduledDays,
        lastReviewedAt = storedState
    )
}

fun fixedIntervalFor(item: StudyItem, grade: Int): Int {
    val base = maxOf(1, minOf(90, Math.round(item.fixedIntervalDays.toDouble()).toInt()))
    if (grade == 1) {
        return 1
    }
    if (grade == 2) {
        return maxOf(1, Math.round(base / 2.0).toInt())
    }
    if (grade == 4) {
        return maxOf(base + 1, Math.round(base * 1.5).toInt())
    }
    return base
}

/** 最长间隔：0 或非有限值表示不限 */
private fun capInterval(days: Int, maxIntervalDays: Int?): Int {
    if (maxIntervalDays == null || maxIntervalDays <= 0) {
        return days
    }
    return minOf(days, maxOf(1, maxIntervalDays))
}

fun scheduleFsrs(
    item: StudyItem,
    grade: Int,
    now: Long,
    retention: Double,
    maxIntervalDays: Int? = null
): FsrsScheduleResult {
    val safe = safeGrade(grade)
    if (item.scheduleMode == "fixed") {
        val days = capInterval(fixedIntervalFor(item, safe), maxIntervalDays)
        return FsrsScheduleResult(
            nextAt = nextDueAt(now, days),
            nextIntervalDays = days,
            curveStage = item.curveStage,
            rating = safe.toString(),
            stability = item.fsrsStability,
            difficulty = item.fsrsDifficulty,
            state = if (item.reviewCount > 0) "review" else "new",
            lapses = item.fsrsLapses,
            scheduledDays = days
        )
    }
    val state = fsrsStateFromItem(item)
    val reviewed = Fsrs.review(state, safe, elapsedDays(item, now), safeRetention(retention), now)
    val days = capInterval(safeDays(reviewed.scheduledDays), maxIntervalDays)
    return FsrsScheduleResult(
        nextAt = nextDueAt(now, days),
        nextIntervalDays = days,
        curveStage = item.curveStage,
        rating = safe.toString(),
        stability = reviewed.stability,
        difficulty = reviewed.difficulty,
        state = reviewed.state,
        lapses = reviewed.lapses,
        scheduledDays = days
    )
}

fun previewForGrades(
    item: StudyItem,
    now: Long,
    retention: Double,
    maxIntervalDays: Int? = null
): List<Int> {
    if (item.scheduleMode == "fixed") {
        val result = mutableListOf<Int>()
        for (grade in 1..4) {
            result.add(capInterval(fixedIntervalFor(item, grade), maxIntervalDays))
        }
        return result
    }
    val state = fsrsStateFromItem(item)
    val previews = Fsrs.preview(state, elapsedDays(item, now), safeRetention(retention), now)
    val intervals = mutableListOf<Int>()
    for (p in previews) {
        intervals.add(capInterval(safeDays(p.intervalDays.toDouble()), maxIntervalDays))
    }
    return intervals
}

fun postponeToTomorrow(item: StudyItem, now: Long): StudyItem =
    item.copy(nextReviewAt = nextDueAt(now, 1))
