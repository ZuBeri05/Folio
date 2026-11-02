import { common } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';

const NOTIFY_ID: number = 9101;

/**
 * 专注结束的提示音。
 * 走消息类通知通道（SOCIAL_COMMUNICATION），和微信、短信同一条，带横幅和系统提示音。
 */
export class FocusAlert {
  private static slotReady: boolean = false;

  /** 开始专注前准备通道；没有通知权限就问一次 */
  static async prepare(context: common.UIAbilityContext): Promise<void> {
    if (!FocusAlert.slotReady) {
      try {
        await notificationManager.addSlot(notificationManager.SlotType.SOCIAL_COMMUNICATION);
      } catch (error) {
        // 通道已经存在，忽略
      }
      FocusAlert.slotReady = true;
    }
    try {
      const enabled: boolean = await notificationManager.isNotificationEnabled();
      if (!enabled) {
        await notificationManager.requestEnableNotification(context);
      }
    } catch (error) {
      // 用户拒绝就安静地结束，只是没有提示音
    }
  }

  static async ring(title: string, text: string): Promise<void> {
    const request: notificationManager.NotificationRequest = {
      id: NOTIFY_ID,
      notificationSlotType: notificationManager.SlotType.SOCIAL_COMMUNICATION,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: title,
          text: text
        }
      }
    };
    try {
      await notificationManager.publish(request);
    } catch (error) {
      // 没有通知权限时静默失败
    }
  }

  static async clear(): Promise<void> {
    try {
      await notificationManager.cancel(NOTIFY_ID);
    } catch (error) {
      // 没有发过就没有可清的
    }
  }
}
