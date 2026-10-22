import { describe, expect, it } from 'vitest';
import {
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
