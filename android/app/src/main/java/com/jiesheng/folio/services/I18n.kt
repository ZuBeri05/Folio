package com.jiesheng.folio.services

import com.jiesheng.folio.domain.dayOfMonth
import com.jiesheng.folio.domain.dayOfWeekIndex
import com.jiesheng.folio.domain.monthOf
import com.jiesheng.folio.domain.pad2

data class LanguageOption(val code: String, val name: String, val locale: String)

/**
 * 界面语言。文案表在 I18nTables.kt（由原版 I18n.ets 转换），这里只负责查表与日期格式化。
 */
object I18n {
    val languages: List<LanguageOption> = listOf(
        LanguageOption("zh", "中文", "zh-CN"),
        LanguageOption("en", "English", "en-US"),
        LanguageOption("ja", "日本語", "ja-JP"),
        LanguageOption("ko", "한국어", "ko-KR"),
        LanguageOption("fr", "Français", "fr-FR"),
        LanguageOption("es", "Español", "es-ES")
    )

    fun t(lang: String, key: String, a: String? = null, b: String? = null): String {
        val table = I18nTables.all[lang] ?: I18nTables.en
        var value = table[key] ?: I18nTables.en[key] ?: key
        if (a != null) {
            value = value.replace("{0}", a)
        }
        if (b != null) {
            value = value.replace("{1}", b)
        }
        return value
    }

    private fun months(lang: String): List<String> = when (lang) {
        "en" -> listOf(
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December"
        )
        "ja" -> listOf(
            "1月", "2月", "3月", "4月", "5月", "6月",
            "7月", "8月", "9月", "10月", "11月", "12月"
        )
        "ko" -> listOf(
            "1월", "2월", "3월", "4월", "5월", "6월",
            "7월", "8월", "9월", "10월", "11월", "12월"
        )
        "fr" -> listOf(
            "janvier", "février", "mars", "avril", "mai", "juin",
            "juillet", "août", "septembre", "octobre", "novembre", "décembre"
        )
        "es" -> listOf(
            "enero", "febrero", "marzo", "abril", "mayo", "junio",
            "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"
        )
        else -> listOf(
            "1 月", "2 月", "3 月", "4 月", "5 月", "6 月",
            "7 月", "8 月", "9 月", "10 月", "11 月", "12 月"
        )
    }

    private fun weekdays(lang: String): List<String> = when (lang) {
        "en" -> listOf("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")
        "ja" -> listOf("日", "月", "火", "水", "木", "金", "土")
        "ko" -> listOf("일", "월", "화", "수", "목", "금", "토")
        "fr" -> listOf("dim.", "lun.", "mar.", "mer.", "jeu.", "ven.", "sam.")
        "es" -> listOf("dom", "lun", "mar", "mié", "jue", "vie", "sáb")
        else -> listOf("周日", "周一", "周二", "周三", "周四", "周五", "周六")
    }

    /** 紧凑日期：10.24 / 10/24 / 24/10 */
    fun dateShort(lang: String, ts: Long): String {
        val month = monthOf(ts)
        val day = dayOfMonth(ts)
        if (lang == "zh") {
            return pad2(month) + "." + pad2(day)
        }
        if (lang == "fr" || lang == "es") {
            return pad2(day) + "/" + pad2(month)
        }
        return pad2(month) + "/" + pad2(day)
    }

    /** 完整日期：10 月 24 日 / October 24 / 24 octobre */
    fun dateLong(lang: String, ts: Long): String {
        val month = months(lang)[monthOf(ts) - 1]
        val day = dayOfMonth(ts)
        return when (lang) {
            "en" -> "$month $day"
            "fr" -> "$day $month"
            "es" -> "$day de $month"
            "ko" -> "$month ${day}일"
            "ja" -> "$month${day}日"
            else -> "$month $day 日"
        }
    }

    /** 星期：周一 / Mon / 月 / 월 */
    fun weekday(lang: String, ts: Long): String = weekdays(lang)[dayOfWeekIndex(ts)]

    fun locale(lang: String): String {
        for (option in languages) {
            if (option.code == lang) {
                return option.locale
            }
        }
        return "zh-CN"
    }

    /**
     * 顶部那一行日期。对齐鸿蒙版 `Intl.DateTimeFormat(locale, {year, month:'long',
     * day, weekday:'long'})` 的输出，并把第一个逗号换成 " · "。
     */
    fun localizedToday(lang: String, ts: Long): String {
        val pattern = when (lang) {
            "en" -> "EEEE, MMMM d, yyyy"
            "ja" -> "yyyy年M月d日EEEE"
            "ko" -> "yyyy년 M월 d일 EEEE"
            "fr" -> "EEEE d MMMM yyyy"
            "es" -> "EEEE, d 'de' MMMM 'de' yyyy"
            else -> "yyyy年M月d日EEEE"
        }
        return try {
            val locale = java.util.Locale.forLanguageTag(locale(lang))
            val formatter = java.text.SimpleDateFormat(pattern, locale)
            formatter.format(java.util.Date(ts)).replaceFirst(",", " · ")
        } catch (error: Exception) {
            dateLong(lang, ts) + " · " + weekday(lang, ts)
        }
    }
}
