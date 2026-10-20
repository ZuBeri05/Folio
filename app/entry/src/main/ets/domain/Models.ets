export interface Subject {
  id: string;
  name: string;
  color: string;
}

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
    { id: 'math', name: '数学', color: '#FF6542' },
    { id: 'english', name: '英语', color: '#E0A92E' },
    { id: 'physics', name: '物理', color: '#7E9FB5' },
    { id: 'chinese', name: '语文', color: '#D98F87' }
  ];
  return {
    subjects: subjects,
    items: [],
    logs: [],
    settings: {
      reminderEnabled: true,
      reminderTime: '20:00',
      subjectTimes: []
    }
  };
}
