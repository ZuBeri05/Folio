import { FsrsPreview, FsrsState, preview, review } from './Fsrs.ts';

const DAY_MS: number = 86400000;

export interface SchedulingItem {
  id: string;
  subjectId: string;
  title: string;
  createdAt: number;
  scheduleMode: string;
  curveStage: number;
  fixedIntervalDays: number;
  currentIntervalDays: number;
  nextReviewAt: number;
  lastReviewedAt: number;
  reviewCount: number;
  status: string;
  fsrsStability: number;
  fsrsDifficulty: number;
  fsrsState: string;
  fsrsScheduledDays: number;
  fsrsLapses: number;
  fsrsVersion: number;
}

export interface FsrsScheduleResult {
  nextAt: number;
  nextIntervalDays: number;
  curveStage: number;
  rating: string;
  stability: number;
  difficulty: number;
  state: string;
  lapses: number;
  scheduledDays: number;
}

export function roundFsrsDays(raw: number): number {
  if (!isFiniteNumber(raw)) {
    return 1;
  }
  return Math.max(1, Math.round(raw));
}

export function nextDueAt(now: number, days: number): number {
  const d = new Date(now);
  d.setHours(0, 0, 0, 0);
  d.setDate(d.getDate() + Math.max(1, days));
  return d.getTime();
}

function isFiniteNumber(value: number): boolean {
  return typeof value === 'number' && isFinite(value);
}

function safeRetention(value: number): number {
  if (!isFiniteNumber(value)) {
    return 0.90;
  }
  return Math.min(0.95, Math.max(0.80, value));
}

function safeGrade(value: number): number {
  if (!isFiniteNumber(value)) {
    return 3;
  }
  return Math.round(Math.min(4, Math.max(1, value)));
}

function clamp(value: number, low: number, high: number): number {
  return Math.min(high, Math.max(low, value));
}

function safeState(value: string): string {
  if (value === 'learning' || value === 'review' || value === 'relearning') {
    return value;
  }
  return 'review';
}

function safeDays(value: number): number {
  if (!isFiniteNumber(value)) {
    return 1;
  }
  return roundFsrsDays(value);
}

function startOfDay(value: number): number {
  const date = new Date(value);
  date.setHours(0, 0, 0, 0);
  return date.getTime();
}

function elapsedDays(item: SchedulingItem, now: number): number {
  if (!isFiniteNumber(item.lastReviewedAt) || item.lastReviewedAt <= 0) {
    return 0;
  }
  return Math.max(0, Math.round((startOfDay(now) - startOfDay(item.lastReviewedAt)) / DAY_MS));
}

export function fsrsStateFromItem(item: SchedulingItem): FsrsState {
  const reviewCount = isFiniteNumber(item.reviewCount) ? item.reviewCount : 0;
  const storedState = isFiniteNumber(item.lastReviewedAt) ? item.lastReviewedAt : 0;
  if (reviewCount <= 0) {
    return {
      stability: 0,
      difficulty: 5,
      state: 'new',
      lapses: 0,
      scheduledDays: 0,
      lastReviewedAt: storedState
    };
  }
  const fallbackInterval = isFiniteNumber(item.currentIntervalDays) ? item.currentIntervalDays : 1;
  const stability = isFiniteNumber(item.fsrsStability)
    ? clamp(item.fsrsStability, 0.1, 36500)
    : clamp(roundFsrsDays(fallbackInterval), 0.1, 36500);
  const difficulty = isFiniteNumber(item.fsrsDifficulty)
    ? clamp(item.fsrsDifficulty, 1, 10)
    : 5;
  const scheduledDays = isFiniteNumber(item.fsrsScheduledDays)
    ? Math.max(1, item.fsrsScheduledDays)
    : Math.max(1, stability);
  const lapses = isFiniteNumber(item.fsrsLapses) ? Math.max(0, item.fsrsLapses) : 0;
  return {
    stability: stability,
    difficulty: difficulty,
    state: safeState(item.fsrsState),
    lapses: lapses,
    scheduledDays: scheduledDays,
    lastReviewedAt: storedState
  };
}

export function fixedIntervalFor(item: SchedulingItem, grade: number): number {
  const base = Math.max(1, Math.min(90, Math.round(item.fixedIntervalDays)));
  if (grade === 1) {
    return 1;
  }
  if (grade === 2) {
    return Math.max(1, Math.round(base / 2));
  }
  if (grade === 4) {
    return Math.max(base + 1, Math.round(base * 1.5));
  }
  return base;
}

export function scheduleFsrs(
  item: SchedulingItem,
  grade: number,
  now: number,
  retention: number
): FsrsScheduleResult {
  const safe = safeGrade(grade);
  if (item.scheduleMode === 'fixed') {
    const days = fixedIntervalFor(item, safe);
    return {
      nextAt: nextDueAt(now, days),
      nextIntervalDays: days,
      curveStage: isFiniteNumber(item.curveStage) ? item.curveStage : 0,
      rating: String(safe),
      stability: isFiniteNumber(item.fsrsStability) ? item.fsrsStability : 0,
      difficulty: isFiniteNumber(item.fsrsDifficulty) ? item.fsrsDifficulty : 5,
      state: isFiniteNumber(item.reviewCount) && item.reviewCount > 0 ? 'review' : 'new',
      lapses: isFiniteNumber(item.fsrsLapses) ? item.fsrsLapses : 0,
      scheduledDays: days
    };
  }
  const state = fsrsStateFromItem(item);
  const reviewed = review(state, safe, elapsedDays(item, now), safeRetention(retention), now);
  const days = safeDays(reviewed.scheduledDays);
  return {
    nextAt: nextDueAt(now, days),
    nextIntervalDays: days,
    curveStage: isFiniteNumber(item.curveStage) ? item.curveStage : 0,
    rating: String(safe),
    stability: isFiniteNumber(reviewed.stability) ? reviewed.stability : state.stability,
    difficulty: isFiniteNumber(reviewed.difficulty) ? reviewed.difficulty : state.difficulty,
    state: reviewed.state,
    lapses: reviewed.lapses,
    scheduledDays: days
  };
}

export function previewForGrades(item: SchedulingItem, now: number, retention: number): number[] {
  if (item.scheduleMode === 'fixed') {
    const result: number[] = [];
    for (let grade = 1; grade <= 4; grade++) {
      result.push(fixedIntervalFor(item, grade));
    }
    return result;
  }
  const state = fsrsStateFromItem(item);
  const previews: FsrsPreview[] = preview(state, elapsedDays(item, now), safeRetention(retention), now);
  const intervals: number[] = [];
  for (let i = 0; i < previews.length; i++) {
    intervals.push(safeDays(previews[i].intervalDays));
  }
  return intervals;
}

export function postponeToTomorrow(item: SchedulingItem, now: number): SchedulingItem {
  return {
    id: item.id,
    subjectId: item.subjectId,
    title: item.title,
    createdAt: item.createdAt,
    scheduleMode: item.scheduleMode,
    curveStage: item.curveStage,
    fixedIntervalDays: item.fixedIntervalDays,
    currentIntervalDays: item.currentIntervalDays,
    nextReviewAt: nextDueAt(now, 1),
    lastReviewedAt: item.lastReviewedAt,
    reviewCount: item.reviewCount,
    status: item.status,
    fsrsStability: item.fsrsStability,
    fsrsDifficulty: item.fsrsDifficulty,
    fsrsState: item.fsrsState,
    fsrsScheduledDays: item.fsrsScheduledDays,
    fsrsLapses: item.fsrsLapses,
    fsrsVersion: item.fsrsVersion
  };
}
