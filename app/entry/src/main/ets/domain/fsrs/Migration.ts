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

function isFiniteNumber(value: number): boolean {
  return typeof value === 'number' && isFinite(value);
}

function isValidTargetRetention(value: number): boolean {
  return isFiniteNumber(value) && value >= 0.80 && value <= 0.95;
}

export function isValidFsrsItem(item: LegacyStudyItem): boolean {
  const candidate = item as MigratedStudyItem;
  if (candidate.fsrsVersion !== 6) {
    return false;
  }
  if (!isFiniteNumber(candidate.fsrsStability) || !isFiniteNumber(candidate.fsrsDifficulty)) {
    return false;
  }
  if (!isFiniteNumber(candidate.fsrsScheduledDays) || !isFiniteNumber(candidate.fsrsLapses)) {
    return false;
  }
  if (typeof candidate.fsrsState !== 'string') {
    return false;
  }
  if (candidate.reviewCount > 0 && (candidate.fsrsState === 'new' || !(candidate.fsrsStability > 0))) {
    return false;
  }
  return candidate.fsrsStability >= 0 && candidate.fsrsStability <= 36500 &&
    candidate.fsrsDifficulty >= 1 && candidate.fsrsDifficulty <= 10 &&
    candidate.fsrsScheduledDays >= 0 && candidate.fsrsLapses >= 0;
}

export function needsMigration(data: LegacyAppData): boolean {
  const candidate = data as MigratedAppData;
  if (candidate.schemaVersion !== 2) {
    return true;
  }
  if (!Array.isArray(candidate.items) ||
      candidate.items.some((item: MigratedStudyItem) =>
        !isValidFsrsItem(item) || item.scheduleMode !== 'fsrs')) {
    return true;
  }
  if (!Array.isArray(candidate.logs) ||
      candidate.logs.some((log: MigratedReviewLog) => !isFiniteNumber(log.grade))) {
    return true;
  }
  if (!candidate.settings || !isValidTargetRetention(candidate.settings.targetRetention)) {
    return true;
  }
  return false;
}

function copyWithFsrsMode(item: LegacyStudyItem): MigratedStudyItem {
  const candidate = item as MigratedStudyItem;
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
    fsrsStability: candidate.fsrsStability,
    fsrsDifficulty: candidate.fsrsDifficulty,
    fsrsState: candidate.fsrsState,
    fsrsScheduledDays: candidate.fsrsScheduledDays,
    fsrsLapses: candidate.fsrsLapses,
    fsrsVersion: candidate.fsrsVersion
  };
}

export function migrateItem(item: LegacyStudyItem): MigratedStudyItem {
  if (isValidFsrsItem(item)) {
    if (item.scheduleMode === 'fsrs') {
      return item as MigratedStudyItem;
    }
    return copyWithFsrsMode(item);
  }
  const reviewed = item.reviewCount > 0;
  const currentInterval = isFiniteNumber(item.currentIntervalDays) ? item.currentIntervalDays : 0;
  const migratedInterval = reviewed ? Math.max(1, currentInterval) : 0;
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
    fsrsStability: migratedInterval,
    fsrsDifficulty: 5,
    fsrsState: reviewed ? 'review' : 'new',
    fsrsScheduledDays: migratedInterval,
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
  const candidate = log as MigratedReviewLog;
  if (isFiniteNumber(candidate.grade)) {
    return candidate;
  }
  const previousInterval = isFiniteNumber(log.previousIntervalDays) ? log.previousIntervalDays : 0;
  const nextInterval = isFiniteNumber(log.nextIntervalDays) ? log.nextIntervalDays : 0;
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
    elapsedDays: Math.max(0, Math.round(previousInterval)),
    scheduledDays: Math.max(0, Math.round(nextInterval))
  };
}

function migrateSettings(settings: LegacySettings): MigratedSettings {
  const candidate = settings as MigratedSettings;
  return {
    reminderEnabled: settings.reminderEnabled,
    reminderTime: settings.reminderTime,
    subjectTimes: settings.subjectTimes,
    themeIndex: settings.themeIndex,
    language: settings.language,
    curveDays: settings.curveDays,
    targetRetention: isValidTargetRetention(candidate.targetRetention) ? candidate.targetRetention : 0.90
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
