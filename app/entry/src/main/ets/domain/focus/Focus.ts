/**
 * 专注计时的纯逻辑。这里不碰 UI、不碰存储，方便直接用 vitest 测。
 */

export interface FocusLogLike {
  reviewedAt: number;
  grade: number;
}

export interface FocusSessionLike {
  startedAt: number;
  endedAt: number;
  minutes: number;
  itemCount?: number;
  remembered?: number;
}

/** 一轮循环的累计 */
export interface CycleSummary {
  segments: number;
  minutes: number;
  itemCount: number;
  remembered: number;
}

export interface FocusSummary {
  /** 实际分钟数；不足 1 分钟记 0，调用方据此决定要不要落库 */
  minutes: number;
  itemCount: number;
  remembered: number;
}

const DAY_MS: number = 86400000;

/** 距离结束还剩多少毫秒，过点返回 0 */
export function remainingMs(endAt: number, now: number): number {
  const left = endAt - now;
  return left > 0 ? left : 0;
}

/** 24:35 这种显示 */
export function formatClock(ms: number): string {
  const totalSeconds = Math.max(0, Math.ceil(ms / 1000));
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  const mm = minutes < 10 ? '0' + minutes : '' + minutes;
  const ss = seconds < 10 ? '0' + seconds : '' + seconds;
  return mm + ':' + ss;
}

export function startOfDay(ts: number): number {
  const date = new Date(ts);
  date.setHours(0, 0, 0, 0);
  return date.getTime();
}

/** 结算一段专注：这段时间里复习了几条、其中几条记得 */
export function summarize(startedAt: number, endedAt: number, logs: FocusLogLike[]): FocusSummary {
  let itemCount = 0;
  let remembered = 0;
  for (let i = 0; i < logs.length; i++) {
    const at = logs[i].reviewedAt;
    if (at >= startedAt && at <= endedAt) {
      itemCount = itemCount + 1;
      if (logs[i].grade >= 3) {
        remembered = remembered + 1;
      }
    }
  }
  const rawMinutes = (endedAt - startedAt) / 60000;
  const minutes = rawMinutes < 1 ? 0 : Math.max(1, Math.round(rawMinutes));
  return { minutes: minutes, itemCount: itemCount, remembered: remembered };
}

export function todayMinutes(sessions: FocusSessionLike[], now: number): number {
  const from = startOfDay(now);
  const to = from + DAY_MS;
  let total = 0;
  for (let i = 0; i < sessions.length; i++) {
    const at = sessions[i].startedAt;
    if (at >= from && at < to) {
      total = total + sessions[i].minutes;
    }
  }
  return total;
}

export function todayCount(sessions: FocusSessionLike[], now: number): number {
  const from = startOfDay(now);
  const to = from + DAY_MS;
  let count = 0;
  for (let i = 0; i < sessions.length; i++) {
    const at = sessions[i].startedAt;
    if (at >= from && at < to) {
      count = count + 1;
    }
  }
  return count;
}

/** 本周（周一开头）每天多少分钟，返回 7 个桶 */
export function weekBuckets(sessions: FocusSessionLike[], now: number): number[] {
  const buckets: number[] = [0, 0, 0, 0, 0, 0, 0];
  const today = startOfDay(now);
  const weekday = (new Date(now).getDay() + 6) % 7;
  const monday = today - weekday * DAY_MS;
  for (let i = 0; i < sessions.length; i++) {
    const day = startOfDay(sessions[i].startedAt);
    const index = Math.round((day - monday) / DAY_MS);
    if (index >= 0 && index < 7) {
      buckets[index] = buckets[index] + sessions[i].minutes;
    }
  }
  return buckets;
}

/** 分钟拆成 [小时, 分钟]，给「1 小时 15 分」这种文案用 */
export function durationParts(minutes: number): number[] {
  const safe = minutes > 0 ? minutes : 0;
  return [Math.floor(safe / 60), safe % 60];
}

/** 第几轮之后休息多久：每 4 轮一次长休息 */
export function breakMinutesFor(round: number): number {
  const safe = round > 0 ? round : 1;
  return safe % 4 === 0 ? 15 : 5;
}

/** 从 since 开始，累计这一段循环的专注 */
export function cycleSummary(sessions: FocusSessionLike[], since: number): CycleSummary {
  let segments = 0;
  let minutes = 0;
  let itemCount = 0;
  let remembered = 0;
  for (let i = 0; i < sessions.length; i++) {
    const session = sessions[i];
    if (session.startedAt < since) {
      continue;
    }
    segments = segments + 1;
    minutes = minutes + session.minutes;
    itemCount = itemCount + (session.itemCount !== undefined ? session.itemCount : 0);
    remembered = remembered + (session.remembered !== undefined ? session.remembered : 0);
  }
  return { segments: segments, minutes: minutes, itemCount: itemCount, remembered: remembered };
}
