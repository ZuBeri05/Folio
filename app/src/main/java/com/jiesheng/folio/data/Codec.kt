package com.jiesheng.folio.data

import com.jiesheng.folio.domain.AppData
import com.jiesheng.folio.domain.FocusSession
import com.jiesheng.folio.domain.ReviewLog
import com.jiesheng.folio.domain.Settings
import com.jiesheng.folio.domain.StudyItem
import com.jiesheng.folio.domain.Subject
import com.jiesheng.folio.domain.SubjectTime
import org.json.JSONArray
import org.json.JSONObject

/**
 * AppData ⇄ JSON。
 *
 * 字段名、默认值和鸿蒙版（preferences 里的 app_data_v1）逐字对应，
 * 所以把鸿蒙版导出的这份 JSON 直接搬过来也能读。
 */
object Codec {
    private fun optLong(obj: JSONObject, key: String, fallback: Long): Long =
        if (obj.has(key) && !obj.isNull(key)) obj.optLong(key, fallback) else fallback

    private fun optDouble(obj: JSONObject, key: String, fallback: Double): Double =
        if (obj.has(key) && !obj.isNull(key)) obj.optDouble(key, fallback) else fallback

    private fun optInt(obj: JSONObject, key: String, fallback: Int): Int =
        if (obj.has(key) && !obj.isNull(key)) obj.optInt(key, fallback) else fallback

    private fun optString(obj: JSONObject, key: String, fallback: String): String =
        if (obj.has(key) && !obj.isNull(key)) obj.optString(key, fallback) else fallback

    fun decode(raw: String): AppData? {
        return try {
            val root = JSONObject(raw)
            if (!root.has("subjects") || !root.has("items") || !root.has("logs") || !root.has("settings")) {
                return null
            }
            AppData(
                schemaVersion = optInt(root, "schemaVersion", 2),
                subjects = decodeSubjects(root.optJSONArray("subjects")),
                items = decodeItems(root.optJSONArray("items")),
                logs = decodeLogs(root.optJSONArray("logs")),
                settings = decodeSettings(root.optJSONObject("settings")),
                focusSessions = decodeSessions(root.optJSONArray("focusSessions")),
                activeFocus = root.optJSONObject("activeFocus")?.let { decodeSession(it) }
            )
        } catch (error: Exception) {
            null
        }
    }

    fun encode(data: AppData): String {
        val root = JSONObject()
        root.put("schemaVersion", data.schemaVersion)
        root.put("subjects", JSONArray().apply { data.subjects.forEach { put(encodeSubject(it)) } })
        root.put("items", JSONArray().apply { data.items.forEach { put(encodeItem(it)) } })
        root.put("logs", JSONArray().apply { data.logs.forEach { put(encodeLog(it)) } })
        root.put("settings", encodeSettings(data.settings))
        root.put("focusSessions", JSONArray().apply { data.focusSessions.forEach { put(encodeSession(it)) } })
        if (data.activeFocus == null) {
            root.put("activeFocus", JSONObject.NULL)
        } else {
            root.put("activeFocus", encodeSession(data.activeFocus!!))
        }
        return root.toString()
    }

    private fun decodeSubjects(array: JSONArray?): MutableList<Subject> {
        val result = mutableListOf<Subject>()
        if (array == null) return result
        for (i in 0 until array.length()) {
            val obj = array.optJSONObject(i) ?: continue
            result.add(
                Subject(
                    id = optString(obj, "id", ""),
                    name = optString(obj, "name", ""),
                    color = optString(obj, "color", "#8D7F6C")
                )
            )
        }
        return result
    }

    private fun encodeSubject(subject: Subject): JSONObject = JSONObject().apply {
        put("id", subject.id)
        put("name", subject.name)
        put("color", subject.color)
    }

    private fun decodeItems(array: JSONArray?): MutableList<StudyItem> {
        val result = mutableListOf<StudyItem>()
        if (array == null) return result
        for (i in 0 until array.length()) {
            val obj = array.optJSONObject(i) ?: continue
            result.add(
                StudyItem(
                    id = optString(obj, "id", ""),
                    subjectId = optString(obj, "subjectId", ""),
                    title = optString(obj, "title", ""),
                    createdAt = optLong(obj, "createdAt", 0L),
                    scheduleMode = optString(obj, "scheduleMode", "curve"),
                    curveStage = optInt(obj, "curveStage", 0),
                    fixedIntervalDays = optInt(obj, "fixedIntervalDays", 3),
                    currentIntervalDays = optInt(obj, "currentIntervalDays", 1),
                    nextReviewAt = optLong(obj, "nextReviewAt", 0L),
                    lastReviewedAt = optLong(obj, "lastReviewedAt", 0L),
                    reviewCount = optInt(obj, "reviewCount", 0),
                    status = optString(obj, "status", "active"),
                    fsrsStability = optDouble(obj, "fsrsStability", 0.0),
                    fsrsDifficulty = optDouble(obj, "fsrsDifficulty", 5.0),
                    fsrsState = optString(obj, "fsrsState", "new"),
                    fsrsScheduledDays = optDouble(obj, "fsrsScheduledDays", 0.0),
                    fsrsLapses = optInt(obj, "fsrsLapses", 0),
                    fsrsVersion = optInt(obj, "fsrsVersion", 6)
                )
            )
        }
        return result
    }

    private fun encodeItem(item: StudyItem): JSONObject = JSONObject().apply {
        put("id", item.id)
        put("subjectId", item.subjectId)
        put("title", item.title)
        put("createdAt", item.createdAt)
        put("scheduleMode", item.scheduleMode)
        put("curveStage", item.curveStage)
        put("fixedIntervalDays", item.fixedIntervalDays)
        put("currentIntervalDays", item.currentIntervalDays)
        put("nextReviewAt", item.nextReviewAt)
        put("lastReviewedAt", item.lastReviewedAt)
        put("reviewCount", item.reviewCount)
        put("status", item.status)
        put("fsrsStability", item.fsrsStability)
        put("fsrsDifficulty", item.fsrsDifficulty)
        put("fsrsState", item.fsrsState)
        put("fsrsScheduledDays", item.fsrsScheduledDays)
        put("fsrsLapses", item.fsrsLapses)
        put("fsrsVersion", item.fsrsVersion)
    }

    private fun decodeLogs(array: JSONArray?): MutableList<ReviewLog> {
        val result = mutableListOf<ReviewLog>()
        if (array == null) return result
        for (i in 0 until array.length()) {
            val obj = array.optJSONObject(i) ?: continue
            result.add(
                ReviewLog(
                    id = optString(obj, "id", ""),
                    itemId = optString(obj, "itemId", ""),
                    reviewedAt = optLong(obj, "reviewedAt", 0L),
                    rating = optString(obj, "rating", "got"),
                    previousIntervalDays = optInt(obj, "previousIntervalDays", 0),
                    nextIntervalDays = optInt(obj, "nextIntervalDays", 0),
                    nextReviewAt = optLong(obj, "nextReviewAt", 0L),
                    grade = optInt(obj, "grade", 3),
                    stabilityBefore = optDouble(obj, "stabilityBefore", 0.0),
                    stabilityAfter = optDouble(obj, "stabilityAfter", 0.0),
                    difficultyBefore = optDouble(obj, "difficultyBefore", 0.0),
                    difficultyAfter = optDouble(obj, "difficultyAfter", 0.0),
                    elapsedDays = optInt(obj, "elapsedDays", 0),
                    scheduledDays = optInt(obj, "scheduledDays", 0)
                )
            )
        }
        return result
    }

    private fun encodeLog(log: ReviewLog): JSONObject = JSONObject().apply {
        put("id", log.id)
        put("itemId", log.itemId)
        put("reviewedAt", log.reviewedAt)
        put("rating", log.rating)
        put("previousIntervalDays", log.previousIntervalDays)
        put("nextIntervalDays", log.nextIntervalDays)
        put("nextReviewAt", log.nextReviewAt)
        put("grade", log.grade)
        put("stabilityBefore", log.stabilityBefore)
        put("stabilityAfter", log.stabilityAfter)
        put("difficultyBefore", log.difficultyBefore)
        put("difficultyAfter", log.difficultyAfter)
        put("elapsedDays", log.elapsedDays)
        put("scheduledDays", log.scheduledDays)
    }

    private fun decodeSettings(obj: JSONObject?): Settings {
        if (obj == null) return Settings()
        val times = mutableListOf<SubjectTime>()
        val array = obj.optJSONArray("subjectTimes")
        if (array != null) {
            for (i in 0 until array.length()) {
                val item = array.optJSONObject(i) ?: continue
                times.add(SubjectTime(optString(item, "subjectId", ""), optString(item, "time", "20:00")))
            }
        }
        val focusMinutes = optInt(obj, "focusMinutes", 25)
        return Settings(
            reminderEnabled = obj.optBoolean("reminderEnabled", true),
            reminderTime = optString(obj, "reminderTime", "20:00"),
            subjectTimes = times,
            themeIndex = optInt(obj, "themeIndex", 0),
            language = optString(obj, "language", "zh"),
            targetRetention = optDouble(obj, "targetRetention", 0.9),
            // 老数据没有这一项，按新默认 180 天补齐；0 表示不限
            maxIntervalDays = optInt(obj, "maxIntervalDays", 180),
            focusMinutes = if (focusMinutes < 1) 25 else focusMinutes
        )
    }

    private fun encodeSettings(settings: Settings): JSONObject = JSONObject().apply {
        put("reminderEnabled", settings.reminderEnabled)
        put("reminderTime", settings.reminderTime)
        put("subjectTimes", JSONArray().apply {
            settings.subjectTimes.forEach {
                put(JSONObject().apply {
                    put("subjectId", it.subjectId)
                    put("time", it.time)
                })
            }
        })
        put("themeIndex", settings.themeIndex)
        put("language", settings.language)
        put("targetRetention", settings.targetRetention)
        put("maxIntervalDays", settings.maxIntervalDays)
        put("focusMinutes", settings.focusMinutes)
    }

    private fun decodeSessions(array: JSONArray?): MutableList<FocusSession> {
        val result = mutableListOf<FocusSession>()
        if (array == null) return result
        for (i in 0 until array.length()) {
            val obj = array.optJSONObject(i) ?: continue
            result.add(decodeSession(obj))
        }
        return result
    }

    private fun decodeSession(obj: JSONObject): FocusSession = FocusSession(
        id = optString(obj, "id", ""),
        startedAt = optLong(obj, "startedAt", 0L),
        endedAt = optLong(obj, "endedAt", 0L),
        plannedMinutes = optInt(obj, "plannedMinutes", 25),
        minutes = optInt(obj, "minutes", 0),
        itemCount = optInt(obj, "itemCount", 0),
        remembered = optInt(obj, "remembered", 0),
        completed = obj.optBoolean("completed", false),
        isBreak = if (obj.has("isBreak") && !obj.isNull("isBreak")) obj.optBoolean("isBreak") else null,
        round = if (obj.has("round") && !obj.isNull("round")) obj.optInt("round") else null,
        cycleStart = if (obj.has("cycleStart") && !obj.isNull("cycleStart")) obj.optLong("cycleStart") else null
    )

    private fun encodeSession(session: FocusSession): JSONObject = JSONObject().apply {
        put("id", session.id)
        put("startedAt", session.startedAt)
        put("endedAt", session.endedAt)
        put("plannedMinutes", session.plannedMinutes)
        put("minutes", session.minutes)
        put("itemCount", session.itemCount)
        put("remembered", session.remembered)
        put("completed", session.completed)
        if (session.isBreak != null) put("isBreak", session.isBreak)
        if (session.round != null) put("round", session.round)
        if (session.cycleStart != null) put("cycleStart", session.cycleStart)
    }
}
