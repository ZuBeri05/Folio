package com.jiesheng.folio.domain

import java.util.Calendar

const val DAY_MS: Long = 86_400_000L

fun startOfDayTs(ts: Long): Long {
    val c = Calendar.getInstance()
    c.timeInMillis = ts
    c.set(Calendar.HOUR_OF_DAY, 0)
    c.set(Calendar.MINUTE, 0)
    c.set(Calendar.SECOND, 0)
    c.set(Calendar.MILLISECOND, 0)
    return c.timeInMillis
}

fun startOfDayTs(): Long = startOfDayTs(System.currentTimeMillis())

fun addDaysTs(ts: Long, days: Int): Long {
    val c = Calendar.getInstance()
    c.timeInMillis = ts
    c.set(Calendar.HOUR_OF_DAY, 0)
    c.set(Calendar.MINUTE, 0)
    c.set(Calendar.SECOND, 0)
    c.set(Calendar.MILLISECOND, 0)
    c.add(Calendar.DAY_OF_MONTH, days)
    return c.timeInMillis
}

fun daysBetween(from: Long, to: Long): Int {
    val a = startOfDayTs(from)
    val b = startOfDayTs(to)
    return maxOf(0, Math.round((b - a).toDouble() / DAY_MS).toInt())
}

/** 周一 = 0，和鸿蒙版 `(getDay() + 6) % 7` 一致 */
fun mondayIndex(ts: Long): Int {
    val c = Calendar.getInstance()
    c.timeInMillis = ts
    // Calendar.DAY_OF_WEEK: 周日 = 1
    return (c.get(Calendar.DAY_OF_WEEK) + 5) % 7
}

fun dayOfWeekIndex(ts: Long): Int {
    val c = Calendar.getInstance()
    c.timeInMillis = ts
    return c.get(Calendar.DAY_OF_WEEK) % 7
}

fun monthOf(ts: Long): Int {
    val c = Calendar.getInstance()
    c.timeInMillis = ts
    return c.get(Calendar.MONTH) + 1
}

fun dayOfMonth(ts: Long): Int {
    val c = Calendar.getInstance()
    c.timeInMillis = ts
    return c.get(Calendar.DAY_OF_MONTH)
}

fun yearOf(ts: Long): Int {
    val c = Calendar.getInstance()
    c.timeInMillis = ts
    return c.get(Calendar.YEAR)
}

fun hourOf(ts: Long): Int {
    val c = Calendar.getInstance()
    c.timeInMillis = ts
    return c.get(Calendar.HOUR_OF_DAY)
}

fun minuteOf(ts: Long): Int {
    val c = Calendar.getInstance()
    c.timeInMillis = ts
    return c.get(Calendar.MINUTE)
}

fun hourMinuteLabel(ts: Long): String {
    val h = hourOf(ts)
    val m = minuteOf(ts)
    return (if (h < 10) "0$h" else "$h") + ":" + (if (m < 10) "0$m" else "$m")
}

fun pad2(value: Int): String = if (value < 10) "0$value" else "$value"
