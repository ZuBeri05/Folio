package com.jiesheng.folio.domain

import kotlin.random.Random

data class Subject(
    val id: String,
    val name: String,
    val color: String
)

val SUBJECT_COLORS: List<String> = listOf(
    "#E8A21A",
    "#4A90D9",
    "#D95F3F",
    "#8E7CC3",
    "#5AA469",
    "#E07A5F",
    "#7A8B99",
    "#3FA7A3",
    "#C77DBB",
    "#6C7BD9",
    "#D4A72C",
    "#7FA650",
    "#C46A8A",
    "#5B8CBF",
    "#9A7B4F",
    "#8C9A5B"
)

data class StudyItem(
    val id: String = "",
    val subjectId: String = "",
    val title: String = "",
    val createdAt: Long = 0L,
    val scheduleMode: String = "curve",
    val curveStage: Int = 0,
    val fixedIntervalDays: Int = 3,
    val currentIntervalDays: Int = 1,
    val nextReviewAt: Long = 0L,
    val lastReviewedAt: Long = 0L,
    val reviewCount: Int = 0,
    val status: String = "active",
    val fsrsStability: Double = 0.0,
    val fsrsDifficulty: Double = 5.0,
    val fsrsState: String = "new",
    val fsrsScheduledDays: Double = 0.0,
    val fsrsLapses: Int = 0,
    val fsrsVersion: Int = 6
)

data class ReviewLog(
    val id: String,
    val itemId: String,
    val reviewedAt: Long,
    val rating: String,
    val previousIntervalDays: Int,
    val nextIntervalDays: Int,
    val nextReviewAt: Long,
    val grade: Int,
    val stabilityBefore: Double,
    val stabilityAfter: Double,
    val difficultyBefore: Double,
    val difficultyAfter: Double,
    val elapsedDays: Int,
    val scheduledDays: Int
)

data class SubjectTime(
    val subjectId: String,
    val time: String
)

/** 一段专注（番茄钟） */
data class FocusSession(
    val id: String,
    val startedAt: Long,
    val endedAt: Long,
    val plannedMinutes: Int,
    val minutes: Int,
    val itemCount: Int,
    val remembered: Int,
    val completed: Boolean,
    /** 只有 activeFocus 会填：这一段是不是休息 */
    val isBreak: Boolean? = null,
    /** 只有 activeFocus 会填：循环里的第几轮 */
    val round: Int? = null,
    /** 只有 activeFocus 会填：这一轮循环的起点 */
    val cycleStart: Long? = null
)

data class Settings(
    val reminderEnabled: Boolean = true,
    val reminderTime: String = "20:00",
    val subjectTimes: List<SubjectTime> = emptyList(),
    val themeIndex: Int = 0,
    val language: String = "zh",
    val targetRetention: Double = 0.9,
    /** 最长间隔（天），0 表示不限 */
    val maxIntervalDays: Int = 180,
    /** 上次选的专注时长（分钟） */
    val focusMinutes: Int = 25
)

data class AppData(
    val schemaVersion: Int = 2,
    val subjects: MutableList<Subject> = mutableListOf(),
    val items: MutableList<StudyItem> = mutableListOf(),
    val logs: MutableList<ReviewLog> = mutableListOf(),
    val settings: Settings = Settings(),
    val focusSessions: MutableList<FocusSession> = mutableListOf(),
    /** 正在跑的专注，App 被关掉后靠它恢复 */
    val activeFocus: FocusSession? = null
)

/** Subject 也是不可变数据，颜色修正靠 copy */
fun Subject.withColor(color: String): Subject = copy(color = color)

data class ReviewResult(
    val nextAt: Long,
    val nextIntervalDays: Int,
    val curveStage: Int,
    val rating: String
)

data class DayCount(
    val date: Long,
    val count: Int
)

private const val ID_ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyz"

private fun randomSuffix(length: Int): String {
    val builder = StringBuilder(length)
    for (i in 0 until length) {
        builder.append(ID_ALPHABET[Random.nextInt(ID_ALPHABET.length)])
    }
    return builder.toString()
}

/** 和鸿蒙版一致：时间戳的 36 进制 + 6 位随机后缀 */
fun newId(): String = System.currentTimeMillis().toString(36) + randomSuffix(6)

fun emptyItem(): StudyItem = StudyItem()

fun createDefaultData(): AppData {
    val subjects = mutableListOf(
        Subject(id = "math", name = "数学", color = "#E8A21A"),
        Subject(id = "english", name = "英语", color = "#4A90D9"),
        Subject(id = "politics", name = "政治", color = "#D95F3F"),
        Subject(id = "major", name = "专业课", color = "#8E7CC3")
    )
    return AppData(
        schemaVersion = 2,
        subjects = subjects,
        items = mutableListOf(),
        logs = mutableListOf(),
        settings = Settings(),
        focusSessions = mutableListOf(),
        activeFocus = null
    )
}
