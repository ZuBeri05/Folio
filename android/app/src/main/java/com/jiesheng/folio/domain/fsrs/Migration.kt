package com.jiesheng.folio.domain.fsrs

import com.jiesheng.folio.domain.AppData
import com.jiesheng.folio.domain.ReviewLog
import com.jiesheng.folio.domain.Settings
import com.jiesheng.folio.domain.StudyItem

/**
 * 旧数据迁移，逐条对齐鸿蒙版 domain/fsrs/Migration.ts。
 * 只要 schemaVersion 不是 2、缺 FSRS 字段、日志缺 grade、保持率超出范围，就整体跑一遍。
 */
object Migration {
    private fun isValidTargetRetention(value: Double): Boolean =
        value.isFinite() && value >= 0.80 && value <= 0.95

    fun isValidFsrsItem(item: StudyItem): Boolean {
        if (item.fsrsVersion != 6) return false
        if (!item.fsrsStability.isFinite() || !item.fsrsDifficulty.isFinite()) return false
        if (!item.fsrsScheduledDays.isFinite()) return false
        if (item.reviewCount > 0 && (item.fsrsState == "new" || !(item.fsrsStability > 0))) return false
        return item.fsrsStability >= 0 && item.fsrsStability <= 36500 &&
            item.fsrsDifficulty >= 1 && item.fsrsDifficulty <= 10 &&
            item.fsrsScheduledDays >= 0 && item.fsrsLapses >= 0
    }

    fun isValidFixedItem(item: StudyItem): Boolean =
        item.fixedIntervalDays > 0 && item.nextReviewAt.toDouble().isFinite()

    private fun copyFixedItem(item: StudyItem): StudyItem = item.copy(
        scheduleMode = "fixed",
        fixedIntervalDays = maxOf(1, item.fixedIntervalDays),
        fsrsDifficulty = if (item.fsrsDifficulty.isFinite()) item.fsrsDifficulty else 5.0,
        fsrsState = if (item.fsrsState.isNotEmpty()) item.fsrsState else "new",
        fsrsVersion = 6
    )

    fun needsMigration(data: AppData): Boolean {
        if (data.schemaVersion != 2) return true
        for (item in data.items) {
            val ok = if (item.scheduleMode == "fixed") {
                isValidFixedItem(item)
            } else {
                isValidFsrsItem(item) && item.scheduleMode == "fsrs"
            }
            if (!ok) return true
        }
        for (log in data.logs) {
            if (!log.grade.toDouble().isFinite() || log.grade <= 0) return true
        }
        if (!isValidTargetRetention(data.settings.targetRetention)) return true
        return false
    }

    fun migrateItem(item: StudyItem): StudyItem {
        if (item.scheduleMode == "fixed") {
            return copyFixedItem(item)
        }
        if (isValidFsrsItem(item)) {
            if (item.scheduleMode == "fsrs") {
                return item
            }
            return item.copy(scheduleMode = "fsrs")
        }
        val reviewed = item.reviewCount > 0
        val currentInterval = item.currentIntervalDays
        val migratedInterval = if (reviewed) maxOf(1, currentInterval) else 0
        return item.copy(
            scheduleMode = "fsrs",
            fsrsStability = migratedInterval.toDouble(),
            fsrsDifficulty = 5.0,
            fsrsState = if (reviewed) "review" else "new",
            fsrsScheduledDays = migratedInterval.toDouble(),
            fsrsLapses = 0,
            fsrsVersion = 6
        )
    }

    private fun migratedGrade(rating: String): Int = when (rating) {
        "forgot" -> 1
        "fuzzy" -> 2
        else -> 3
    }

    private fun migrateLog(log: ReviewLog): ReviewLog {
        if (log.grade > 0) {
            return log
        }
        return log.copy(
            grade = migratedGrade(log.rating),
            stabilityBefore = 0.0,
            stabilityAfter = 0.0,
            difficultyBefore = 0.0,
            difficultyAfter = 0.0,
            elapsedDays = maxOf(0, log.previousIntervalDays),
            scheduledDays = maxOf(0, log.nextIntervalDays)
        )
    }

    private fun migrateSettings(settings: Settings): Settings = settings.copy(
        targetRetention = if (isValidTargetRetention(settings.targetRetention)) settings.targetRetention else 0.90,
        maxIntervalDays = settings.maxIntervalDays,
        focusMinutes = if (settings.focusMinutes > 0) settings.focusMinutes else 25
    )

    fun migrateAppData(data: AppData): AppData = data.copy(
        schemaVersion = 2,
        items = data.items.map { migrateItem(it) }.toMutableList(),
        logs = data.logs.map { migrateLog(it) }.toMutableList(),
        settings = migrateSettings(data.settings)
    )
}
