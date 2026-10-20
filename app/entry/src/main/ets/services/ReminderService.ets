import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { common } from '@kit.AbilityKit';
import { Settings } from '../domain/Models';

function parseTime(value: string): number[] {
  const parts = value.split(':');
  if (parts.length !== 2) {
    return [20, 0];
  }
  let hour = Number(parts[0]);
  let minute = Number(parts[1]);
  if (isNaN(hour) || isNaN(minute) || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return [20, 0];
  }
  return [hour, minute];
}

export class ReminderService {
  static async requestPermission(context: common.UIAbilityContext): Promise<boolean> {
    try {
      await notificationManager.requestEnableNotification(context);
      return await notificationManager.isNotificationEnabled();
    } catch (error) {
      return false;
    }
  }

  static async sync(context: common.UIAbilityContext, settings: Settings): Promise<void> {
    try {
      await reminderAgentManager.cancelAllReminders();
    } catch (error) {
      // Ignore cancel failures; new reminders can still be published.
    }

    if (!settings.reminderEnabled) {
      return;
    }

    const enabled = await notificationManager.isNotificationEnabled();
    if (!enabled) {
      const allowed = await this.requestPermission(context);
      if (!allowed) {
        throw new Error('notification permission denied');
      }
    }

    const time = parseTime(settings.reminderTime);
    const request: reminderAgentManager.ReminderRequestAlarm = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
      hour: time[0],
      minute: time[1],
      daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
      actionButton: [
        {
          title: '打开',
          type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE
        }
      ],
      wantAgent: {
        pkgName: 'com.jiesheng.review',
        abilityName: 'EntryAbility'
      },
      ringDuration: 3,
      snoozeTimes: 0,
      title: '结绳',
      content: '该复习了，打开看看今天的内容。',
      expiredContent: '今天的复习还在等你。',
      notificationId: 1001,
      slotType: notificationManager.SlotType.SERVICE_INFORMATION
    };

    await reminderAgentManager.publishReminder(request);
  }
}
