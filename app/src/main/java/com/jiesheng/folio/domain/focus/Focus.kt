package com.jiesheng.folio.domain.focus

import com.jiesheng.folio.domain.DAY_MS
import com.jiesheng.folio.domain.ReviewLog
import com.jiesheng.folio.domain.FocusSession
import com.jiesheng.folio.domain.startOfDayTs
import java.util.Calendar

/**
 * 专注计时的纯逻辑，逐行对齐鸿蒙版 domain/focus/Focus.ts。
 */

/** 距离结束还剩多少毫秒，过点返回 0 */
fun remainingMs(endAt: Long, now: Long): Long {
    val left = endAt - now
    return if (left > 0) left else 0L
}

/** 24:35 这种显示 */
fun formatClock(ms: Long): String {
    val totalSeconds = maxOf(0L, Math.ceil(ms / 1000.0).toLong())
    val minutes = totalSeconds / 60
    val seconds = totalSeconds % 60
    val mm = if (minutes < 10) "0$minutes" else "$minutes"
    val ss = if (seconds < 10) "0$seconds" else "$seconds"
    return "$mm:$ss"
}

data class FocusSummary(
    /** 实际分钟数；不足 1 分钟记 0，调用方据此决定要不要落库 */
    val minutes: Int,
    val itemCount: Int,
    val remembered: Int
)

/** 结算一段专注：这段时间里复习了几条、其中几条记得 */
fun summarize(startedAt: Long, endedAt: Long, logs: List<ReviewLog>): FocusSummary {
    var itemCount = 0
    var remembered = 0
    for (log in logs) {
        val at = log.reviewedAt
        if (at >= startedAt && at <= endedAt) {
            itemCount += 1
            if (log.grade >= 3) {
                remembered += 1
            }
        }
    }
    val rawMinutes = (endedAt - startedAt) / 60000.0
    val minutes = if (rawMinutes < 1) 0 else maxOf(1, Math.round(rawMinutes).toInt())
    return FocusSummary(minutes, itemCount, remembered)
}

fun todayMinutes(sessions: List<FocusSession>, now: Long): Int {
    val from = startOfDayTs(now)
    val to = from + DAY_MS
    var total = 0
    for (s in sessions) {
        if (s.startedAt >= from && s.startedAt < to) {
            total += s.minutes
        }
    }
    return total
}

fun todayCount(sessions: List<FocusSession>, now: Long): Int {
    val from = startOfDayTs(now)
    val to = from + DAY_MS
    var count = 0
    for (s in sessions) {
        if (s.startedAt >= from && s.startedAt < to) {
            count += 1
        }
    }
    return count
}

/** 本周（周一开头）每天多少分钟，返回 7 个桶 */
fun weekBuckets(sessions: List<FocusSession>, now: Long): IntArray {
    val buckets = IntArray(7)
    val today = startOfDayTs(now)
    val cal = Calendar.getInstance()
    cal.timeInMillis = now
    val weekday = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7
    val monday = today - weekday * DAY_MS
    for (s in sessions) {
        val day = startOfDayTs(s.startedAt)
        val index = Math.round((day - monday).toDouble() / DAY_MS).toInt()
        if (index in 0..6) {
            buckets[index] += s.minutes
        }
    }
    return buckets
}

/** 分钟拆成 [小时, 分钟]，给「1 小时 15 分」这种文案用 */
fun durationParts(minutes: Int): IntArray {
    val safe = if (minutes > 0) minutes else 0
    return intArrayOf(safe / 60, safe % 60)
}

/** 第几轮之后休息多久：每 4 轮一次长休息 */
fun breakMinutesFor(round: Int): Int {
    val safe = if (round > 0) round else 1
    return if (safe % 4 == 0) 15 else 5
}

data class CycleSummary(
    val segments: Int,
    val minutes: Int,
    val itemCount: Int,
    val remembered: Int
)

/** 从 since 开始，累计这一段循环的专注 */
fun cycleSummary(sessions: List<FocusSession>, since: Long): CycleSummary {
    var segments = 0
    var minutes = 0
    var itemCount = 0
    var remembered = 0
    for (s in sessions) {
        if (s.startedAt < since) {
            continue
        }
        segments += 1
        minutes += s.minutes
        itemCount += s.itemCount
        remembered += s.remembered
    }
    return CycleSummary(segments, minutes, itemCount, remembered)
}
