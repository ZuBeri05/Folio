import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { AppData, createDefaultData } from '../domain/Models';
import { migrateAppData, needsMigration } from '../domain/fsrs/Migration';

const STORE_NAME: string = 'jiesheng_app';
const DATA_KEY: string = 'app_data_v1';

export class Store {
  static async load(context: common.UIAbilityContext): Promise<AppData> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME);
      const raw = await store.get(DATA_KEY, '') as string;
      if (raw.length === 0) {
        return createDefaultData();
      }
      const parsed = JSON.parse(raw) as AppData;
      if (!parsed.subjects || !parsed.items || !parsed.logs || !parsed.settings) {
        return createDefaultData();
      }
      if (typeof parsed.settings.themeIndex !== 'number') {
        parsed.settings.themeIndex = 0;
      }
      if (typeof parsed.settings.language !== 'string') {
        parsed.settings.language = 'zh';
      }
      if (typeof parsed.settings.maxIntervalDays !== 'number') {
        // 老数据没有这一项，按新默认 180 天补齐；0 表示不限
        parsed.settings.maxIntervalDays = 180;
      }
      if (typeof parsed.settings.focusMinutes !== 'number' || parsed.settings.focusMinutes < 1) {
        parsed.settings.focusMinutes = 25;
      }
      if (!Array.isArray(parsed.focusSessions)) {
        parsed.focusSessions = [];
      }
      if (parsed.activeFocus === undefined || parsed.activeFocus === null) {
        parsed.activeFocus = null;
      }
      // 旧结构（schemaVersion < 2）用的是旧色板和旧科目名，迁移前补一次「政治 / 专业课」。
      // 新结构不再补：用户删掉的科目不能每次启动都复活。
      const legacy = typeof parsed.schemaVersion !== 'number' || parsed.schemaVersion < 2;
      if (legacy) {
        for (let i = 0; i < parsed.subjects.length; i++) {
          const subject = parsed.subjects[i];
          if (subject.id === 'math') {
            subject.color = '#E8A21A';
          } else if (subject.id === 'english') {
            subject.color = '#4A90D9';
          } else if (subject.id === 'physics') {
            subject.color = '#8E7CC3';
          } else if (subject.id === 'chinese') {
            subject.color = '#D95F3F';
          }
        }
        let hasPolitics = false;
        let hasMajor = false;
        for (let i = 0; i < parsed.subjects.length; i++) {
          if (parsed.subjects[i].name === '政治') {
            hasPolitics = true;
          }
          if (parsed.subjects[i].name === '专业课') {
            hasMajor = true;
          }
        }
        if (!hasPolitics) {
          parsed.subjects.push({ id: 'politics', name: '政治', color: '#D95F3F' });
        }
        if (!hasMajor) {
          parsed.subjects.push({ id: 'major', name: '专业课', color: '#8E7CC3' });
        }
      }
      try {
        if (needsMigration(parsed)) {
          const migrated = migrateAppData(parsed);
          await Store.save(context, migrated as AppData);
          return migrated as AppData;
        }
      } catch (error) {
        console.error('FSRS migration failed; keeping parsed data', error);
        return parsed;
      }
      return parsed;
    } catch (error) {
      return createDefaultData();
    }
  }

  static async save(context: common.UIAbilityContext, data: AppData): Promise<void> {
    const store = await preferences.getPreferences(context, STORE_NAME);
    await store.put(DATA_KEY, JSON.stringify(data));
    await store.flush();
  }

  static async clear(context: common.UIAbilityContext): Promise<void> {
    const store = await preferences.getPreferences(context, STORE_NAME);
    await store.delete(DATA_KEY);
    await store.flush();
  }
}
