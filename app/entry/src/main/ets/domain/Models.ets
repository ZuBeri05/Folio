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
  '#7A8B99'
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
}

export interface ReviewLog {
  id: string;
  itemId: string;
  reviewedAt: number;
  rating: string;
  previousIntervalDays: number;
  nextIntervalDays: number;
  nextReviewAt: number;
}

export interface SubjectTime {
  subjectId: string;
  time: string;
}

export interface Settings {
  reminderEnabled: boolean;
  reminderTime: string;
  subjectTimes: SubjectTime[];
  themeIndex: number;
}

export interface AppData {
  subjects: Subject[];
  items: StudyItem[];
  logs: ReviewLog[];
  settings: Settings;
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
    status: 'active'
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
    subjects: subjects,
    items: [],
    logs: [],
    settings: {
      reminderEnabled: true,
      reminderTime: '20:00',
      subjectTimes: [],
      themeIndex: 0
    }
  };
}
