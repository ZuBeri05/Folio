import { describe, expect, it } from 'vitest';
import {
  initialState,
  preview,
  retrievability,
  review
} from '../app/entry/src/main/ets/domain/fsrs/Fsrs.ts';

describe('FSRS initial state', () => {
  it('gives higher initial stability for easier first grades', () => {
    const again = initialState(1, 1000);
    const hard = initialState(2, 1000);
    const good = initialState(3, 1000);
    const easy = initialState(4, 1000);
    expect(again.stability).toBeGreaterThan(0);
    expect(hard.stability).toBeGreaterThan(again.stability);
    expect(good.stability).toBeGreaterThan(hard.stability);
    expect(easy.stability).toBeGreaterThan(good.stability);
    expect(good.difficulty).toBeCloseTo(6.4133, 3);
  });

  it('previews four positive intervals and keeps the retention ordering', () => {
    const state = initialState(3, 1000);
    const p80 = preview(state, 0, 0.80, 1000);
    const p90 = preview(state, 0, 0.90, 1000);
    const p95 = preview(state, 0, 0.95, 1000);
    expect(p90).toHaveLength(4);
    expect(p90.every((p) => p.intervalDays >= 1)).toBe(true);
    expect(p95[2].intervalDays).toBeLessThanOrEqual(p90[2].intervalDays);
    expect(p80[2].intervalDays).toBeGreaterThanOrEqual(p90[2].intervalDays);
  });
});

describe('FSRS review transitions', () => {
  it('increments lapses and uses relearning after Again', () => {
    const state = initialState(3, 1000);
    const next = review(state, 1, 3, 0.90, 2000);
    expect(next.state).toBe('relearning');
    expect(next.lapses).toBe(1);
  });

  it('does not decrease stability after a successful review', () => {
    const state = initialState(3, 1000);
    const next = review(state, 3, 3, 0.90, 2000);
    expect(next.stability).toBeGreaterThanOrEqual(state.stability);
    expect(next.state).toBe('review');
  });

  it('decays retrievability as elapsed days grow', () => {
    const state = initialState(3, 1000);
    expect(retrievability(state, 0)).toBeGreaterThan(retrievability(state, 10));
  });
});
