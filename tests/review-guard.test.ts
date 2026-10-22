import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';

const sourcePath = fileURLToPath(new URL('../app/entry/src/main/ets/pages/Index.ets', import.meta.url));
const source = readFileSync(sourcePath, 'utf8');

function methodBody(name: string): string {
  const signature = 'private ' + name + '(';
  const start = source.indexOf(signature);
  if (start < 0) {
    throw new Error('missing member: ' + name);
  }
  const open = source.indexOf('{', start);
  let depth = 0;
  for (let i = open; i < source.length; i++) {
    const ch = source[i];
    if (ch === '{') {
      depth += 1;
    } else if (ch === '}') {
      depth -= 1;
      if (depth === 0) {
        return source.slice(open + 1, i);
      }
    }
  }
  throw new Error('unterminated member: ' + name);
}

function requireIndex(body: string, needle: string): number {
  const at = body.indexOf(needle);
  expect(at, 'missing: ' + needle).toBeGreaterThan(-1);
  return at;
}

describe('review commit race guards (static, UI-free)', () => {
  it('declares the two tracked timer ids and the review token', () => {
    expect(source).toContain('private reviewPressTimer: number');
    expect(source).toContain('private reviewCommitTimer: number');
    expect(source).toContain('private reviewToken: number');
  });

  it('clears both timeout ids', () => {
    const body = methodBody('clearReviewTimers');
    requireIndex(body, 'clearTimeout(this.reviewPressTimer)');
    requireIndex(body, 'clearTimeout(this.reviewCommitTimer)');
  });

  it('bumps the token and resets busy/pressed when discarding', () => {
    const body = methodBody('discardPendingReview');
    requireIndex(body, 'this.clearReviewTimers()');
    requireIndex(body, 'this.reviewToken = this.reviewToken + 1');
    requireIndex(body, 'this.reviewBusy = false');
    requireIndex(body, 'this.pressedGrade = 0');
  });

  it('cancels pending commits on close, back, open, and postpone', () => {
    for (const name of ['closeReview', 'backToEntry', 'openReview', 'postponeReview']) {
      expect(methodBody(name), name).toContain('this.discardPendingReview()');
    }
    const open = methodBody('openReview');
    expect(open.indexOf('discardPendingReview')).toBeLessThan(open.indexOf('this.reviewItem = item'));
  });

  it('cancels a pending commit before deleting the reviewed item', () => {
    const body = methodBody('deleteItem');
    const close = requireIndex(body, 'this.closeReview()');
    expect(close).toBeLessThan(requireIndex(body, 'this.items = this.items.filter'));
    expect(body).toContain('this.reviewItem.id === id');
  });

  it('captures item id and token at grade tap and tracks both timers', () => {
    const body = methodBody('finishReview');
    requireIndex(body, 'const itemId = this.reviewItem.id');
    requireIndex(body, 'const token = this.reviewToken');
    requireIndex(body, 'this.reviewPressTimer = setTimeout');
    requireIndex(body, 'this.reviewCommitTimer = setTimeout');
    expect(body).toContain('this.commitReview(grade, itemId, token)');
  });

  it('re-checks the active-review guard before the commit call', () => {
    const body = methodBody('finishReview');
    const commitCall = requireIndex(body, 'this.commitReview(grade, itemId, token)');
    const guard = body.lastIndexOf('isReviewCommitActive(itemId, token)', commitCall);
    expect(guard).toBeGreaterThan(-1);
  });

  it('makes commitReview a no-op unless the same item and token are active', () => {
    // guard must run before any scheduling/log side effect
    const body = methodBody('commitReview');
    const guard = requireIndex(body, 'if (!this.isReviewCommitActive(itemId, token))');
    expect(guard).toBeLessThan(requireIndex(body, 'scheduleFsrs('));
    expect(source).toContain('private commitReview(grade: number, itemId: string, token: number): void');
  });

  it('routes the rating card back button through backToEntry', () => {
    const backButton = source.slice(source.indexOf("Button('←')"), source.indexOf("Button('←')") + 700);
    expect(backButton).toContain('this.backToEntry()');
    expect(backButton).not.toContain("this.reviewStage = 'entry'");
  });
});
