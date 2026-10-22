import { describe, expect, it } from 'vitest';
import { migrateAppData, migrateItem, needsMigration } from '../app/entry/src/main/ets/domain/fsrs/Migration.ts';

const base = {
  id: 'a', subjectId: 'math', title: '导数', createdAt: 1,
  scheduleMode: 'curve', curveStage: 2, fixedIntervalDays: 3,
  currentIntervalDays: 4, nextReviewAt: 1000, lastReviewedAt: 500,
  reviewCount: 2, status: 'active'
};

const validSettings = {
  reminderEnabled: true,
  reminderTime: '20:00',
  subjectTimes: [],
  themeIndex: 0,
  language: 'zh',
  curveDays: [1, 2, 4, 7, 15, 30, 60],
  targetRetention: 0.9
};

function makeValidData(): any {
  return {
    schemaVersion: 2,
    subjects: [{ id: 'math', name: '数学', color: '#E8A21A' }],
    items: [{
      ...base, scheduleMode: 'fsrs', fsrsStability: 9, fsrsDifficulty: 7,
      fsrsState: 'review', fsrsScheduledDays: 9, fsrsLapses: 2, fsrsVersion: 6
    }],
    logs: [{
      id: 'l', itemId: 'a', reviewedAt: 1, rating: 'got',
      previousIntervalDays: 1, nextIntervalDays: 9, nextReviewAt: 9,
      grade: 3, stabilityBefore: 1, stabilityAfter: 2,
      difficultyBefore: 5, difficultyAfter: 5, elapsedDays: 1, scheduledDays: 9
    }],
    settings: { ...validSettings }
  };
}

describe('migration', () => {
  it('preserves reviewed item due date and estimates stability', () => {
    const result = migrateItem({ ...base, scheduleMode: 'curve' });
    expect(result.nextReviewAt).toBe(1000);
    expect(result.scheduleMode).toBe('fsrs');
    expect(result.fsrsState).toBe('review');
    expect(result.fsrsStability).toBeGreaterThanOrEqual(1);
    expect(result.fsrsDifficulty).toBe(5);
  });

  it('leaves unreviewed items as new', () => {
    const result = migrateItem({ ...base, reviewCount: 0, lastReviewedAt: 0 });
    expect(result.fsrsState).toBe('new');
    expect(result.fsrsStability).toBe(0);
  });

  it('migrates app data to schema 2 and backfills logs and settings', () => {
    const result = migrateAppData({
      subjects: [],
      items: [{ ...base, scheduleMode: 'curve' }],
      logs: [{
        id: 'l1', itemId: 'a', reviewedAt: 900, rating: 'fuzzy',
        previousIntervalDays: 2, nextIntervalDays: 4, nextReviewAt: 1000
      }],
      settings: {
        reminderEnabled: true, reminderTime: '20:00', subjectTimes: [],
        themeIndex: 0, language: 'zh', curveDays: [1, 2, 4]
      }
    });
    expect(result.schemaVersion).toBe(2);
    expect(result.items[0].nextReviewAt).toBe(1000);
    expect(result.items[0].fsrsState).toBe('review');
    expect(result.logs[0].grade).toBe(2);
    expect(result.logs[0].stabilityBefore).toBe(0);
    expect(result.logs[0].elapsedDays).toBe(2);
    expect(result.logs[0].scheduledDays).toBe(4);
    expect(result.settings.targetRetention).toBe(0.9);
  });

  it('does not reset an already-valid FSRS item', () => {
    const valid = {
      ...base,
      scheduleMode: 'fsrs', fsrsStability: 9, fsrsDifficulty: 7,
      fsrsState: 'review', fsrsScheduledDays: 9, fsrsLapses: 2, fsrsVersion: 6
    };
    const once = migrateItem(valid as any);
    const twice = migrateItem(once as any);
    expect(once.fsrsStability).toBe(9);
    expect(twice.fsrsStability).toBe(9);
    expect(twice.fsrsDifficulty).toBe(7);
    expect(twice.fsrsLapses).toBe(2);
    expect(twice.fsrsScheduledDays).toBe(9);
  });

  it('detects legacy items, logs, and settings separately', () => {
    const valid = makeValidData();
    expect(needsMigration(valid)).toBe(false);

    const legacyItem = makeValidData();
    legacyItem.items[0] = { ...base, fsrsVersion: 6, fsrsState: 'new', fsrsStability: 0 };
    expect(needsMigration(legacyItem)).toBe(true);

    const legacyLog = makeValidData();
    delete legacyLog.logs[0].grade;
    expect(needsMigration(legacyLog)).toBe(true);

    const legacySettings = makeValidData();
    delete legacySettings.settings.targetRetention;
    expect(needsMigration(legacySettings)).toBe(true);

    const legacySchema = makeValidData();
    legacySchema.schemaVersion = 1;
    expect(needsMigration(legacySchema)).toBe(true);
  });

  it('detects incomplete FSRS fields on version 6 items', () => {
    const noScheduledDays = makeValidData();
    delete noScheduledDays.items[0].fsrsScheduledDays;
    expect(needsMigration(noScheduledDays)).toBe(true);

    const noLapses = makeValidData();
    delete noLapses.items[0].fsrsLapses;
    expect(needsMigration(noLapses)).toBe(true);
  });

  it('does not re-migrate fully valid data', () => {
    const data = makeValidData();
    data.items[0] = {
      ...base, scheduleMode: 'fsrs', fsrsStability: 4, fsrsDifficulty: 5,
      fsrsState: 'review', fsrsScheduledDays: 4, fsrsLapses: 0, fsrsVersion: 6
    };
    data.logs[0] = {
      id: 'l', itemId: 'a', reviewedAt: 1, rating: 'got',
      previousIntervalDays: 1, nextIntervalDays: 4, nextReviewAt: 9,
      grade: 3, stabilityBefore: 0, stabilityAfter: 0,
      difficultyBefore: 0, difficultyAfter: 0, elapsedDays: 1, scheduledDays: 4
    };
    data.settings = { ...validSettings, targetRetention: 0.8, curveDays: [1, 2] };

    expect(needsMigration(data)).toBe(false);
    const migrated = migrateAppData(data);
    expect(migrated.items[0].fsrsStability).toBe(4);
    expect(migrated.items[0].fsrsDifficulty).toBe(5);
    expect(migrated.settings.targetRetention).toBe(0.8);
  });

  it('is idempotent for mixed valid and legacy data', () => {
    const validItem = {
      ...base, id: 'valid', scheduleMode: 'fsrs', fsrsStability: 9,
      fsrsDifficulty: 7, fsrsState: 'review', fsrsScheduledDays: 9,
      fsrsLapses: 2, fsrsVersion: 6
    };
    const legacyItem = {
      ...base, id: 'legacy', scheduleMode: 'curve', currentIntervalDays: 4
    };
    const validLog = {
      id: 'valid-log', itemId: 'valid', reviewedAt: 1, rating: 'got',
      previousIntervalDays: 1, nextIntervalDays: 9, nextReviewAt: 9,
      grade: 3, stabilityBefore: 1.1, stabilityAfter: 2.2,
      difficultyBefore: 4.4, difficultyAfter: 5.5, elapsedDays: 1, scheduledDays: 9
    };
    const legacyLog = {
      id: 'legacy-log', itemId: 'legacy', reviewedAt: 2, rating: 'fuzzy',
      previousIntervalDays: 2, nextIntervalDays: 4, nextReviewAt: 10
    };
    const data: any = {
      schemaVersion: 2,
      subjects: [{ id: 'math', name: '数学', color: '#E8A21A' }],
      items: [legacyItem, validItem],
      logs: [legacyLog, validLog],
      settings: { ...validSettings, targetRetention: 0.8 }
    };

    expect(needsMigration(data)).toBe(true);
    const once = migrateAppData(data);
    const twice = migrateAppData(once as any);

    expect(once.items[0].fsrsStability).toBe(4);
    expect(once.items[0].fsrsScheduledDays).toBe(4);
    expect(once.items[1]).toBe(validItem);
    expect(once.logs[0].grade).toBe(2);
    expect(once.logs[0].stabilityBefore).toBe(0);
    expect(once.logs[1]).toBe(validLog);
    expect(once.settings.targetRetention).toBe(0.8);
    expect(once.subjects).toEqual(data.subjects);
    expect(twice).toEqual(once);
  });

  it('repairs a retention value outside the supported range', () => {
    const data = makeValidData();
    data.settings.targetRetention = 0.5;
    expect(needsMigration(data)).toBe(true);
    expect(migrateAppData(data).settings.targetRetention).toBe(0.9);
  });
});
