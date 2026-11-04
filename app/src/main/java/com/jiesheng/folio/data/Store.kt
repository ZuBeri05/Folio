package com.jiesheng.folio.data

import android.content.Context
import com.jiesheng.folio.domain.AppData
import com.jiesheng.folio.domain.Subject
import com.jiesheng.folio.domain.createDefaultData
import com.jiesheng.folio.domain.fsrs.Migration
import com.jiesheng.folio.domain.withColor

/**
 * 本地持久化。原版用 harmony preferences（STORE_NAME = jiesheng_app，
 * DATA_KEY = app_data_v1），这里用同名 SharedPreferences + 同一个 JSON 结构。
 */
class Store(private val context: Context) {
    companion object {
        private const val STORE_NAME = "jiesheng_app"
        private const val DATA_KEY = "app_data_v1"
    }

    private val prefs = context.getSharedPreferences(STORE_NAME, Context.MODE_PRIVATE)

    fun load(): AppData {
        val raw = prefs.getString(DATA_KEY, "") ?: ""
        if (raw.isEmpty()) {
            return createDefaultData()
        }
        val parsed = Codec.decode(raw) ?: return createDefaultData()
        // 旧结构（schemaVersion < 2）用的是旧色板和旧科目名，迁移前补一次「政治 / 专业课」。
        // 新结构不再补：用户删掉的科目不能每次启动都复活。
        val legacy = parsed.schemaVersion < 2
        if (legacy) {
            val recolored = parsed.subjects.map { subject ->
                when (subject.id) {
                    "math" -> subject.withColor("#E8A21A")
                    "english" -> subject.withColor("#4A90D9")
                    "physics" -> subject.withColor("#8E7CC3")
                    "chinese" -> subject.withColor("#D95F3F")
                    else -> subject
                }
            }.toMutableList()
            parsed.subjects.clear()
            parsed.subjects.addAll(recolored)
            var hasPolitics = false
            var hasMajor = false
            for (subject in parsed.subjects) {
                if (subject.name == "政治") hasPolitics = true
                if (subject.name == "专业课") hasMajor = true
            }
            if (!hasPolitics) {
                parsed.subjects.add(Subject("politics", "政治", "#D95F3F"))
            }
            if (!hasMajor) {
                parsed.subjects.add(Subject("major", "专业课", "#8E7CC3"))
            }
        }
        return try {
            if (Migration.needsMigration(parsed)) {
                val migrated = Migration.migrateAppData(parsed)
                save(migrated)
                migrated
            } else {
                parsed
            }
        } catch (error: Exception) {
            parsed
        }
    }

    fun save(data: AppData) {
        prefs.edit().putString(DATA_KEY, Codec.encode(data)).apply()
    }

    fun saveBlocking(data: AppData) {
        prefs.edit().putString(DATA_KEY, Codec.encode(data)).commit()
    }

    fun clear() {
        prefs.edit().remove(DATA_KEY).apply()
    }
}
