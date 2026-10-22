# FSRS Scheduler Replacement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Replace Folio's fixed/classic curve scheduler with FSRS-6, four-grade review, a 80–95% retention slider, and lossless migration of existing records.

**Architecture:** A pure TypeScript FSRS core in domain/fsrs/Fsrs.ts is imported by the ArkTS scheduling adapter and UI. StudyItem stores S/D/state, ReviewLog stores the four-grade history, and Store migrates v1 data once. UI is a two-step flow: postpone/complete, then four grades with live interval previews.

**Tech Stack:** HarmonyOS 7 / API 26, ArkTS/ArkUI V1, preferences storage, Node 22 + Vitest for the pure TypeScript core and migration tests.

## Global Constraints

- FSRS version: 6; default 21 weights; no per-user parameter training.
- Four grades only: 1=Again/忘记, 2=Hard/困难, 3=Good/良好, 4=Easy/简单.
- Day granularity only; no minute-level learning steps.
- Minimum interval: 1 day; never schedule today.
- Target retention: 0.80–0.95, step 0.01, default 0.90.
- Postpone to tomorrow must not change S/D, reviewCount, or write a ReviewLog.
- Only due items can enter review in v1.
- Existing records and nextReviewAt must survive migration.
- Do not modify the currently submitted 1.0.0 package; ship this as 1.1.0 with an incremented versionCode.
- All tests must run without a device; device builds are verified separately with devecocli.

---

## File Structure

Create:

- app/entry/src/main/ets/domain/fsrs/Fsrs.ts — pure FSRS-6 math and previews
- app/entry/src/main/ets/domain/fsrs/Migration.ts — pure v1 to v2 item/log migration
- tests/package.json — Vitest test harness
- tests/fsrs.test.ts — core FSRS tests
- tests/migration.test.ts — migration tests

Modify:

- app/entry/src/main/ets/domain/Models.ets — FSRS fields, targetRetention, schemaVersion
- app/entry/src/main/ets/data/Store.ets — load and run migration
- app/entry/src/main/ets/domain/Scheduling.ets — FSRS adapter, postpone helper
- app/entry/src/main/ets/pages/Index.ets — two-step review UI, rating page, settings slider, remove curve UI
- app/entry/src/main/ets/services/I18n.ets — four grade labels and new strings
- app/AppScope/app.json5 — versionName 1.1.0, versionCode increment

Do not modify the submitted 1.0.0 artifacts in dist.

---

### Task 1: Set up the pure test harness and FSRS core types

**Files:**
- Create: tests/package.json
- Create: tests/fsrs.test.ts
- Create: app/entry/src/main/ets/domain/fsrs/Fsrs.ts

**Interfaces:**
- Produces: FsrsState, FsrsPreview, initialState(grade, now), review(state, grade, elapsedDays, retention, now), preview(state, elapsedDays, retention, now), retrievability(state, elapsedDays)

- [ ] **Step 1: Create the test harness**

tests/package.json:

~~~json
{
  "private": true,
  "type": "module",
  "scripts": {
    "test": "vitest run"
  },
  "devDependencies": {
    "vitest": "^2.1.9"
  }
}
~~~

Run:

~~~powershell
cd jiesheng/tests
npm install
~~~

Expected: node_modules and package-lock.json are created.

- [ ] **Step 2: Write the first failing test**

tests/fsrs.test.ts:

~~~ts
import { describe, expect, it } from 'vitest';
import {
  initialState,
  preview,
  retrievability,
  review
} from '../app/entry/src/main/ets/domain/fsrs/Fsrs.ts';

describe('FSRS initial state', () => {
  it('gives higher initial stability for easier first grades', () => {
    const again = initialState(1, 1000);
    const hard = initialState(2, 1000);
    const good = initialState(3, 1000);
    const easy = initialState(4, 1000);
    expect(again.stability).toBeGreaterThan(0);
    expect(hard.stability).toBeGreaterThan(again.stability);
    expect(good.stability).toBeGreaterThan(hard.stability);
    expect(easy.stability).toBeGreaterThan(good.stability);
    expect(hard.difficulty).toBeCloseTo(5.1122, 3);
    expect(good.difficulty).toBeCloseTo(2.1181, 3);
    expect(easy.difficulty).toBe(1);
  });

  it('previews four positive intervals and keeps the retention ordering', () => {
    const state = initialState(3, 1000);
    const p80 = preview(state, 0, 0.80, 1000);
    const p90 = preview(state, 0, 0.90, 1000);
    const p95 = preview(state, 0, 0.95, 1000);
    expect(p90).toHaveLength(4);
    expect(p90.every((p) => p.intervalDays >= 1)).toBe(true);
    expect(p95[2].intervalDays).toBeLessThanOrEqual(p90[2].intervalDays);
    expect(p80[2].intervalDays).toBeGreaterThanOrEqual(p90[2].intervalDays);
  });
});

describe('FSRS review transitions', () => {
  it('increments lapses and uses relearning after Again', () => {
    const state = initialState(3, 1000);
    const next = review(state, 1, 3, 0.90, 2000);
    expect(next.state).toBe('relearning');
    expect(next.lapses).toBe(1);
  });

  it('uses the FSRS-6 new-card branch for the first rating', () => {
    const fresh: FsrsState = { stability: 0, difficulty: 5, state: 'new', lapses: 0, scheduledDays: 0, lastReviewedAt: 0 };
    const first = review(fresh, 3, 0, 0.90, 1000);
    expect(first.state).toBe('review');
    expect(first.stability).toBeCloseTo(2.3065, 3);
    expect(first.scheduledDays).toBeGreaterThanOrEqual(1);
  });

  it('does not decrease stability after a successful review', () => {
    const state = initialState(3, 1000);
    const next = review(state, 3, 3, 0.90, 2000);
    expect(next.stability).toBeGreaterThanOrEqual(state.stability);
    expect(next.state).toBe('review');
  });

  it('decays retrievability as elapsed days grow', () => {
    const state = initialState(3, 1000);
    expect(retrievability(state, 0)).toBeGreaterThan(retrievability(state, 10));
  });
});
~~~

- [ ] **Step 3: Run the test and verify it fails**

Run:

~~~powershell
cd jiesheng/tests
npx vitest run
~~~

Expected: FAIL because Fsrs.ts does not exist.

- [ ] **Step 4: Implement Fsrs.ts**

app/entry/src/main/ets/domain/fsrs/Fsrs.ts:

~~~ts
export const W: number[] = [
  0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334,
  3.0194, 0.001, 1.8722, 0.1666, 0.796, 1.4835,
  0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425,
  0.0912, 0.0658, 0.1542
];

const DECAY: number = -W[20];
const FACTOR: number = Math.pow(0.9, 1 / DECAY) - 1;

export interface FsrsState {
  stability: number;
  difficulty: number;
  state: string;
  lapses: number;
  scheduledDays: number;
  lastReviewedAt: number;
}

export interface FsrsPreview {
  grade: number;
  intervalDays: number;
}

function clamp(value: number, low: number, high: number): number {
  return Math.min(high, Math.max(low, value));
}

function clampGrade(grade: number): number {
  return Math.round(clamp(grade, 1, 4));
}

function clampState(state: FsrsState): FsrsState {
  return {
    stability: clamp(state.stability, 0.1, 36500),
    difficulty: clamp(state.difficulty, 1, 10),
    state: ['new', 'learning', 'review', 'relearning'].includes(state.state) ? state.state : 'review',
    lapses: Math.max(0, Math.round(state.lapses)),
    scheduledDays: Math.max(0, Math.round(state.scheduledDays)),
    lastReviewedAt: state.lastReviewedAt
  };
}

export function retrievability(state: FsrsState, elapsedDays: number): number {
  const elapsed = Math.max(0, elapsedDays);
  return Math.pow(1 + FACTOR * elapsed / Math.max(0.1, state.stability), DECAY);
}

export function initialState(grade: number, now: number): FsrsState {
  const g = clampGrade(grade);
  return {
    stability: W[g - 1],
    difficulty: clamp(W[4] - Math.exp(W[5] * (g - 1)) + 1, 1, 10),
    state: g === 1 ? 'learning' : 'review',
    lapses: 0,
    scheduledDays: 0,
    lastReviewedAt: now
  };
}

function nextDifficulty(difficulty: number, grade: number): number {
  const initialEasy = clamp(W[4] - Math.exp(W[5] * 3) + 1, 1, 10);
  const next = W[7] * initialEasy + (1 - W[7]) * (difficulty - W[6] * (grade - 3));
  return clamp(next, 1, 10);
}

function nextStability(state: FsrsState, grade: number, elapsedDays: number): number {
  const r = retrievability(state, elapsedDays);
  const d = state.difficulty;
  const s = state.stability;
  if (grade === 1) {
    return W[11] * Math.pow(d, -W[12]) * (Math.pow(s + 1, W[13]) - 1) * Math.exp(W[14] * (1 - r));
  }
  const hardFactor = grade === 2 ? W[15] : 1;
  const easyFactor = grade === 4 ? W[16] : 1;
  const growth = Math.exp(W[8]) * (11 - d) * Math.pow(s, -W[9]) *
    (Math.exp(W[10] * (1 - r)) - 1) * hardFactor * easyFactor + 1;
  return s * growth;
}

function intervalFor(stability: number, retention: number): number {
  const raw = stability / FACTOR * (Math.pow(retention, 1 / DECAY) - 1);
  return Math.max(1, Math.round(raw));
}

export function review(
  state: FsrsState,
  grade: number,
  elapsedDays: number,
  retention: number,
  now: number
): FsrsState {
  const g = clampGrade(grade);
  const safeRetention = clamp(retention, 0.80, 0.95);
  const base = state.state === 'new' ? initialState(g, now) : clampState(state);
  if (state.state === 'new') {
    const interval = intervalFor(base.stability, safeRetention);
    return {
      stability: base.stability,
      difficulty: base.difficulty,
      state: base.state,
      lapses: base.lapses,
      scheduledDays: interval,
      lastReviewedAt: now
    };
  }
  const stability = clamp(nextStability(base, g, elapsedDays), 0.1, 36500);
  const difficulty = nextDifficulty(base.difficulty, g);
  const interval = intervalFor(stability, safeRetention);
  return {
    stability,
    difficulty,
    state: g === 1 ? 'relearning' : 'review',
    lapses: base.lapses + (g === 1 ? 1 : 0),
    scheduledDays: interval,
    lastReviewedAt: now
  };
}

export function preview(
  state: FsrsState,
  elapsedDays: number,
  retention: number,
  now: number
): FsrsPreview[] {
  const result: FsrsPreview[] = [];
  for (let grade = 1; grade <= 4; grade++) {
    result.push({ grade, intervalDays: review(state, grade, elapsedDays, retention, now).scheduledDays });
  }
  return result;
}
~~~

- [ ] **Step 5: Run tests and verify they pass**

Run:

~~~powershell
cd jiesheng/tests
npx vitest run
~~~

Expected: PASS.

- [ ] **Step 6: Commit**

~~~powershell
git add app/entry/src/main/ets/domain/fsrs/Fsrs.ts tests/package.json tests/package-lock.json tests/fsrs.test.ts
git commit -m "feat: add pure FSRS-6 core and tests"
~~~

---

### Task 2: Add day rounding and the scheduling adapter

**Files:**
- Modify: app/entry/src/main/ets/domain/Scheduling.ets
- Create: tests/scheduling.test.ts

**Interfaces:**
- Consumes: FsrsState (only for a compile gate)
- Produces: roundFsrsDays(raw), nextDueAt(now, days), and a compile-only fsrsCoreReady(now)
- Task 5 produces scheduleFsrs, postponeToTomorrow, and previewForGrades; Task 2 does not wire scheduling yet.

- [ ] **Step 1: Write failing tests**

tests/scheduling.test.ts:

~~~ts
import { describe, expect, it } from 'vitest';
import { initialState } from '../app/entry/src/main/ets/domain/fsrs/Fsrs.ts';
import { nextDueAt, roundFsrsDays } from '../app/entry/src/main/ets/domain/fsrs/Scheduling.ts';

describe('FSRS day scheduling', () => {
  it('never schedules today', () => {
    expect(roundFsrsDays(0.2)).toBe(1);
    expect(roundFsrsDays(0.8)).toBe(1);
  });

  it('rounds to whole days', () => {
    expect(roundFsrsDays(2.4)).toBe(2);
    expect(roundFsrsDays(2.6)).toBe(3);
  });

  it('moves the due date to the next local day', () => {
    const now = new Date(2026, 9, 22, 22, 30).getTime();
    const due = nextDueAt(now, 2);
    const d = new Date(due);
    expect(d.getDate()).toBe(24);
    expect(d.getHours()).toBe(0);
  });
});
~~~

- [ ] **Step 2: Run and verify failure**

~~~powershell
cd jiesheng/tests
npx vitest run scheduling.test.ts
~~~

Expected: FAIL because Scheduling.ts does not exist.

- [ ] **Step 3: Extract pure scheduling helpers**

Create app/entry/src/main/ets/domain/fsrs/Scheduling.ts with:

~~~ts
export function roundFsrsDays(raw: number): number {
  return Math.max(1, Math.round(raw));
}

export function nextDueAt(now: number, days: number): number {
  const d = new Date(now);
  d.setHours(0, 0, 0, 0);
  d.setDate(d.getDate() + Math.max(1, days));
  return d.getTime();
}
~~~

Keep Scheduling.ets as the ArkTS-facing adapter that imports these helpers. Task 2 only adds a compile gate; Task 5 adds the real FSRS review wiring.

- [ ] **Step 4: Run tests**

~~~powershell
cd jiesheng/tests
npx vitest run scheduling.test.ts
~~~

Expected: PASS.

- [ ] **Step 5: Commit**

~~~powershell
git add app/entry/src/main/ets/domain/fsrs/Scheduling.ts app/entry/src/main/ets/domain/Scheduling.ets tests/scheduling.test.ts
git commit -m "feat: add FSRS day scheduling adapter"
~~~

---

### Task 2 acceptance gates

**Files:**
- Create: tests/fixtures/fsrs6-golden.json
- Modify: tests/fsrs.test.ts
- Modify: app/entry/src/main/ets/domain/Scheduling.ets

- [ ] **Gate 1: Add a named-reference fixture with tolerance**

Create tests/fixtures/fsrs6-golden.json:

~~~json
{
  "source": "ts-fsrs 5.2.3 FSRS-6 reference; elapsed=previous scheduled interval; difficulty unrounded",
  "retention": 0.90,
  "intervals": [2, 11, 46, 163, 497]
}
~~~

Add a test that replays five Good reviews from initialState(3, 0), feeding the previous scheduled interval as elapsedDays, and asserts each interval is within ±1 day of the fixture. This pins the local rounding convention without pretending 497 is an official byte-exact vector.

- [ ] **Gate 2: Verify the ArkTS build can import Fsrs.ts**

In Scheduling.ets add:

~~~ts
import { initialState } from './fsrs/Fsrs';

export function fsrsCoreReady(now: number): boolean {
  return initialState(3, now).state === 'review';
}
~~~

This is a compile gate only; do not wire it into UI or behavior yet. Task 5 replaces it with the real adapter.

- [ ] **Gate 3: Run the ArkTS build**

~~~powershell
cd jiesheng/app
node ../.tools/node_modules/@deveco/deveco-cli/cli.js build --build-mode debug
~~~

Expected: BUILD SUCCESSFUL. If the .ts import or object syntax fails, fix it before proceeding.

- [ ] **Gate 4: Run all tests and commit the gate changes**

~~~powershell
cd jiesheng/tests
npx vitest run
~~~

Expected: all tests pass.

~~~powershell
git add tests/fixtures/fsrs6-golden.json tests/fsrs.test.ts app/entry/src/main/ets/domain/Scheduling.ets
git commit -m "test: pin FSRS-6 reference sequence and ArkTS import"
~~~

---

### Task 3: Add FSRS fields and pure migration

**Files:**
- Modify: app/entry/src/main/ets/domain/Models.ets
- Create: app/entry/src/main/ets/domain/fsrs/Migration.ts
- Create: tests/migration.test.ts

**Interfaces:**
- Consumes: StudyItem, ReviewLog shapes
- Produces: migrateItem(item), migrateAppData(data)

- [ ] **Step 1: Add fields to Models.ets**

Add to StudyItem:

~~~ts
fsrsStability: number;
fsrsDifficulty: number;
fsrsState: string;
fsrsScheduledDays: number;
fsrsLapses: number;
fsrsVersion: number;
~~~

Add to ReviewLog:

~~~ts
grade: number;
stabilityBefore: number;
stabilityAfter: number;
difficultyBefore: number;
difficultyAfter: number;
elapsedDays: number;
scheduledDays: number;
~~~

Add to Settings:

~~~ts
targetRetention: number;
~~~

Keep curveDays in Settings for now so existing UI compiles; remove it together with the curve UI in Task 8.

Add schemaVersion: number to AppData.

Set defaults in emptyItem and createDefaultData: fsrsStability=0, fsrsDifficulty=5, fsrsState='new', fsrsScheduledDays=0, fsrsLapses=0, fsrsVersion=6, targetRetention=0.9, schemaVersion=2. Keep curveDays defaults until Task 8.

- [ ] **Step 2: Update every StudyItem and ReviewLog literal**

Add the new fields with defaults in:

- Models.ets emptyItem
- Index.ets previousLog default
- Index.ets commitReview updated item and log
- Index.ets addItem
- Index.ets saveEdit updated item

The app must still compile after this step, before any UI changes.

- [ ] **Step 3: Write migration tests**

tests/migration.test.ts:

~~~ts
import { describe, expect, it } from 'vitest';
import { migrateItem } from '../app/entry/src/main/ets/domain/fsrs/Migration.ts';

const base = {
  id: 'a', subjectId: 'math', title: '导数', createdAt: 1,
  scheduleMode: 'curve', curveStage: 2, fixedIntervalDays: 3,
  currentIntervalDays: 4, nextReviewAt: 1000, lastReviewedAt: 500,
  reviewCount: 2, status: 'active'
};

describe('migration', () => {
  it('preserves reviewed item due date and estimates stability', () => {
    const result = migrateItem({ ...base, scheduleMode: 'curve' });
    expect(result.nextReviewAt).toBe(1000);
    expect(result.scheduleMode).toBe('fsrs');
    expect(result.fsrsState).toBe('review');
    expect(result.fsrsStability).toBeGreaterThanOrEqual(1);
    expect(result.fsrsDifficulty).toBe(5);
  });

  it('leaves unreviewed items as new', () => {
    const result = migrateItem({ ...base, reviewCount: 0, lastReviewedAt: 0 });
    expect(result.fsrsState).toBe('new');
    expect(result.fsrsStability).toBe(0);
  });
});
~~~

- [ ] **Step 4: Run and verify failure**

~~~powershell
cd jiesheng/tests
npx vitest run tests/migration.test.ts
~~~

Expected: FAIL because Migration.ts does not exist.

- [ ] **Step 5: Implement Migration.ts**

~~~ts
export function migrateItem(item: any): any {
  const reviewed = item.reviewCount > 0;
  return {
    ...item,
    scheduleMode: 'fsrs',
    fsrsStability: reviewed ? Math.max(1, item.currentIntervalDays) : 0,
    fsrsDifficulty: 5,
    fsrsState: reviewed ? 'review' : 'new',
    fsrsScheduledDays: item.currentIntervalDays,
    fsrsLapses: 0,
    fsrsVersion: 6
  };
}

export function migrateAppData(data: any): any {
  const items = data.items.map((item: any) => migrateItem(item));
  const logs = data.logs.map((log: any) => ({
    ...log,
    grade: log.rating === 'forgot' ? 1 : log.rating === 'fuzzy' ? 2 : 3,
    stabilityBefore: 0,
    stabilityAfter: 0,
    difficultyBefore: 0,
    difficultyAfter: 0,
    elapsedDays: Math.max(0, Math.round(log.previousIntervalDays)),
    scheduledDays: Math.max(0, Math.round(log.nextIntervalDays))
  }));
  return {
    ...data,
    schemaVersion: 2,
    items,
    logs,
    settings: { ...data.settings, targetRetention: 0.9 }
  };
}
~~~

- [ ] **Step 6: Run tests**

~~~powershell
cd jiesheng/tests
npx vitest run tests/migration.test.ts
~~~

Expected: PASS.

- [ ] **Step 7: Commit**

~~~powershell
git add app/entry/src/main/ets/domain/Models.ets app/entry/src/main/ets/domain/fsrs/Migration.ts app/entry/src/main/ets/pages/Index.ets tests/migration.test.ts
git commit -m "feat: add FSRS fields and v1 migration"
~~~

---

### Task 4: Run idempotent migration in Store.load

**Files:**
- Modify: app/entry/src/main/ets/data/Store.ets
- Modify: app/entry/src/main/ets/domain/fsrs/Migration.ts
- Modify: tests/migration.test.ts

**Interfaces:**
- Produces: needsMigration(data), migrateAppData(data); migrateAppData must be idempotent
- Consumes: StudyItem/ReviewLog/AppData shapes

- [ ] **Step 1: Add failing idempotency and guard tests**

Add to tests/migration.test.ts:

~~~ts
import { needsMigration } from '../app/entry/src/main/ets/domain/fsrs/Migration.ts';

it('does not reset an already-valid FSRS item', () => {
  const valid = {
    ...base,
    scheduleMode: 'fsrs', fsrsStability: 9, fsrsDifficulty: 7,
    fsrsState: 'review', fsrsScheduledDays: 9, fsrsLapses: 2, fsrsVersion: 6
  };
  const once = migrateItem(valid as any);
  const twice = migrateItem(once as any);
  expect(once.fsrsStability).toBe(9);
  expect(twice.fsrsStability).toBe(9);
  expect(twice.fsrsDifficulty).toBe(7);
  expect(twice.fsrsLapses).toBe(2);
});

it('detects legacy items, logs, and settings', () => {
  const data: any = {
    schemaVersion: 2,
    subjects: [],
    items: [{ ...base, fsrsVersion: 6, fsrsState: 'new', fsrsStability: 0 }],
    logs: [{ id: 'l', rating: 'got' }],
    settings: { targetRetention: 0.8 }
  };
  expect(needsMigration(data)).toBe(true);
});

it('does not re-migrate fully valid data', () => {
  const data: any = {
    schemaVersion: 2,
    subjects: [],
    items: [{
      ...base, scheduleMode: 'fsrs', fsrsStability: 4, fsrsDifficulty: 5,
      fsrsState: 'review', fsrsScheduledDays: 4, fsrsLapses: 0, fsrsVersion: 6
    }],
    logs: [{
      id: 'l', itemId: 'a', reviewedAt: 1, rating: 'got',
      previousIntervalDays: 1, nextIntervalDays: 4, nextReviewAt: 9,
      grade: 3, stabilityBefore: 0, stabilityAfter: 0,
      difficultyBefore: 0, difficultyAfter: 0, elapsedDays: 1, scheduledDays: 4
    }],
    settings: { targetRetention: 0.8, curveDays: [1, 2] }
  };
  expect(needsMigration(data)).toBe(false);
  const migrated = migrateAppData(data as any) as any;
  expect(migrated.items[0].fsrsStability).toBe(4);
  expect(migrated.settings.targetRetention).toBe(0.8);
});
~~~

- [ ] **Step 2: Make Migration.ts idempotent and content-aware**

Add these functions in Migration.ts:

~~~ts
function isFiniteNumber(value: unknown): boolean {
  return typeof value === 'number' && isFinite(value);
}

export function isValidFsrsItem(item: any): boolean {
  if (item.fsrsVersion !== 6) return false;
  if (!isFiniteNumber(item.fsrsStability) || !isFiniteNumber(item.fsrsDifficulty)) return false;
  if (typeof item.fsrsState !== 'string') return false;
  if (item.reviewCount > 0 && (item.fsrsState === 'new' || !(item.fsrsStability > 0))) return false;
  return item.fsrsStability >= 0 && item.fsrsStability <= 36500 &&
    item.fsrsDifficulty >= 1 && item.fsrsDifficulty <= 10;
}

export function needsMigration(data: any): boolean {
  if (data.schemaVersion !== 2) return true;
  if (!data.items || data.items.some((item: any) => !isValidFsrsItem(item))) return true;
  if (!data.logs || data.logs.some((log: any) => typeof log.grade !== 'number')) return true;
  if (!data.settings || !isFiniteNumber(data.settings.targetRetention)) return true;
  return false;
}
~~~

Update migrateItem:

~~~ts
export function migrateItem(item: any): any {
  if (isValidFsrsItem(item)) return item;
  const reviewed = item.reviewCount > 0;
  return {
    id: item.id, subjectId: item.subjectId, title: item.title,
    createdAt: item.createdAt, scheduleMode: 'fsrs',
    curveStage: item.curveStage, fixedIntervalDays: item.fixedIntervalDays,
    currentIntervalDays: item.currentIntervalDays,
    nextReviewAt: item.nextReviewAt, lastReviewedAt: item.lastReviewedAt,
    reviewCount: item.reviewCount, status: item.status,
    fsrsStability: reviewed ? Math.max(1, item.currentIntervalDays) : 0,
    fsrsDifficulty: 5, fsrsState: reviewed ? 'review' : 'new',
    fsrsScheduledDays: reviewed ? Math.max(1, item.currentIntervalDays) : 0,
    fsrsLapses: 0, fsrsVersion: 6
  };
}
~~~

Update migrateLog to return an existing valid log unchanged:

~~~ts
function migrateLog(log: any): any {
  if (typeof log.grade === 'number') return log;
  return {
    id: log.id, itemId: log.itemId, reviewedAt: log.reviewedAt,
    rating: log.rating, previousIntervalDays: log.previousIntervalDays,
    nextIntervalDays: log.nextIntervalDays, nextReviewAt: log.nextReviewAt,
    grade: migratedGrade(log.rating), stabilityBefore: 0, stabilityAfter: 0,
    difficultyBefore: 0, difficultyAfter: 0,
    elapsedDays: Math.max(0, Math.round(log.previousIntervalDays)),
    scheduledDays: Math.max(0, Math.round(log.nextIntervalDays))
  };
}
~~~

Update migrateSettings to preserve a valid targetRetention:

~~~ts
function migrateSettings(settings: any): any {
  const valid = isFiniteNumber(settings.targetRetention) &&
    settings.targetRetention >= 0.80 && settings.targetRetention <= 0.95;
  return {
    reminderEnabled: settings.reminderEnabled,
    reminderTime: settings.reminderTime,
    subjectTimes: settings.subjectTimes,
    themeIndex: settings.themeIndex,
    language: settings.language,
    curveDays: settings.curveDays,
    targetRetention: valid ? settings.targetRetention : 0.90
  };
}
~~~

migrateAppData remains a per-item/per-log/per-settings map, so mixed legacy/valid data is safe.

- [ ] **Step 3: Use the content-based guard in Store.load**

Import:

~~~ts
import { migrateAppData, needsMigration } from '../domain/fsrs/Migration';
~~~

In Store.load after structural validation:

~~~ts
const needs = needsMigration(parsed);
if (needs) {
  try {
    const migrated = migrateAppData(parsed);
    await Store.save(context, migrated);
    return migrated as AppData;
  } catch (error) {
    return parsed;
  }
}
~~~

Do not use a StudyItem type annotation here unless Store.ets imports StudyItem. Do not return createDefaultData() after a migration failure; preserve the raw parsed data.

- [ ] **Step 4: Build and test**

~~~powershell
cd jiesheng/tests
npx vitest run
cd ../app
node ../.tools/node_modules/@deveco/deveco-cli/cli.js build --build-mode debug
~~~

Expected: all tests pass; BUILD SUCCESSFUL with CompileArkTS executed.

- [ ] **Step 5: Commit**

~~~powershell
git add app/entry/src/main/ets/data/Store.ets app/entry/src/main/ets/domain/fsrs/Migration.ts tests/migration.test.ts
git commit -m "feat: run idempotent FSRS migration in Store"
~~~

---

### Task 5: Replace Scheduling with FSRS and add postpone

**Files:**
- Modify: app/entry/src/main/ets/domain/fsrs/Scheduling.ts
- Modify: app/entry/src/main/ets/domain/Scheduling.ets
- Modify: tests/scheduling.test.ts

**Interfaces:**
- Pure producers in fsrs/Scheduling.ts: scheduleFsrs(item, grade, now, retention), postponeToTomorrow(item, now), previewForGrades(item, now, retention)
- Scheduling.ets re-exports those functions for the UI; it does not duplicate the math.

- [ ] **Step 1: Write tests for postpone semantics**

Add:

~~~ts
import { postponeToTomorrow } from '../app/entry/src/main/ets/domain/fsrs/Scheduling.ts';

it('postpone changes only the due date', () => {
  const item = { id: 'a', reviewCount: 3, fsrsStability: 3, fsrsDifficulty: 5, nextReviewAt: 1 };
  const next = postponeToTomorrow(item as any, new Date(2026, 9, 22).getTime());
  expect(next.reviewCount).toBe(3);
  expect(next.fsrsStability).toBe(3);
  expect(next.nextReviewAt).toBeGreaterThan(item.nextReviewAt);
});
~~~

- [ ] **Step 2: Implement the FSRS adapter in fsrs/Scheduling.ts**

Add pure functions there:

- fsrsStateFromItem(item): build a valid FsrsState; for a new item use state new with S=0/D=5; for a reviewed item use stored S/D.
- scheduleFsrs(item, grade, now, retention): call review(), round the result with roundFsrsDays(), set nextAt = nextDueAt(now, days), and return ReviewResult with curveStage preserved and rating=String(grade).
- previewForGrades(item, now, retention): call preview() for grades 1-4 and return the four integer intervals.
- postponeToTomorrow(item, now): copy the item explicitly (no object spread) and set nextReviewAt = nextDueAt(now, 1); do not change S/D, reviewCount, or logs.

In Scheduling.ets import and re-export these functions. Remove the compile-only fsrsCoreReady function; it must not ship dead code. Guard non-finite S/D/interval values by falling back to max(1, round(raw)).

Add tests for scheduleFsrs (date and S/D update), previewForGrades (four positive intervals), and postponeToTomorrow (only date changes).

- [ ] **Step 3: Run tests and the ArkTS build**

~~~powershell
cd jiesheng/tests
npx vitest run scheduling.test.ts
cd ../app
node ../.tools/node_modules/@deveco/deveco-cli/cli.js build --build-mode debug
~~~

Expected: tests PASS and BUILD SUCCESSFUL with CompileArkTS executed.

- [ ] **Step 4: Commit**

~~~powershell
git add app/entry/src/main/ets/domain/fsrs/Scheduling.ts app/entry/src/main/ets/domain/Scheduling.ets tests/scheduling.test.ts
git commit -m "feat: route scheduling through FSRS"
~~~

---

### Task 6: Build the two-step review entry

**Files:**
- Modify: app/entry/src/main/ets/pages/Index.ets
- Modify: app/entry/src/main/ets/services/I18n.ets

**Interfaces:**
- Consumes: scheduleFsrs, postponeToTomorrow, previewForGrades
- Produces: @State reviewStage: 'entry' | 'rating'; review entry overlay; postpone action

- [ ] **Step 1: Add reviewStage and open/close methods**

Add:

~~~ts
@State reviewStage: string = 'entry';

private openReview(item: StudyItem): void {
  this.reviewItem = item;
  this.reviewStage = 'entry';
  this.showReview = true;
  this.reviewScale = 0.94;
  animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
    this.reviewScale = 1;
  });
}

private closeReview(): void {
  this.showReview = false;
  this.reviewStage = 'entry';
  this.reviewScale = 1;
}

private postponeReview(): void {
  const next = postponeToTomorrow(this.reviewItem, Date.now());
  this.items = this.items.map((item: StudyItem) => item.id === next.id ? next : item);
  this.closeReview();
  this.persist();
  this.syncReminder();
  this.toast(this.t('postponedTomorrow'));
}
~~~

- [ ] **Step 2: Replace ReviewOverlay entry with two buttons**

In ReviewOverlay, render EntryCard when reviewStage==='entry', RatingCard when reviewStage==='rating'. EntryCard must include title, subject, last review, Postpone and Complete buttons.

- [ ] **Step 3: Add i18n strings**

Add zh/en strings for:

postponeTomorrow, completeReview, rateTitle, gradeAgain, gradeHard, gradeGood, gradeEasy, gradeAgainHint, gradeHardHint, gradeGoodHint, gradeEasyHint, postponedTomorrow, nextReviewToast, retentionTitle, retentionHint.

- [ ] **Step 4: Build and verify compile**

~~~powershell
cd jiesheng/app
node ../.tools/node_modules/@deveco/deveco-cli/cli.js build --build-mode debug
~~~

Expected: BUILD SUCCESSFUL.

- [ ] **Step 5: Commit**

~~~powershell
git add app/entry/src/main/ets/pages/Index.ets app/entry/src/main/ets/services/I18n.ets
git commit -m "feat: add FSRS review entry and postpone"
~~~

---

### Task 7: Build the four-grade rating page

**Files:**
- Modify: app/entry/src/main/ets/pages/Index.ets

- [ ] **Step 1: Add preview data**

Replace intervalHint with:

~~~ts
private gradePreview(): number[] {
  return previewForGrades(this.reviewItem, Date.now(), this.settings.targetRetention);
}

private intervalText(days: number): string {
  return days === 1 ? this.t('tomorrow') : this.t('daysAfter', days);
}
~~~

- [ ] **Step 2: Add four grade cards**

Use a 2x2 Flex on phone and one row on wide screens. Each card shows label, meaning, intervalText(preview[index]). Use colors:
Again #D95F3F, Hard #B17A12, Good #8F5600, Easy #5AA469.

Clicking calls:

~~~ts
this.finishReview(grade);
~~~

- [ ] **Step 3: Update commitReview to use FSRS**

Replace scheduleNext with scheduleFsrs(item, Number(grade), now, this.settings.targetRetention). Write grade and before/after S/D into ReviewLog.

- [ ] **Step 4: Build and manually verify**

~~~powershell
cd jiesheng/app
node ../.tools/node_modules/@deveco/deveco-cli/cli.js build --build-mode debug
~~~

Open a due item, tap Complete, verify four cards show four different intervals, tap Easy, verify toast and next date.

- [ ] **Step 5: Commit**

~~~powershell
git add app/entry/src/main/ets/pages/Index.ets
git commit -m "feat: add four-grade FSRS rating UI"
~~~

---

### Task 8: Replace curve settings with retention slider

**Files:**
- Modify: app/entry/src/main/ets/pages/Index.ets
- Modify: app/entry/src/main/ets/domain/Models.ets

- [ ] **Step 1: Remove curve UI and curveDays**

Delete:

- curveDays from Models.ets Settings and from createDefaultData
- curveDaysTitle card and seven day buttons
- openCurvePicker, closeCurvePicker, confirmCurvePicker
- CurvePickerOverlay builder and showCurvePicker state
- CurvePanel builder and curveLabels usage

- [ ] **Step 2: Add retention card**

Add a settings card with a Slider({ value: Math.round(this.settings.targetRetention * 100), min: 80, max: 95, step: 1, style: SliderStyle.OutSet }), label showing value + '%', and helper text. onChange updates a draft state; saveSettings clamps and persists.

- [ ] **Step 3: Update saveSettings**

Use:

~~~ts
const retention = Math.min(0.95, Math.max(0.80, this.settings.targetRetention));
this.settings = { ...this.settings, targetRetention: retention };
~~~

- [ ] **Step 4: Build and verify**

~~~powershell
cd jiesheng/app
node ../.tools/node_modules/@deveco/deveco-cli/cli.js build --build-mode debug
~~~

Expected: no references to curveDays or CurvePickerOverlay remain.

- [ ] **Step 5: Commit**

~~~powershell
git add app/entry/src/main/ets/pages/Index.ets
git commit -m "feat: replace curve settings with retention slider"
~~~

---

### Task 9: End-to-end verification and version bump

**Files:**
- Modify: app/AppScope/app.json5
- Modify: app/entry/src/main/resources/base/element/string.json

- [ ] **Step 1: Bump version**

Set versionName 1.1.0 and increment versionCode from 1000000 to 1000001.

- [ ] **Step 2: Run the full test suite**

~~~powershell
cd jiesheng/tests
npx vitest run
~~~

Expected: all FSRS and migration tests pass.

- [ ] **Step 3: Build debug on phone/tablet emulator**

~~~powershell
cd jiesheng/app
node ../.tools/node_modules/@deveco/deveco-cli/cli.js build --build-mode debug
~~~

Install on 127.0.0.1:5555 and 127.0.0.1:5557, then verify:

- old records survive migration
- due item shows postpone/complete
- four grades show intervals
- postpone changes only date
- retention slider persists after restart
- no curve settings remain

- [ ] **Step 4: Build release and verify signature**

~~~powershell
cd jiesheng
./scripts/build-release.ps1
~~~

Then verify the .app and .hap with hap-sign-tool. Do not upload until 1.0.0 review is complete.

- [ ] **Step 5: Commit**

~~~powershell
git add app/AppScope/app.json5 app/entry/src/main/resources/base/element/string.json
git commit -m "chore: bump Folio to 1.1.0 for FSRS"
~~~

---

## Self-Review

- Spec coverage: architecture (Tasks 1–4), four grades (Task 7), postpone (Tasks 5–6), retention slider (Task 8), migration (Tasks 3–4), error handling (Tasks 1–5), tests (Tasks 1–3, 9).
- No TBD/TODO placeholders in tasks; all paths and commands are explicit.
- Type consistency: FsrsState fields match Models; grade is 1–4 throughout; scheduleFsrs returns ReviewResult.
- Scope: single feature, no unrelated refactors.

## Execution Handoff

Plan complete and saved to docs/superpowers/plans/2026-10-22-fsrs-scheduler.md.

Two execution options:

1. Subagent-Driven (recommended) — fresh subagent per task, review between tasks.
2. Inline Execution — execute tasks in this session with checkpoints.
