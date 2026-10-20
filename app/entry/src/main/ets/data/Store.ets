import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { AppData, createDefaultData } from '../domain/Models';

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
