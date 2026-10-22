import { describe, expect, it } from 'vitest';
import { migrateAppData, migrateItem } from '../app/entry/src/main/ets/domain/fsrs/Migration.ts';

const base = {
  id: 'a', subjectId: 'math', title: '导数', createdAt: 1,
  scheduleMode: 'curve', curveStage: 2, fixedIntervalDays: 3,
  currentIntervalDays: 4, nextReviewAt: 1000, lastReviewedAt: 500,
  reviewCount: 2, status: 'active'
};

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
});
