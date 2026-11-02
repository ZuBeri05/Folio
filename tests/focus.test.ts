import { describe, expect, it } from 'vitest';
import {
  breakMinutesFor,
  cycleSummary,
  durationParts,
  formatClock,
  remainingMs,
  startOfDay,
  summarize,
  todayCount,
  todayMinutes,
  weekBuckets
} from '../app/entry/src/main/ets/domain/focus/Focus.ts';

describe('focus timer clock', () => {
  it('counts down to zero and never goes negative', () => {
    expect(remainingMs(1000, 0)).toBe(1000);
    expect(remainingMs(1000, 400)).toBe(600);
    expect(remainingMs(1000, 1000)).toBe(0);
    expect(remainingMs(1000, 5000)).toBe(0);
  });

  it('formats the remaining time as mm:ss', () => {
    expect(formatClock(25 * 60 * 1000)).toBe('25:00');
    expect(formatClock(24 * 60 * 1000 + 35 * 1000)).toBe('24:35');
    expect(formatClock(9 * 1000)).toBe('00:09');
    expect(formatClock(0)).toBe('00:00');
    // 还剩 400ms 时显示 00:01，不能提前显示 00:00
    expect(formatClock(400)).toBe('00:01');
  });
});

describe('focus session summary', () => {
  const start = new Date(2026, 10, 2, 20, 0, 0).getTime();
  const end = start + 25 * 60 * 1000;

  it('counts only the reviews inside the session window', () => {
    const logs = [
      { reviewedAt: start - 1000, grade: 3 },
      { reviewedAt: start, grade: 3 },
      { reviewedAt: start + 60000, grade: 1 },
      { reviewedAt: start + 120000, grade: 4 },
      { reviewedAt: end, grade: 2 },
      { reviewedAt: end + 1000, grade: 4 }
    ];
    const summary = summarize(start, end, logs);
    expect(summary.itemCount).toBe(4);
    expect(summary.remembered).toBe(2);
    expect(summary.minutes).toBe(25);
  });

  it('drops sessions shorter than a minute', () => {
    const summary = summarize(start, start + 20000, []);
    expect(summary.minutes).toBe(0);
  });

  it('rounds the duration to whole minutes', () => {
    expect(summarize(start, start + 90000, []).minutes).toBe(2);
    expect(summarize(start, start + 61000, []).minutes).toBe(1);
  });
});

describe('focus aggregation', () => {
  const now = new Date(2026, 10, 4, 21, 0, 0).getTime(); // 周三
  const today = startOfDay(now);

  const sessions = [
    { startedAt: today + 10 * 3600000, endedAt: today + 10.4 * 3600000, minutes: 25 },
    { startedAt: today + 11 * 3600000, endedAt: today + 11.75 * 3600000, minutes: 45 },
    { startedAt: today - 86400000, endedAt: today - 86400000 + 1500000, minutes: 25 },
    { startedAt: today - 3 * 86400000, endedAt: today - 3 * 86400000 + 3000000, minutes: 50 }
  ];

  it('sums only today', () => {
    expect(todayMinutes(sessions, now)).toBe(70);
    expect(todayCount(sessions, now)).toBe(2);
  });

  it('buckets the week starting on monday', () => {
    const buckets = weekBuckets(sessions, now);
    expect(buckets.length).toBe(7);
    expect(buckets[0]).toBe(0);
    expect(buckets[1]).toBe(25);
    expect(buckets[2]).toBe(70);
    expect(buckets[6]).toBe(0);
  });

  it('ignores sessions outside the week', () => {
    const older = [{ startedAt: today - 20 * 86400000, endedAt: today - 20 * 86400000 + 60000, minutes: 60 }];
    const buckets = weekBuckets(older, now);
    expect(buckets.reduce((a: number, b: number) => a + b, 0)).toBe(0);
  });

  it('splits minutes into hours and remainder', () => {
    expect(durationParts(0)).toEqual([0, 0]);
    expect(durationParts(25)).toEqual([0, 25]);
    expect(durationParts(75)).toEqual([1, 15]);
    expect(durationParts(-5)).toEqual([0, 0]);
  });
});

describe('pomodoro cycle', () => {
  it('takes a short break after each round and a long one every fourth', () => {
    expect(breakMinutesFor(1)).toBe(5);
    expect(breakMinutesFor(2)).toBe(5);
    expect(breakMinutesFor(3)).toBe(5);
    expect(breakMinutesFor(4)).toBe(15);
    expect(breakMinutesFor(5)).toBe(5);
    expect(breakMinutesFor(8)).toBe(15);
    // 越界值当第一轮
    expect(breakMinutesFor(0)).toBe(5);
  });

  it('adds up only the sessions inside the current cycle', () => {
    const now = new Date(2026, 10, 4, 21, 0, 0).getTime();
    const sessions = [
      { startedAt: now - 7200000, endedAt: now - 5400000, minutes: 30, itemCount: 4, remembered: 3 },
      { startedAt: now - 3600000, endedAt: now - 1800000, minutes: 30, itemCount: 6, remembered: 5 },
      { startedAt: now - 600000, endedAt: now - 300000, minutes: 5, itemCount: 2, remembered: 1 }
    ];
    const cycle = cycleSummary(sessions, now - 3600000);
    expect(cycle.segments).toBe(2);
    expect(cycle.minutes).toBe(35);
    expect(cycle.itemCount).toBe(8);
    expect(cycle.remembered).toBe(6);
  });

  it('returns an empty cycle when nothing started yet', () => {
    const cycle = cycleSummary([], 0);
    expect(cycle.segments).toBe(0);
    expect(cycle.minutes).toBe(0);
    expect(cycle.itemCount).toBe(0);
  });
});