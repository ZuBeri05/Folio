export function roundFsrsDays(raw: number): number {
  return Math.max(1, Math.round(raw));
}

export function nextDueAt(now: number, days: number): number {
  const d = new Date(now);
  d.setHours(0, 0, 0, 0);
  d.setDate(d.getDate() + Math.max(1, days));
  return d.getTime();
}
