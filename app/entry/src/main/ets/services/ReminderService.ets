import { calendarManager } from '@kit.CalendarKit';
import { abilityAccessCtrl, common, Permissions, PermissionRequestResult } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
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
  private static account: calendarManager.CalendarAccount = {
    name: 'JieshengReview',
    type: calendarManager.CalendarType.LOCAL,
    displayName: '结绳复习'
  };

  /** 专注结束的提醒单独一个日历，免得被每日提醒的 sync() 顺手清掉 */
  private static focusAccount: calendarManager.CalendarAccount = {
    name: 'JieshengFocus',
    type: calendarManager.CalendarType.LOCAL,
    displayName: '专注计时'
  };

  private static config: calendarManager.CalendarConfig = {
    enableReminder: true,
    color: '#FFC531'
  };

  static async isEnabled(): Promise<boolean> {
    try {
      return await notificationManager.isNotificationEnabled();
    } catch (error) {
      return false;
    }
  }

  static async count(context: common.UIAbilityContext): Promise<number> {
    try {
      const calendar = await ReminderService.getCalendar(context);
      const events = await calendar.getEvents();
      return events.length;
    } catch (error) {
      return -1;
    }
  }

  static async sync(context: common.UIAbilityContext, settings: Settings, hasItems: boolean): Promise<string> {
    if (!settings.reminderEnabled || !hasItems) {
      await ReminderService.clearCalendar(context);
      return 'off';
    }

    await ReminderService.requestCalendarPermission(context);
    const calendar = await ReminderService.getCalendar(context);
    await ReminderService.clearEvents(calendar);

    const time = parseTime(settings.reminderTime);
    const start = new Date();
    start.setHours(time[0], time[1], 0, 0);
    if (start.getTime() <= Date.now()) {
      start.setDate(start.getDate() + 1);
    }
    const end = new Date(start.getTime() + 15 * 60 * 1000);

    const event: calendarManager.Event = {
      title: 'Folio · 复习提醒',
      description: '打开 Folio，看看今天要复习的内容。',
      type: calendarManager.EventType.NORMAL,
      startTime: start.getTime(),
      endTime: end.getTime(),
      reminderTime: [0],
      recurrenceRule: {
        recurrenceFrequency: calendarManager.RecurrenceFrequency.DAILY,
        count: 60,
        interval: 1
      }
    };
    await calendar.addEvent(event);
    return 'calendar';
  }

  private static async requestCalendarPermission(context: common.UIAbilityContext): Promise<void> {
    const manager = abilityAccessCtrl.createAtManager();
    const permissions: Permissions[] = ['ohos.permission.READ_CALENDAR', 'ohos.permission.WRITE_CALENDAR'];
    const result: PermissionRequestResult = await manager.requestPermissionsFromUser(context, permissions);
    for (let i = 0; i < result.authResults.length; i++) {
      if (result.authResults[i] !== 0) {
        throw new Error('需要日历权限才能写入复习提醒');
      }
    }
  }

  private static async getCalendar(context: common.UIAbilityContext): Promise<calendarManager.Calendar> {
    return ReminderService.getCalendarFor(context, ReminderService.account);
  }

  /** 专注结束时提醒一次；App 在后台、锁屏也能收到 */
  static async scheduleFocusEnd(context: common.UIAbilityContext, endAt: number, minutes: number): Promise<void> {
    try {
      await ReminderService.requestCalendarPermission(context);
      const calendar = await ReminderService.getCalendarFor(context, ReminderService.focusAccount);
      await ReminderService.clearEvents(calendar);
      const event: calendarManager.Event = {
        title: 'Folio · 专注结束',
        description: '专注 ' + minutes + ' 分钟到点了，回来看看复习进度。',
        type: calendarManager.EventType.NORMAL,
        startTime: endAt,
        endTime: endAt + 5 * 60 * 1000,
        reminderTime: [0]
      };
      await calendar.addEvent(event);
    } catch (error) {
      // 没有日历权限就只靠应用内计时，不影响功能
    }
  }

  static async clearFocusEnd(context: common.UIAbilityContext): Promise<void> {
    try {
      const calendar = await ReminderService.getCalendarFor(context, ReminderService.focusAccount);
      await ReminderService.clearEvents(calendar);
    } catch (error) {
      // 没权限或还没建过日历，什么都不用做
    }
  }

  private static async getCalendarFor(context: common.UIAbilityContext,
    account: calendarManager.CalendarAccount): Promise<calendarManager.Calendar> {
    const manager = calendarManager.getCalendarManager(context);
    let calendar: calendarManager.Calendar;
    try {
      calendar = await manager.getCalendar(account);
    } catch (error) {
      calendar = await manager.createCalendar(account);
    }
    try {
      await calendar.setConfig(ReminderService.config);
    } catch (error) {
      // The reminder flag may already be set.
    }
    return calendar;
  }

  private static async clearCalendar(context: common.UIAbilityContext): Promise<void> {
    try {
      const calendar = await ReminderService.getCalendar(context);
      await ReminderService.clearEvents(calendar);
    } catch (error) {
      // No calendar permission or no calendar yet; nothing to clear.
    }
  }

  private static async clearEvents(calendar: calendarManager.Calendar): Promise<void> {
    const events = await calendar.getEvents();
    for (let i = 0; i < events.length; i++) {
      const id = events[i].id;
      await new Promise<void>((resolve: () => void) => {
        calendar.deleteEvent(id, (err: BusinessError) => {
          resolve();
        });
      });
    }
  }
}
