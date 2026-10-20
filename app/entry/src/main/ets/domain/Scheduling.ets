import { StudyItem, ReviewResult } from './Models';

export const DAY_MS: number = 86400000;
export const CURVE: number[] = [1, 2, 4, 7, 15, 30, 60];

export function startOfDay(value: Date): Date {
  const date = new Date(value.getTime());
  date.setHours(0, 0, 0, 0);
  return date;
}

export function addDays(value: Date, days: number): Date {
  const date = new Date(value.getTime());
  date.setDate(date.getDate() + days);
  return date;
}

export function dayKey(value: Date): number {
  return startOfDay(value).getTime();
}

export function daysBetween(from: number, to: Date): number {
  const a = startOfDay(new Date(from)).getTime();
  const b = startOfDay(to).getTime();
  return Math.max(0, Math.round((b - a) / DAY_MS));
}

export function firstReviewAt(mode: string, fixedDays: number, now: Date): number {
  const days = mode === 'fixed' ? Math.max(1, fixedDays) : 1;
  return addDays(startOfDay(now), days).getTime();
}

export function scheduleNext(item: StudyItem, rating: string, now: Date): ReviewResult {
  const previous = Math.max(1, item.currentIntervalDays);
  let nextInterval = previous;
  let nextStage = item.curveStage;

  if (item.scheduleMode === 'fixed') {
    const fixed = Math.max(1, item.fixedIntervalDays);
    if (rating === 'forgot') {
      nextInterval = 1;
    } else if (rating === 'fuzzy') {
      nextInterval = Math.max(1, Math.round(fixed / 2));
    } else {
      nextInterval = fixed;
    }
  } else {
    if (rating === 'forgot') {
      nextStage = Math.max(0, item.curveStage - 2);
      nextInterval = 1;
    } else if (rating === 'fuzzy') {
      nextStage = item.curveStage;
      nextInterval = Math.max(1, Math.round(previous * 0.75));
    } else {
      nextStage = Math.min(CURVE.length - 1, item.curveStage + 1);
      nextInterval = CURVE[nextStage];
    }
  }

  return {
    nextAt: addDays(startOfDay(now), nextInterval).getTime(),
    nextIntervalDays: nextInterval,
    curveStage: nextStage,
    rating: rating
  };
}

export function formatDate(ts: number): string {
  const d = new Date(ts);
  return (d.getMonth() + 1) + ' 月 ' + d.getDate() + ' 日';
}

export function formatShort(ts: number): string {
  const d = new Date(ts);
  const m = d.getMonth() + 1;
  const day = d.getDate();
  return (m < 10 ? '0' + m : '' + m) + '.' + (day < 10 ? '0' + day : '' + day);
}

export function formatFull(ts: number): string {
  const d = new Date(ts);
  return d.getFullYear() + ' 年 ' + (d.getMonth() + 1) + ' 月 ' + d.getDate() + ' 日';
}

export function weekdayCN(ts: number): string {
  const names: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
  return names[new Date(ts).getDay()];
}

export function ratingLabel(rating: string): string {
  if (rating === 'forgot') {
    return '忘了';
  }
  if (rating === 'fuzzy') {
    return '模糊';
  }
  return '记得';
}
