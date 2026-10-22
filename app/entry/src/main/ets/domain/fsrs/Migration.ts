export interface LegacyStudyItem {
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
}

export interface MigratedStudyItem extends LegacyStudyItem {
  fsrsStability: number;
  fsrsDifficulty: number;
  fsrsState: string;
  fsrsScheduledDays: number;
  fsrsLapses: number;
  fsrsVersion: number;
}

export interface LegacyReviewLog {
  id: string;
  itemId: string;
  reviewedAt: number;
  rating: string;
  previousIntervalDays: number;
  nextIntervalDays: number;
  nextReviewAt: number;
}

export interface MigratedReviewLog extends LegacyReviewLog {
  grade: number;
  stabilityBefore: number;
  stabilityAfter: number;
  difficultyBefore: number;
  difficultyAfter: number;
  elapsedDays: number;
  scheduledDays: number;
}

export interface LegacySubjectTime {
  subjectId: string;
  time: string;
}

export interface LegacySubject {
  id: string;
  name: string;
  color: string;
}

export interface LegacySettings {
  reminderEnabled: boolean;
  reminderTime: string;
  subjectTimes: LegacySubjectTime[];
  themeIndex: number;
  language: string;
  curveDays: number[];
}

export interface MigratedSettings extends LegacySettings {
  targetRetention: number;
}

export interface LegacyAppData {
  subjects: LegacySubject[];
  items: LegacyStudyItem[];
  logs: LegacyReviewLog[];
  settings: LegacySettings;
}

export interface MigratedAppData {
  schemaVersion: number;
  subjects: LegacySubject[];
  items: MigratedStudyItem[];
  logs: MigratedReviewLog[];
  settings: MigratedSettings;
}

export function migrateItem(item: LegacyStudyItem): MigratedStudyItem {
  const reviewed = item.reviewCount > 0;
  return {
    id: item.id,
    subjectId: item.subjectId,
    title: item.title,
    createdAt: item.createdAt,
    scheduleMode: 'fsrs',
    curveStage: item.curveStage,
    fixedIntervalDays: item.fixedIntervalDays,
    currentIntervalDays: item.currentIntervalDays,
    nextReviewAt: item.nextReviewAt,
    lastReviewedAt: item.lastReviewedAt,
    reviewCount: item.reviewCount,
    status: item.status,
    fsrsStability: reviewed ? Math.max(1, item.currentIntervalDays) : 0,
    fsrsDifficulty: 5,
    fsrsState: reviewed ? 'review' : 'new',
    fsrsScheduledDays: item.currentIntervalDays,
    fsrsLapses: 0,
    fsrsVersion: 6
  };
}

function migratedGrade(rating: string): number {
  if (rating === 'forgot') {
    return 1;
  }
  if (rating === 'fuzzy') {
    return 2;
  }
  return 3;
}

function migrateLog(log: LegacyReviewLog): MigratedReviewLog {
  return {
    id: log.id,
    itemId: log.itemId,
    reviewedAt: log.reviewedAt,
    rating: log.rating,
    previousIntervalDays: log.previousIntervalDays,
    nextIntervalDays: log.nextIntervalDays,
    nextReviewAt: log.nextReviewAt,
    grade: migratedGrade(log.rating),
    stabilityBefore: 0,
    stabilityAfter: 0,
    difficultyBefore: 0,
    difficultyAfter: 0,
    elapsedDays: Math.max(0, Math.round(log.previousIntervalDays)),
    scheduledDays: Math.max(0, Math.round(log.nextIntervalDays))
  };
}

function migrateSettings(settings: LegacySettings): MigratedSettings {
  return {
    reminderEnabled: settings.reminderEnabled,
    reminderTime: settings.reminderTime,
    subjectTimes: settings.subjectTimes,
    themeIndex: settings.themeIndex,
    language: settings.language,
    curveDays: settings.curveDays,
    targetRetention: 0.9
  };
}

export function migrateAppData(data: LegacyAppData): MigratedAppData {
  const items: MigratedStudyItem[] = data.items.map((item: LegacyStudyItem) => migrateItem(item));
  const logs: MigratedReviewLog[] = data.logs.map((log: LegacyReviewLog) => migrateLog(log));
  return {
    schemaVersion: 2,
    subjects: data.subjects,
    items: items,
    logs: logs,
    settings: migrateSettings(data.settings)
  };
}
