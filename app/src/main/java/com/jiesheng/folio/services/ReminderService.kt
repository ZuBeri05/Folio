package com.jiesheng.folio.services

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.jiesheng.folio.MainActivity
import com.jiesheng.folio.R
import com.jiesheng.folio.domain.Settings
import java.util.Calendar

/**
 * 提醒。
 *
 * 鸿蒙版因为 ReminderAgent 配额为 0，改用系统日历写每日重复日程；
 * Android 上直接回到正统做法：AlarmManager 的每日重复闹钟 + 通知。
 * 行为对齐原来的语义 —— 每天 fixedtime 弹一条「今天有 N 条要复习」的通知，
 * 专注结束另有一次性闹钟。
 */
object ReminderService {
    private const val CHANNEL_REVIEW = "review_reminder"
    private const val CHANNEL_FOCUS = "focus_end"
    private const val DAILY_REQUEST = 9001
    private const val FOCUS_REQUEST = 9101
    private const val DAILY_NOTIFY_ID = 9001
    private const val FOCUS_NOTIFY_ID = 9101

    fun isEnabled(context: Context): Boolean {
        return try {
            NotificationManagerCompat.from(context).areNotificationsEnabled()
        } catch (error: Exception) {
            false
        }
    }

    /** 已安排的提醒条数：开着的每日提醒算 1，专注结束另算 */
    fun count(context: Context): Int {
        return try {
            var total = 0
            if (pendingDaily(context) != null) total += 1
            if (pendingFocus(context) != null) total += 1
            total
        } catch (error: Exception) {
            -1
        }
    }

    private fun pendingDaily(context: Context): PendingIntent? {
        val intent = Intent(context, DailyReminderReceiver::class.java)
        return PendingIntent.getBroadcast(
            context,
            DAILY_REQUEST,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun pendingFocus(context: Context): PendingIntent? {
        val intent = Intent(context, FocusEndReceiver::class.java)
        return PendingIntent.getBroadcast(
            context,
            FOCUS_REQUEST,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /** "calendar" = 已写入每日提醒，"off" = 关闭 */
    fun sync(context: Context, settings: Settings, hasItems: Boolean): String {
        ensureChannels(context)
        if (!settings.reminderEnabled || !hasItems) {
            clearDaily(context)
            return "off"
        }
        val parts = settings.reminderTime.split(":")
        var hour = 20
        var minute = 0
        if (parts.size == 2) {
            val h = parts[0].toIntOrNull()
            val m = parts[1].toIntOrNull()
            if (h != null && h in 0..23) hour = h
            if (m != null && m in 0..59) minute = m
        }
        scheduleDaily(context, hour, minute)
        return "calendar"
    }

    private fun scheduleDaily(context: Context, hour: Int, minute: Int) {
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, DailyReminderReceiver::class.java)
        val pending = PendingIntent.getBroadcast(
            context,
            DAILY_REQUEST,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) {
                add(Calendar.DAY_OF_MONTH, 1)
            }
        }
        // 不精确闹钟不需要额外权限，代价是可能晚几分钟，对复习提醒够用
        alarm.setInexactRepeating(
            AlarmManager.RTC_WAKEUP,
            next.timeInMillis,
            AlarmManager.INTERVAL_DAY,
            pending
        )
    }

    fun clearDaily(context: Context) {
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, DailyReminderReceiver::class.java)
        val pending = PendingIntent.getBroadcast(
            context,
            DAILY_REQUEST,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        if (pending != null) {
            alarm.cancel(pending)
            pending.cancel()
        }
    }

    /** 专注结束时提醒一次；App 在后台、锁屏也能收到 */
    fun scheduleFocusEnd(context: Context, endAt: Long, minutes: Int) {
        try {
            ensureChannels(context)
            val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, FocusEndReceiver::class.java).apply {
                putExtra("minutes", minutes)
            }
            val pending = PendingIntent.getBroadcast(
                context,
                FOCUS_REQUEST,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            if (endAt > System.currentTimeMillis()) {
                alarm.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, endAt, pending)
            }
        } catch (error: Exception) {
            // 没有精确闹钟权限就只靠应用内计时，不影响功能
        }
    }

    fun clearFocusEnd(context: Context) {
        try {
            val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, FocusEndReceiver::class.java)
            val pending = PendingIntent.getBroadcast(
                context,
                FOCUS_REQUEST,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pending != null) {
                alarm.cancel(pending)
                pending.cancel()
            }
        } catch (error: Exception) {
            // 没权限或还没建过，什么都不用做
        }
    }

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val review = NotificationChannel(
            CHANNEL_REVIEW,
            context.getString(R.string.channel_review),
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = context.getString(R.string.channel_review_desc)
        }
        // 专注结束走「社交」级别的通道，和微信、短信一样带横幅和提示音
        val focus = NotificationChannel(
            CHANNEL_FOCUS,
            context.getString(R.string.channel_focus),
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = context.getString(R.string.channel_focus_desc)
        }
        manager.createNotificationChannel(review)
        manager.createNotificationChannel(focus)
    }

    fun notifyDaily(context: Context, dueCount: Int) {
        ensureChannels(context)
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pending = PendingIntent.getActivity(
            context,
            DAILY_NOTIFY_ID,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val text = if (dueCount > 0) {
            context.resources.getQuantityString(R.plurals.reminder_due, dueCount, dueCount)
        } else {
            context.getString(R.string.reminder_body)
        }
        val notification = NotificationCompat.Builder(context, CHANNEL_REVIEW)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(context.getString(R.string.reminder_title))
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setContentIntent(pending)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(DAILY_NOTIFY_ID, notification)
        } catch (error: Exception) {
            // 没有通知权限时静默失败
        }
    }

    fun notifyFocusEnd(context: Context, title: String, text: String) {
        ensureChannels(context)
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pending = PendingIntent.getActivity(
            context,
            FOCUS_NOTIFY_ID,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_FOCUS)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(pending)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(FOCUS_NOTIFY_ID, notification)
        } catch (error: Exception) {
            // 没有通知权限时静默失败
        }
    }

    /** 开始专注前准备通道；没有通知权限就问一次 */
    fun prepare(context: Context) {
        ensureChannels(context)
    }

    /** 应用内的提示音，用于专注结束那一声 */
    fun ring(context: Context, title: String, text: String) {
        notifyFocusEnd(context, title, text)
    }

    fun clearFocusNotification(context: Context) {
        try {
            NotificationManagerCompat.from(context).cancel(FOCUS_NOTIFY_ID)
        } catch (error: Exception) {
            // 没有发过就没有可清的
        }
    }
}
