import { postponeToTomorrow, previewForGrades, scheduleFsrs } from './fsrs/Scheduling.ts';

export { postponeToTomorrow, previewForGrades, scheduleFsrs };

const DAY_MS: number = 86400000;

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

export function daysBetween(from: number, to: Date): number {
  const a = startOfDay(new Date(from)).getTime();
  const b = startOfDay(to).getTime();
  return Math.max(0, Math.round((b - a) / DAY_MS));
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
