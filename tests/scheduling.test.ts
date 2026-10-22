import { describe, expect, it } from 'vitest';
import { initialState } from '../app/entry/src/main/ets/domain/fsrs/Fsrs.ts';
import { nextDueAt, roundFsrsDays } from '../app/entry/src/main/ets/domain/fsrs/Scheduling.ts';

describe('FSRS day scheduling', () => {
  it('never schedules today', () => {
    expect(roundFsrsDays(0.2)).toBe(1);
    expect(roundFsrsDays(0.8)).toBe(1);
  });

  it('rounds to whole days', () => {
    expect(roundFsrsDays(2.4)).toBe(2);
    expect(roundFsrsDays(2.6)).toBe(3);
  });

  it('moves the due date to the next local day', () => {
    const now = new Date(2026, 9, 22, 22, 30).getTime();
    const due = nextDueAt(now, 2);
    const d = new Date(due);
    expect(d.getDate()).toBe(24);
    expect(d.getHours()).toBe(0);
  });
});
