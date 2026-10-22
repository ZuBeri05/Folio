export const W: number[] = [
  0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334,
  3.0194, 0.001, 1.8722, 0.1666, 0.796, 1.4835,
  0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425,
  0.0912, 0.0658, 0.1542
];

const DECAY: number = -W[20];
const FACTOR: number = Math.pow(0.9, 1 / DECAY) - 1;

export interface FsrsState {
  stability: number;
  difficulty: number;
  state: string;
  lapses: number;
  scheduledDays: number;
  lastReviewedAt: number;
}

export interface FsrsPreview {
  grade: number;
  intervalDays: number;
}

function clamp(value: number, low: number, high: number): number {
  return Math.min(high, Math.max(low, value));
}

function clampGrade(grade: number): number {
  return Math.round(clamp(grade, 1, 4));
}

function clampState(state: FsrsState): FsrsState {
  return {
    stability: clamp(state.stability, 0.1, 36500),
    difficulty: clamp(state.difficulty, 1, 10),
    state: ['new', 'learning', 'review', 'relearning'].includes(state.state) ? state.state : 'review',
    lapses: Math.max(0, Math.round(state.lapses)),
    scheduledDays: Math.max(0, Math.round(state.scheduledDays)),
    lastReviewedAt: state.lastReviewedAt
  };
}

export function retrievability(state: FsrsState, elapsedDays: number): number {
  const elapsed = Math.max(0, elapsedDays);
  return Math.pow(1 + FACTOR * elapsed / Math.max(0.1, state.stability), DECAY);
}

export function initialState(grade: number, now: number): FsrsState {
  const g = clampGrade(grade);
  return {
    stability: W[g - 1],
    difficulty: clamp(W[4] - (g - 3) * W[5], 1, 10),
    state: g === 1 ? 'learning' : 'review',
    lapses: 0,
    scheduledDays: 0,
    lastReviewedAt: now
  };
}

function nextDifficulty(difficulty: number, grade: number): number {
  const next = W[7] * W[4] + (1 - W[7]) * (difficulty - W[6] * (grade - 3));
  return clamp(next, 1, 10);
}

function nextStability(state: FsrsState, grade: number, elapsedDays: number): number {
  const r = retrievability(state, elapsedDays);
  const d = state.difficulty;
  const s = state.stability;
  if (grade === 1) {
    return W[11] * Math.pow(d, -W[12]) * (Math.pow(s + 1, W[13]) - 1) * Math.exp(W[14] * (1 - r));
  }
  const hardFactor = grade === 2 ? W[15] : 1;
  const easyFactor = grade === 4 ? W[16] : 1;
  const growth = Math.exp(W[8]) * (11 - d) * Math.pow(s, -W[9]) *
    (Math.exp(W[10] * (1 - r)) - 1) * hardFactor * easyFactor + 1;
  return s * growth;
}

function intervalFor(stability: number, retention: number): number {
  const raw = stability / FACTOR * (Math.pow(retention, 1 / DECAY) - 1);
  return Math.max(1, Math.round(raw));
}

export function review(
  state: FsrsState,
  grade: number,
  elapsedDays: number,
  retention: number,
  now: number
): FsrsState {
  const g = clampGrade(grade);
  const safeRetention = clamp(retention, 0.80, 0.95);
  const base = state.state === 'new' ? initialState(g, now) : clampState(state);
  if (state.state === 'new') {
    const interval = intervalFor(base.stability, safeRetention);
    return { ...base, scheduledDays: interval, lastReviewedAt: now };
  }
  const stability = clamp(nextStability(base, g, elapsedDays), 0.1, 36500);
  const difficulty = nextDifficulty(base.difficulty, g);
  const interval = intervalFor(stability, safeRetention);
  return {
    stability,
    difficulty,
    state: g === 1 ? 'relearning' : 'review',
    lapses: base.lapses + (g === 1 ? 1 : 0),
    scheduledDays: interval,
    lastReviewedAt: now
  };
}

export function preview(
  state: FsrsState,
  elapsedDays: number,
  retention: number,
  now: number
): FsrsPreview[] {
  const result: FsrsPreview[] = [];
  for (let grade = 1; grade <= 4; grade++) {
    result.push({ grade, intervalDays: review(state, grade, elapsedDays, retention, now).scheduledDays });
  }
  return result;
}
