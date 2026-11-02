export interface Subject {
  id: string;
  name: string;
  color: string;
}

export const SUBJECT_COLORS: string[] = [
  '#E8A21A',
  '#4A90D9',
  '#D95F3F',
  '#8E7CC3',
  '#5AA469',
  '#E07A5F',
  '#7A8B99',
  '#3FA7A3',
  '#C77DBB',
  '#6C7BD9',
  '#D4A72C',
  '#7FA650',
  '#C46A8A',
  '#5B8CBF',
  '#9A7B4F',
  '#8C9A5B'
];

export interface StudyItem {
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

export interface ReviewLog {
  id: string;
  itemId: string;
  reviewedAt: number;
  rating: string;
  previousIntervalDays: number;
  nextIntervalDays: number;
  nextReviewAt: number;
  grade: number;
  stabilityBefore: number;
  stabilityAfter: number;
  difficultyBefore: number;
  difficultyAfter: number;
  elapsedDays: number;
  scheduledDays: number;
}

export interface SubjectTime {
  subjectId: string;
  time: string;
}

/** 一段专注（番茄钟） */
export interface FocusSession {
  id: string;
  startedAt: number;
  endedAt: number;
  plannedMinutes: number;
  minutes: number;
  itemCount: number;
  remembered: number;
  completed: boolean;
  /** 只有 activeFocus 会填：这一段是不是休息 */
  isBreak?: boolean;
  /** 只有 activeFocus 会填：循环里的第几轮 */
  round?: number;
  /** 只有 activeFocus 会填：这一轮循环的起点 */
  cycleStart?: number;
}

export interface Settings {
  reminderEnabled: boolean;
  reminderTime: string;
  subjectTimes: SubjectTime[];
  themeIndex: number;
  language: string;
  targetRetention: number;
  /** 最长间隔（天），0 表示不限 */
  maxIntervalDays: number;
  /** 上次选的专注时长（分钟） */
  focusMinutes: number;
}

export interface AppData {
  schemaVersion: number;
  subjects: Subject[];
  items: StudyItem[];
  logs: ReviewLog[];
  settings: Settings;
  focusSessions: FocusSession[];
  /** 正在跑的专注，App 被关掉后靠它恢复 */
  activeFocus: FocusSession | null;
}

export interface ReviewResult {
  nextAt: number;
  nextIntervalDays: number;
  curveStage: number;
  rating: string;
}

export interface DayCount {
  date: number;
  count: number;
}

export function newId(): string {
  return Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
}

export function emptyItem(): StudyItem {
  return {
    id: '',
    subjectId: '',
    title: '',
    createdAt: 0,
    scheduleMode: 'curve',
    curveStage: 0,
    fixedIntervalDays: 3,
    currentIntervalDays: 1,
    nextReviewAt: 0,
    lastReviewedAt: 0,
    reviewCount: 0,
    status: 'active',
    fsrsStability: 0,
    fsrsDifficulty: 5,
    fsrsState: 'new',
    fsrsScheduledDays: 0,
    fsrsLapses: 0,
    fsrsVersion: 6
  };
}

export function createDefaultData(): AppData {
  const subjects: Subject[] = [
    { id: 'math', name: '数学', color: '#E8A21A' },
    { id: 'english', name: '英语', color: '#4A90D9' },
    { id: 'politics', name: '政治', color: '#D95F3F' },
    { id: 'major', name: '专业课', color: '#8E7CC3' }
  ];
  return {
    schemaVersion: 2,
    subjects: subjects,
    items: [],
    logs: [],
    settings: {
      reminderEnabled: true,
      reminderTime: '20:00',
      subjectTimes: [],
      themeIndex: 0,
      language: 'zh',
      targetRetention: 0.9,
      maxIntervalDays: 180,
      focusMinutes: 25
    },
    focusSessions: [],
    activeFocus: null
  };
}
