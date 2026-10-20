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
