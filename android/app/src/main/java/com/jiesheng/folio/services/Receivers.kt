package com.jiesheng.folio.services

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.jiesheng.folio.data.Store
import com.jiesheng.folio.domain.startOfDayTs

/** 每天固定时间到点：数一遍今天要复习几条，弹通知 */
class DailyReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val store = Store(context)
        val data = store.load()
        if (!data.settings.reminderEnabled) {
            return
        }
        val today = startOfDayTs()
        val due = data.items.count { it.status == "active" && startOfDayTs(it.nextReviewAt) <= today }
        ReminderService.notifyDaily(context, due)
    }
}

/** 专注到点：响一声 */
class FocusEndReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val minutes = intent.getIntExtra("minutes", 0)
        val title = context.getString(com.jiesheng.folio.R.string.focus_done_title)
        val text = if (minutes > 0) {
            context.getString(com.jiesheng.folio.R.string.focus_done_body, minutes)
        } else {
            context.getString(com.jiesheng.folio.R.string.reminder_body)
        }
        ReminderService.notifyFocusEnd(context, title, text)
    }
}

/** 开机后把每日提醒重新挂上（AlarmManager 的重复闹钟重启会丢） */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != Intent.ACTION_BOOT_COMPLETED && action != Intent.ACTION_MY_PACKAGE_REPLACED) {
            return
        }
        val data = Store(context).load()
        ReminderService.sync(context, data.settings, data.items.isNotEmpty())
    }
}
