import { describe, expect, it } from 'vitest';
import { review } from '../app/entry/src/main/ets/domain/fsrs/Fsrs.ts';
import {
  fixedIntervalFor,
  fsrsStateFromItem,
  nextDueAt,
  postponeToTomorrow,
  previewForGrades,
  roundFsrsDays,
  scheduleFsrs
} from '../app/entry/src/main/ets/domain/fsrs/Scheduling.ts';

const reviewedItem = {
  id: 'a',
  subjectId: 'math',
  title: '导数',
  createdAt: 1,
  scheduleMode: 'fsrs',
  curveStage: 2,
  fixedIntervalDays: 3,
  currentIntervalDays: 3,
  nextReviewAt: 1,
  lastReviewedAt: new Date(2026, 9, 20).getTime(),
  reviewCount: 2,
  status: 'active',
  fsrsStability: 3,
  fsrsDifficulty: 5,
  fsrsState: 'review',
  fsrsScheduledDays: 3,
  fsrsLapses: 1,
  fsrsVersion: 6
};

describe('FSRS day scheduling', () => {
  it('never schedules today', () => {
    expect(roundFsrsDays(0.2)).toBe(1);
    expect(roundFsrsDays(0.8)).toBe(1);
  });

  it('rounds to whole days', () => {
    expect(roundFsrsDays(2.4)).toBe(2);
    expect(roundFsrsDays(2.6)).toBe(3);
  });

  it('falls back to one day for non-finite intervals', () => {
    expect(roundFsrsDays(NaN)).toBe(1);
    expect(roundFsrsDays(Infinity)).toBe(1);
  });

  it('moves the due date to the next local day', () => {
    const now = new Date(2026, 9, 22, 22, 30).getTime();
    const due = nextDueAt(now, 2);
    const d = new Date(due);
    expect(d.getDate()).toBe(24);
    expect(d.getHours()).toBe(0);
  });
});

describe('FSRS scheduling adapter', () => {
  it('schedules the next review and updates FSRS state', () => {
    const now = new Date(2026, 9, 22, 22, 30).getTime();
    const result = scheduleFsrs(reviewedItem as any, 3, now, 0.9);
    expect(result.nextIntervalDays).toBeGreaterThanOrEqual(1);
    expect(result.nextAt).toBe(nextDueAt(now, result.nextIntervalDays));
    expect(new Date(result.nextAt).getHours()).toBe(0);
    expect(result.stability).toBeGreaterThan(reviewedItem.fsrsStability);
    expect(result.difficulty).toBeGreaterThanOrEqual(1);
    expect(result.difficulty).toBeLessThanOrEqual(10);
    expect(result.curveStage).toBe(reviewedItem.curveStage);
    expect(result.rating).toBe('3');
  });

  it('previews four positive intervals', () => {
    const now = new Date(2026, 9, 22, 22, 30).getTime();
    const intervals = previewForGrades(reviewedItem as any, now, 0.9);
    expect(intervals).toHaveLength(4);
    for (let i = 0; i < intervals.length; i++) {
      expect(intervals[i]).toBeGreaterThanOrEqual(1);
    }
    expect(intervals[3]).toBeGreaterThanOrEqual(intervals[0]);
  });

  it('caps the overdue bonus at 1.5x the planned interval', () => {
    const now = new Date(2026, 9, 22, 22, 30).getTime();
    const day = 86400000;
    const base = {
      ...reviewedItem,
      reviewCount: 3,
      fsrsStability: 10,
      fsrsDifficulty: 5,
      fsrsScheduledDays: 10
    };
    const at = (daysAgo: number) => scheduleFsrs(
      { ...base, lastReviewedAt: now - daysAgo * day } as any, 3, now, 0.9
    ).nextIntervalDays;

    const onTime = at(10);
    const threeLate = at(13);
    const fifteenLate = at(25);
    const sixtyLate = at(70);

    // 轻微逾期照常给奖励
    expect(threeLate).toBeGreaterThan(onTime);
    // 逾期超过 1.5 个周期后完全饱和：再晚也一样
    expect(sixtyLate).toBe(fifteenLate);
    // 饱和值仍然比按时复习宽松，但比不封顶时短
    expect(sixtyLate).toBeGreaterThan(onTime);
    const state = fsrsStateFromItem(base as any);
    const unclamped = Math.max(1, Math.round(review(state, 3, 60, 0.9, now).scheduledDays));
    expect(sixtyLate).toBeLessThan(unclamped);
  });

  it('caps the interval at the configured maximum', () => {
    const now = new Date(2026, 9, 22, 22, 30).getTime();
    const day = 86400000;
    const item = {
      ...reviewedItem,
      reviewCount: 4,
      fsrsStability: 200,
      fsrsDifficulty: 5,
      fsrsScheduledDays: 200,
      lastReviewedAt: now - 200 * day
    };

    const uncapped = scheduleFsrs(item as any, 3, now, 0.9).nextIntervalDays;
    expect(uncapped).toBeGreaterThan(180);

    const capped = scheduleFsrs(item as any, 3, now, 0.9, 180).nextIntervalDays;
    expect(capped).toBe(180);
    expect(capped).toBeLessThan(uncapped);

    // 预览里的四个按钮也要一起夹住，否则点了才发现和显示的不一样
    const previews = previewForGrades(item as any, now, 0.9, 90);
    for (let i = 0; i < previews.length; i++) {
      expect(previews[i]).toBeLessThanOrEqual(90);
    }
  });

  it('treats zero or invalid maximum interval as unlimited', () => {
    const now = new Date(2026, 9, 22, 22, 30).getTime();
    const day = 86400000;
    const item = {
      ...reviewedItem,
      reviewCount: 4,
      fsrsStability: 200,
      fsrsScheduledDays: 200,
      lastReviewedAt: now - 200 * day
    };
    const uncapped = scheduleFsrs(item as any, 3, now, 0.9).nextIntervalDays;
    expect(scheduleFsrs(item as any, 3, now, 0.9, 0).nextIntervalDays).toBe(uncapped);
    expect(scheduleFsrs(item as any, 3, now, 0.9, NaN).nextIntervalDays).toBe(uncapped);
  });

  it('preserves stored FSRS state for reviewed items marked new', () => {
    const now = new Date(2026, 9, 22, 22, 30).getTime();
    const item = {
      ...reviewedItem,
      fsrsState: 'new',
      fsrsStability: 9,
      fsrsDifficulty: 7,
      fsrsScheduledDays: 9,
      fsrsLapses: 2
    };
    const state = fsrsStateFromItem(item as any);
    expect(state.state).toBe('review');
    expect(state.stability).toBe(9);
    expect(state.difficulty).toBe(7);
    expect(state.lapses).toBe(2);
    expect(state.scheduledDays).toBe(9);

    const result = scheduleFsrs(item as any, 3, now, 0.9);
    expect(result.state).toBe('review');
    expect(result.stability).toBeGreaterThan(9);
    expect(result.difficulty).toBeGreaterThan(6.9);
    expect(result.lapses).toBe(2);
  });

  it('falls back when reviewed FSRS values are non-finite', () => {
    const now = new Date(2026, 9, 22, 22, 30).getTime();
    const item = {
      ...reviewedItem,
      fsrsState: 'bogus',
      fsrsStability: NaN,
      fsrsDifficulty: NaN,
      fsrsScheduledDays: NaN,
      fsrsLapses: NaN,
      currentIntervalDays: 6
    };
    const state = fsrsStateFromItem(item as any);
    expect(state.state).toBe('review');
    expect(state.stability).toBe(6);
    expect(state.difficulty).toBe(5);
    expect(state.lapses).toBe(0);
    expect(state.scheduledDays).toBe(6);

    const result = scheduleFsrs(item as any, 3, now, 0.9);
    expect(Number.isFinite(result.stability)).toBe(true);
    expect(Number.isFinite(result.difficulty)).toBe(true);
    expect(result.nextIntervalDays).toBeGreaterThanOrEqual(1);
  });

  it('postpone changes only the due date', () => {
    const now = new Date(2026, 9, 22).getTime();
    const item = {
      id: 'a',
      reviewCount: 3,
      fsrsStability: 3,
      fsrsDifficulty: 5,
      nextReviewAt: 1
    };
    const next = postponeToTomorrow(item as any, now);
    expect(next.reviewCount).toBe(3);
    expect(next.fsrsStability).toBe(3);
    expect(next.fsrsDifficulty).toBe(5);
    expect(next.nextReviewAt).toBeGreaterThan(item.nextReviewAt);
    expect(next.nextReviewAt).toBe(nextDueAt(now, 1));
  });

  it('postpone leaves every other field untouched', () => {
    const now = new Date(2026, 9, 22, 22, 30).getTime();
    const next = postponeToTomorrow(reviewedItem as any, now);
    expect(next).toEqual({ ...reviewedItem, nextReviewAt: nextDueAt(now, 1) });
  });
});

describe('fixed interval scheduling', () => {
  const fixedItem = {
    ...reviewedItem,
    scheduleMode: 'fixed',
    fixedIntervalDays: 10
  };

  it('previews fixed intervals for all four grades', () => {
    const now = new Date(2026, 9, 22).getTime();
    expect(previewForGrades(fixedItem as any, now, 0.9)).toEqual([1, 5, 10, 15]);
    expect(fixedIntervalFor(fixedItem as any, 3)).toBe(10);
  });

  it('schedules a fixed item without changing FSRS state', () => {
    const now = new Date(2026, 9, 22).getTime();
    const good = scheduleFsrs(fixedItem as any, 3, now, 0.9);
    expect(good.nextIntervalDays).toBe(10);
    expect(good.nextAt).toBe(nextDueAt(now, 10));
    expect(good.stability).toBe(reviewedItem.fsrsStability);
    expect(scheduleFsrs(fixedItem as any, 4, now, 0.9).nextIntervalDays).toBe(15);
    expect(scheduleFsrs(fixedItem as any, 1, now, 0.9).nextIntervalDays).toBe(1);
  });
});
