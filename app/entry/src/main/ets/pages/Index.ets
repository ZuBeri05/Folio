import { common } from '@kit.AbilityKit';
import { promptAction, LengthMetrics, KeyboardAvoidMode, window } from '@kit.ArkUI';
import { AppData, Subject, StudyItem, ReviewLog, Settings, DayCount, SUBJECT_COLORS, createDefaultData, emptyItem, newId } from '../domain/Models';
import { Store } from '../data/Store';
import { scheduleNext, firstReviewAt, startOfDay, addDays, daysBetween, formatDate, formatShort, formatFull, weekdayCN, ratingLabel } from '../domain/Scheduling';
import { ReminderService } from '../services/ReminderService';
import { Tokens } from '../theme/Tokens';
import { I18n, LanguageOption } from '../services/I18n';

@Entry
@Component
struct Index {
  @State items: StudyItem[] = [];
  @State logs: ReviewLog[] = [];
  @State subjects: Subject[] = [];
  @State settings: Settings = createDefaultData().settings;
  @State tab: number = 0;
  @StorageProp('topInset') topInset: number = 0;
  @StorageProp('bottomInset') bottomInset: number = 0;
  @State isWide: boolean = true;
  @State showReview: boolean = false;
  @State reviewItem: StudyItem = emptyItem();
  @State showComposer: boolean = false;
  @State draftSubjectId: string = 'math';
  @State draftTitle: string = '';
  @State draftMode: string = 'curve';
  @State draftFixedDays: number = 3;
  @State newSubjectName: string = '';
  @State calendarProgress: number = 1;
  @State calendarX: number[] = [0, 0, 0, 0, 0, 0, 0];
  @State calendarAlpha: number[] = [1, 1, 1, 1, 1, 1, 1];
  @State dotVisible: number = 6;
  @State formProgress: number = 1;
  @State titleFocused: boolean = false;
  @State titleBorderColor: string = '#B3FFFFFF';
  @State todayLabel: string = '';
  @State reviewScale: number = 0.97;
  @State isTablet: boolean = false;
  @State listOpacity: number = 0;
  @State listShift: number = 16;
  @State pressedRating: string = '';
  @State composerScale: number = 0.97;
  @State composerShift: number = 24;
  @State composerOpacity: number = 1;
  @State composerDim: number = 0;
  @State notificationEnabled: boolean = false;
  @State reminderCount: number = -1;
  @State reminderError: string = '';
  @State reminderMode: string = '';
  @State pageOpacity: number = 1;
  @State pageShift: number = 0;
  @State pressedItemId: string = '';
  @State showItemActions: boolean = false;
  @State actionItem: StudyItem = emptyItem();
  @State actionMode: string = 'view';
  @State editTitle: string = '';
  @State editSubjectId: string = '';
  @State actionScale: number = 1;
  @State actionContentOpacity: number = 1;
  @State actionOverlayOpacity: number = 1;
  @State showConfirm: boolean = false;
  @State confirmTitle: string = '';
  @State confirmMessage: string = '';
  @State confirmKind: string = '';
  @State confirmSubjectId: string = '';
  @State confirmItemId: string = '';
  @State confirmScale: number = 1;
  @State showCurvePicker: boolean = false;
  @State curvePickIndex: number = 0;
  @State curvePickValue: number = 1;
  @State curvePickScale: number = 1;
  private reviewBusy: boolean = false;

  private readonly navGlyphs: string[] = ['今', '记', '历', '设'];
  private readonly navLabels: string[] = ['今日', '记录', '日历', '设置'];
  private readonly navIconsOn: Resource[] = [
    $r('app.media.ic_home_on'),
    $r('app.media.ic_records_on'),
    $r('app.media.ic_calendar_on'),
    $r('app.media.ic_settings_on')
  ];
  private readonly navIconsOff: Resource[] = [
    $r('app.media.ic_home_off'),
    $r('app.media.ic_records_off'),
    $r('app.media.ic_calendar_off'),
    $r('app.media.ic_settings_off')
  ];
  private readonly navIcons: Resource[] = [
    $r('app.media.ic_banana_on'),
    $r('app.media.ic_lemon_on'),
    $r('app.media.ic_carrot_on'),
    $r('app.media.ic_watermelon_on')
  ];
  private readonly navIconsMuted: Resource[] = [
    $r('app.media.ic_banana_off'),
    $r('app.media.ic_lemon_off'),
    $r('app.media.ic_carrot_off'),
    $r('app.media.ic_watermelon_off')
  ];
  private readonly curveNodes: number[] = [0, 1, 2, 3, 4, 5];

  aboutToAppear(): void {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.NONE);
    const now = new Date();
    this.todayLabel = formatFull(now.getTime()) + '  ·  ' + weekdayCN(now.getTime());
    this.loadData();
  }

  private async loadData(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    const data = await Store.load(context);
    this.subjects = data.subjects;
    this.items = data.items;
    this.logs = data.logs;
    this.settings = data.settings;
    this.todayLabel = this.localizedToday();
    this.syncSystemBars();
    if (this.subjects.length > 0) {
      this.draftSubjectId = this.subjects[0].id;
    }
    this.playEntry();
    this.playDots();
    this.playForm();
    this.refreshNotificationState();
    if (this.settings.reminderEnabled && this.items.length > 0) {
      this.syncReminder();
    }
  }

  private playEntry(): void {
    this.listOpacity = 0;
    this.listShift = 24;
    setTimeout(() => {
      animateTo({ duration: 480, curve: Curve.EaseOut }, () => {
        this.listOpacity = 1;
        this.listShift = 0;
      });
    }, 40);
  }

  private refreshNotificationState(): void {
    const context = getContext(this) as common.UIAbilityContext;
    ReminderService.isEnabled().then((enabled: boolean) => {
      this.notificationEnabled = enabled;
    }).catch(() => {
      this.notificationEnabled = false;
    });
    ReminderService.count(context).then((count: number) => {
      this.reminderCount = count;
    }).catch(() => {
      this.reminderCount = -1;
    });
  }

  private openComposer(): void {
    this.showComposer = true;
    this.playDots();
    this.playForm();
    this.composerScale = 0.92;
    this.composerShift = 24;
    this.composerOpacity = 0;
    this.composerDim = 0;
    animateTo({ duration: 420, curve: Curve.EaseOut }, () => {
      this.composerScale = 1;
      this.composerShift = 0;
      this.composerOpacity = 1;
      this.composerDim = 1;
    });
  }

  private closeComposer(): void {
    animateTo({ duration: 220, curve: Curve.EaseIn }, () => {
      this.composerScale = 0.96;
      this.composerShift = 10;
      this.composerOpacity = 0;
      this.composerDim = 0;
    });
    setTimeout(() => {
      this.showComposer = false;
      this.composerScale = 1;
      this.composerShift = 0;
      this.composerOpacity = 1;
      this.composerDim = 0;
    }, 220);
  }

  private persist(): void {
    const context = getContext(this) as common.UIAbilityContext;
    const data: AppData = {
      schemaVersion: 2,
      subjects: this.subjects,
      items: this.items,
      logs: this.logs,
      settings: this.settings
    };
    Store.save(context, data).catch(() => {
      this.toast(this.t('toastSaveFail'));
    });
  }

  private syncReminder(): void {
    const context = getContext(this) as common.UIAbilityContext;
    ReminderService.sync(context, this.settings, this.items.length > 0).then((mode: string) => {
      this.reminderError = '';
      this.reminderMode = mode;
      setTimeout(() => {
        this.refreshNotificationState();
      }, 600);
    }).catch((error: Error) => {
      this.reminderError = error.message !== undefined ? error.message : this.t('toastReminderOff');
      this.toast(this.t('toastReminderFail'));
      this.refreshNotificationState();
    });
  }

  private toast(message: string): void {
    promptAction.showToast({ message: message, duration: 1800 });
  }

  private findSubject(id: string): Subject {
    for (let i = 0; i < this.subjects.length; i++) {
      if (this.subjects[i].id === id) {
        return this.subjects[i];
      }
    }
    return { id: '', name: '其他', color: Tokens.muted };
  }

  private dueItems(): StudyItem[] {
    const today = startOfDay(new Date()).getTime();
    const result: StudyItem[] = [];
    for (let i = 0; i < this.items.length; i++) {
      const item = this.items[i];
      if (item.status === 'active' && startOfDay(new Date(item.nextReviewAt)).getTime() <= today) {
        result.push(item);
      }
    }
    result.sort((a: StudyItem, b: StudyItem) => a.nextReviewAt - b.nextReviewAt);
    return result;
  }

  private sortedItems(): StudyItem[] {
    const result = this.items.slice();
    result.sort((a: StudyItem, b: StudyItem) => b.createdAt - a.createdAt);
    return result;
  }

  private todayCreatedItems(): StudyItem[] {
    const today = startOfDay(new Date()).getTime();
    const result: StudyItem[] = [];
    for (let i = 0; i < this.items.length; i++) {
      const item = this.items[i];
      if (startOfDay(new Date(item.createdAt)).getTime() === today) {
        result.push(item);
      }
    }
    result.sort((a: StudyItem, b: StudyItem) => b.createdAt - a.createdAt);
    return result;
  }

  private switchTab(next: number): void {
    if (next === this.tab) {
      return;
    }
    const forward = next > this.tab;
    animateTo({ duration: 130, curve: Curve.EaseIn }, () => {
      this.pageOpacity = 0;
      this.pageShift = 0;
    });
    setTimeout(() => {
      this.tab = next;
      this.syncSystemBars();
      this.pageOpacity = 0;
      this.pageShift = next === 2 ? 0 : 16;
      animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
        this.pageOpacity = 1;
        this.pageShift = 0;
      });
      if (next === 0) {
        this.playEntry();
        this.playDots();
        this.playForm();
      }
      if (next === 2) {
        this.playCalendarRows();
      } else {
        this.playCalendar();
      }
    }, 130);
  }

  private itemSubtitle(item: StudyItem): string {
    const base = item.lastReviewedAt > 0 ? item.lastReviewedAt : item.createdAt;
    const days = daysBetween(base, new Date());
    const reviewNo = item.reviewCount + 1;
    if (days === 0) {
      return this.t('todayNode') + '  ·  ' + this.t('reviewN', reviewNo);
    }
    return this.t('subtitle', days, reviewNo);
  }

  private progressFor(item: StudyItem): number {
    if (item.scheduleMode === 'fixed') {
      return Math.min(88, 30 + item.reviewCount * 12);
    }
    return Math.min(92, 24 + item.curveStage * 12);
  }

  private upcoming(): DayCount[] {
    const result: DayCount[] = [];
    const base = startOfDay(new Date());
    for (let i = 0; i < 7; i++) {
      const day = addDays(base, i);
      const key = day.getTime();
      let count = 0;
      for (let j = 0; j < this.items.length; j++) {
        const item = this.items[j];
        if (item.status === 'active' && startOfDay(new Date(item.nextReviewAt)).getTime() === key) {
          count++;
        }
      }
      result.push({ date: key, count: count });
    }
    return result;
  }

  private previousLog(itemId: string): ReviewLog {
    for (let i = 0; i < this.logs.length; i++) {
      if (this.logs[i].itemId === itemId) {
        return this.logs[i];
      }
    }
    return {
      id: '',
      itemId: '',
      reviewedAt: 0,
      rating: '',
      previousIntervalDays: 0,
      nextIntervalDays: 0,
      nextReviewAt: 0,
      grade: 0,
      stabilityBefore: 0,
      stabilityAfter: 0,
      difficultyBefore: 0,
      difficultyAfter: 0,
      elapsedDays: 0,
      scheduledDays: 0
    };
  }

  private lastRating(itemId: string): string {
    const log = this.previousLog(itemId);
    if (log.id.length === 0) {
      return this.t('first');
    }
    if (log.rating === 'forgot') {
      return this.t('forgot');
    }
    if (log.rating === 'fuzzy') {
      return this.t('fuzzy');
    }
    return this.t('got');
  }

  private lastInterval(itemId: string): number {
    const log = this.previousLog(itemId);
    return log.id.length > 0 ? log.previousIntervalDays : 1;
  }

  private intervalHint(rating: string): string {
    const result = scheduleNext(this.reviewItem, rating, new Date(), this.settings.curveDays);
    return result.nextIntervalDays === 1 ? this.t('tomorrow') : this.t('daysAfter', result.nextIntervalDays);
  }

  private curveLabels(): string[] {
    const labels: string[] = [this.t('todayNode')];
    const safe = this.settings.curveDays.length >= 2 ? this.settings.curveDays : [1, 2, 4, 7, 15];
    for (let i = 0; i < 5; i++) {
      labels.push(this.t('days', safe[Math.min(i, safe.length - 1)]));
    }
    return labels;
  }

  private openReview(item: StudyItem): void {
    this.reviewItem = item;
    this.showReview = true;
    this.reviewScale = 0.94;
    animateTo({ duration: 360, curve: Curve.EaseOut }, () => {
      this.reviewScale = 1;
    });
  }

  private finishReview(rating: string): void {
    if (this.reviewBusy) {
      return;
    }
    this.reviewBusy = true;
    animateTo({ duration: 160, curve: Curve.EaseOut }, () => {
      this.pressedRating = rating;
    });
    setTimeout(() => {
      animateTo({ duration: 180, curve: Curve.EaseIn }, () => {
        this.reviewScale = 0.95;
      });
      setTimeout(() => {
        this.commitReview(rating);
      }, 170);
    }, 130);
  }

  private commitReview(rating: string): void {
    const item = this.reviewItem;
    const now = new Date();
    const result = scheduleNext(item, rating, now, this.settings.curveDays);
    const updated: StudyItem = {
      id: item.id,
      subjectId: item.subjectId,
      title: item.title,
      createdAt: item.createdAt,
      scheduleMode: item.scheduleMode,
      curveStage: result.curveStage,
      fixedIntervalDays: item.fixedIntervalDays,
      currentIntervalDays: result.nextIntervalDays,
      nextReviewAt: result.nextAt,
      lastReviewedAt: now.getTime(),
      reviewCount: item.reviewCount + 1,
      status: item.status,
      fsrsStability: item.fsrsStability,
      fsrsDifficulty: item.fsrsDifficulty,
      fsrsState: item.fsrsState,
      fsrsScheduledDays: item.fsrsScheduledDays,
      fsrsLapses: item.fsrsLapses,
      fsrsVersion: item.fsrsVersion
    };
    animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
      this.items = this.items.map((value: StudyItem) => value.id === updated.id ? updated : value);
    });
    const log: ReviewLog = {
      id: newId(),
      itemId: item.id,
      reviewedAt: now.getTime(),
      rating: rating,
      previousIntervalDays: item.currentIntervalDays,
      nextIntervalDays: result.nextIntervalDays,
      nextReviewAt: result.nextAt,
      grade: rating === 'forgot' ? 1 : rating === 'fuzzy' ? 2 : 3,
      stabilityBefore: 0,
      stabilityAfter: 0,
      difficultyBefore: 0,
      difficultyAfter: 0,
      elapsedDays: item.currentIntervalDays,
      scheduledDays: result.nextIntervalDays
    };
    this.logs = [log, ...this.logs];
    this.showReview = false;
    this.reviewScale = 1;
    this.pressedRating = '';
    this.reviewBusy = false;
    this.persist();
    this.syncReminder();
    this.toast(this.t('toastNext', formatDate(result.nextAt)));
  }

  private addItem(): void {
    const title = this.draftTitle.trim();
    if (title.length === 0) {
      this.toast(this.t('toastWriteToday'));
      return;
    }
    const now = new Date();
    const firstAt = firstReviewAt(this.draftMode, this.draftFixedDays, now, this.settings.curveDays);
    const item: StudyItem = {
      id: newId(),
      subjectId: this.draftSubjectId,
      title: title,
      createdAt: now.getTime(),
      scheduleMode: this.draftMode,
      curveStage: 0,
      fixedIntervalDays: this.draftFixedDays,
      currentIntervalDays: this.draftMode === 'fixed' ? this.draftFixedDays : 1,
      nextReviewAt: firstAt,
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
    animateTo({ duration: 320, curve: Curve.EaseOut }, () => {
      this.items = [item, ...this.items];
    });
    this.draftTitle = '';
    this.showComposer = false;
    this.switchTab(0);
    this.persist();
    this.syncReminder();
    this.toast(this.t('toastSaved', formatDate(firstAt)));
  }

  private updateReminderEnabled(value: boolean): void {
    this.settings = {
      reminderEnabled: value,
      reminderTime: this.settings.reminderTime,
      subjectTimes: this.settings.subjectTimes,
      themeIndex: this.settings.themeIndex,
      language: this.settings.language,
      curveDays: this.settings.curveDays,
      targetRetention: this.settings.targetRetention
    };
    this.persist();
    this.syncReminder();
  }

  private updateReminderTime(value: string): void {
    this.settings = {
      reminderEnabled: this.settings.reminderEnabled,
      reminderTime: value,
      subjectTimes: this.settings.subjectTimes,
      themeIndex: this.settings.themeIndex,
      language: this.settings.language,
      curveDays: this.settings.curveDays,
      targetRetention: this.settings.targetRetention
    };
  }

  private saveSettings(): void {
    const pattern: RegExp = /^([01]?[0-9]|2[0-3]):[0-5][0-9]$/;
    if (!pattern.test(this.settings.reminderTime)) {
      this.toast(this.t('toastTime'));
      return;
    }
    this.persist();
    this.syncReminder();
    this.toast(this.t('toastSettingsSaved'));
  }

  private updateTheme(index: number): void {
    this.settings = {
      reminderEnabled: this.settings.reminderEnabled,
      reminderTime: this.settings.reminderTime,
      subjectTimes: this.settings.subjectTimes,
      themeIndex: index,
      language: this.settings.language,
      curveDays: this.settings.curveDays,
      targetRetention: this.settings.targetRetention
    };
    this.persist();
    this.syncSystemBars();
  }

  private syncSystemBars(): void {
    const context = getContext(this) as common.UIAbilityContext;
    const bg = this.pageBg();
    window.getLastWindow(context).then((win: window.Window) => {
      win.setWindowBackgroundColor(bg);
      win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: '#1F1B14',
        navigationBarColor: '#00000000',
        navigationBarContentColor: '#1F1B14'
      }).catch(() => {
      });
      win.setWindowLayoutFullScreen(true).then(() => {
        const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        AppStorage.setOrCreate('topInset', px2vp(area.topRect.height));
        AppStorage.setOrCreate('bottomInset', px2vp(area.bottomRect.height));
      }).catch(() => {
      });
    }).catch(() => {
    });
  }

  private t(key: string, a?: string | number, b?: string | number): string {
    return I18n.t(this.settings.language, key, a, b);
  }

  private navLabel(index: number): string {
    const keys: string[] = ['navToday', 'navRecords', 'navCalendar', 'navSettings'];
    const safe = index >= 0 && index < keys.length ? index : 0;
    return this.t(keys[safe]);
  }

  private localizedToday(): string {
    const locale = I18n.locale(this.settings.language);
    try {
      const text = new Intl.DateTimeFormat(locale, {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        weekday: 'long'
      }).format(new Date());
      return text.replace(',', ' · ');
    } catch (error) {
      return formatFull(Date.now()) + ' · ' + weekdayCN(Date.now());
    }
  }

  private updateCurveDay(index: number, value: string): void {
    const days = Number(value);
    if (isNaN(days) || days < 1 || days > 90) {
      return;
    }
    const next = this.settings.curveDays.slice();
    next[index] = Math.round(days);
    this.settings = {
      reminderEnabled: this.settings.reminderEnabled,
      reminderTime: this.settings.reminderTime,
      subjectTimes: this.settings.subjectTimes,
      themeIndex: this.settings.themeIndex,
      language: this.settings.language,
      curveDays: next,
      targetRetention: this.settings.targetRetention
    };
    this.persist();
  }

  private openCurvePicker(index: number): void {
    this.curvePickIndex = index;
    this.curvePickValue = this.settings.curveDays[index];
    this.showCurvePicker = true;
    this.curvePickScale = 0.94;
    animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.curvePickScale = 1;
    });
  }

  private closeCurvePicker(): void {
    this.showCurvePicker = false;
  }

  private confirmCurvePicker(): void {
    this.updateCurveDay(this.curvePickIndex, this.curvePickValue + '');
    this.showCurvePicker = false;
  }

  private setLanguage(code: string): void {
    this.settings = {
      reminderEnabled: this.settings.reminderEnabled,
      reminderTime: this.settings.reminderTime,
      subjectTimes: this.settings.subjectTimes,
      themeIndex: this.settings.themeIndex,
      language: code,
      curveDays: this.settings.curveDays,
      targetRetention: this.settings.targetRetention
    };
    this.todayLabel = this.localizedToday();
    this.persist();
  }

  private pageColors(index: number): string[] {
    const palettes: string[][] = [
      ['#F7F2E4', '#F7F2E4', '#F7F2E4', '#F7F2E4'],
      ['#F7F2E4', '#F1F5F8', '#F2F5EE', '#F5F1F7'],
      ['#FBF3E9', '#F8F2EA', '#F4F4EA', '#F7F0F2'],
      ['#F4F5EC', '#EFF5F1', '#F1F6ED', '#F4F2EC']
    ];
    const safe = index >= 0 && index < palettes.length ? index : 0;
    return palettes[safe];
  }

  private themeAccent(index: number): string {
    const accents: string[] = ['#E8A21A', '#6E9BC5', '#D9826B', '#7FA88B'];
    const safe = index >= 0 && index < accents.length ? index : 0;
    return accents[safe];
  }

  private pageBg(): string {
    const colors = this.pageColors(this.settings.themeIndex);
    const index = this.tab >= 0 && this.tab < colors.length ? this.tab : 0;
    return colors[index];
  }

  private addSubject(): void {
    const name = this.newSubjectName.trim();
    if (name.length === 0) {
      this.toast(this.t('toastSubjectEmpty'));
      return;
    }
    for (let i = 0; i < this.subjects.length; i++) {
      if (this.subjects[i].name === name) {
        this.toast(this.t('toastSubjectExists'));
        return;
      }
    }
    const subject: Subject = {
      id: newId(),
      name: name,
      color: SUBJECT_COLORS[this.subjects.length % SUBJECT_COLORS.length]
    };
    this.subjects = [...this.subjects, subject];
    this.draftSubjectId = subject.id;
    this.newSubjectName = '';
    this.persist();
    this.toast(this.t('toastSubjectAdded', name));
  }

  private openItemActions(item: StudyItem): void {
    this.actionItem = item;
    this.editTitle = item.title;
    this.editSubjectId = item.subjectId;
    this.actionMode = 'view';
    this.showItemActions = true;
    this.actionContentOpacity = 1;
    this.actionOverlayOpacity = 1;
    this.actionScale = 0.9;
    animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
      this.actionScale = 1;
    });
  }

  private closeItemActions(): void {
    if (!this.showItemActions) {
      return;
    }
    animateTo({ duration: 180, curve: Curve.EaseIn }, () => {
      this.actionOverlayOpacity = 0;
      this.actionScale = 0.94;
    });
    setTimeout(() => {
      this.showItemActions = false;
      this.actionOverlayOpacity = 1;
      this.actionScale = 1;
      this.actionContentOpacity = 1;
    }, 190);
  }

  private startEditItem(): void {
    this.editTitle = this.actionItem.title;
    this.editSubjectId = this.actionItem.subjectId;
    this.changeActionMode('edit');
  }

  private changeActionMode(mode: string): void {
    animateTo({ duration: 120, curve: Curve.EaseIn }, () => {
      this.actionContentOpacity = 0;
      this.actionScale = 0.98;
    });
    setTimeout(() => {
      this.actionMode = mode;
      this.actionContentOpacity = 0;
      this.actionScale = 0.98;
      animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
        this.actionContentOpacity = 1;
        this.actionScale = 1;
      });
    }, 160);
  }

  private saveItemEdit(): void {
    const title = this.editTitle.trim();
    if (title.length === 0) {
      this.toast(this.t('toastTitleEmpty'));
      return;
    }
    const updated: StudyItem = {
      id: this.actionItem.id,
      subjectId: this.editSubjectId,
      title: title,
      createdAt: this.actionItem.createdAt,
      scheduleMode: this.actionItem.scheduleMode,
      curveStage: this.actionItem.curveStage,
      fixedIntervalDays: this.actionItem.fixedIntervalDays,
      currentIntervalDays: this.actionItem.currentIntervalDays,
      nextReviewAt: this.actionItem.nextReviewAt,
      lastReviewedAt: this.actionItem.lastReviewedAt,
      reviewCount: this.actionItem.reviewCount,
      status: this.actionItem.status,
      fsrsStability: this.actionItem.fsrsStability,
      fsrsDifficulty: this.actionItem.fsrsDifficulty,
      fsrsState: this.actionItem.fsrsState,
      fsrsScheduledDays: this.actionItem.fsrsScheduledDays,
      fsrsLapses: this.actionItem.fsrsLapses,
      fsrsVersion: this.actionItem.fsrsVersion
    };
    this.items = this.items.map((item: StudyItem) => item.id === updated.id ? updated : item);
    this.showItemActions = false;
    this.persist();
    this.toast(this.t('toastModified'));
  }

  private confirmDeleteSubject(subject: Subject): void {
    if (this.subjects.length <= 1) {
      this.toast(this.t('toastAtLeastOne'));
      return;
    }
    let used = 0;
    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].subjectId === subject.id) {
        used = used + 1;
      }
    }
    if (used > 0) {
      this.toast(this.t('toastSubjectUsed', used));
      return;
    }
    this.confirmTitle = this.t('deleteSubjectTitle');
    this.confirmMessage = this.t('deleteSubjectMsg', subject.name);
    this.confirmKind = 'subject';
    this.confirmSubjectId = subject.id;
    this.confirmItemId = '';
    this.showConfirm = true;
    this.confirmScale = 0.94;
    animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
      this.confirmScale = 1;
    });
    return;
    AlertDialog.show({
      title: '删除科目？',
      message: subject.name,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#C7422C',
        action: () => {
          this.subjects = this.subjects.filter((value: Subject) => value.id !== subject.id);
          if (this.draftSubjectId === subject.id && this.subjects.length > 0) {
            this.draftSubjectId = this.subjects[0].id;
          }
          this.persist();
          this.toast(this.t('toastSubjectDeleted', subject.name));
        }
      }
    });
  }

  private askDeleteRecord(item: StudyItem): void {
    this.confirmTitle = this.t('deleteRecordTitle');
    this.confirmMessage = this.t('deleteRecordMsg', item.title);
    this.confirmKind = 'record';
    this.confirmItemId = item.id;
    this.confirmSubjectId = '';
    this.showItemActions = false;
    this.showConfirm = true;
    this.confirmScale = 0.94;
    animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
      this.confirmScale = 1;
    });
  }

  private cancelConfirm(): void {
    this.showConfirm = false;
  }

  private executeConfirm(): void {
    const kind = this.confirmKind;
    const subjectId = this.confirmSubjectId;
    const itemId = this.confirmItemId;
    this.showConfirm = false;
    if (kind === 'subject') {
      this.subjects = this.subjects.filter((value: Subject) => value.id !== subjectId);
      if (this.draftSubjectId === subjectId && this.subjects.length > 0) {
        this.draftSubjectId = this.subjects[0].id;
      }
      this.persist();
      this.toast(this.t('toastDeleted'));
    } else if (kind === 'record') {
      this.deleteItem(itemId);
    }
  }

  private deleteFromAction(): void {
    this.askDeleteRecord(this.actionItem);
  }

  private deleteItem(id: string): void {
    this.items = this.items.filter((item: StudyItem) => item.id !== id);
    this.logs = this.logs.filter((log: ReviewLog) => log.itemId !== id);
    if (this.reviewItem.id === id) {
      this.showReview = false;
    }
    this.persist();
    this.syncReminder();
    this.toast(this.t('toastDeleted'));
  }

  private playForm(): void {
    this.formProgress = 0;
    animateTo({ duration: 520, curve: Curve.EaseOut }, () => {
      this.formProgress = 1;
    });
  }

  private playDots(): void {
    this.dotVisible = 0;
    for (let i = 0; i < 6; i++) {
      setTimeout(() => {
        this.dotVisible = i + 1;
      }, i * 110);
    }
  }

  private playCalendarRows(): void {
    this.calendarX = [0, 0, 0, 0, 0, 0, 0];
    this.calendarAlpha = [0, 0, 0, 0, 0, 0, 0];
    for (let i = 0; i < 7; i++) {
      setTimeout(() => {
        const shown = this.calendarAlpha.slice();
        shown[i] = 1;
        this.calendarAlpha = shown;
        const start = this.calendarX.slice();
        start[i] = 64;
        this.calendarX = start;
        setTimeout(() => {
          animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
            const hit = this.calendarX.slice();
            hit[i] = 0;
            this.calendarX = hit;
          });
          setTimeout(() => {
            animateTo({ duration: 100, curve: Curve.EaseOut }, () => {
              const rebound = this.calendarX.slice();
              rebound[i] = 4;
              this.calendarX = rebound;
            });
            setTimeout(() => {
              animateTo({ duration: 120, curve: Curve.EaseOut }, () => {
                const settle = this.calendarX.slice();
                settle[i] = 0;
                this.calendarX = settle;
              });
            }, 100);
          }, 300);
        }, 20);
      }, i * 70);
    }
  }

  private playCalendar(): void {
    this.calendarProgress = 0;
    animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
      this.calendarProgress = 1;
    });
    setTimeout(() => {
      animateTo({ duration: 140, curve: Curve.EaseOut }, () => {
        this.calendarProgress = 0.9;
      });
    }, 300);
    setTimeout(() => {
      animateTo({ duration: 140, curve: Curve.EaseOut }, () => {
        this.calendarProgress = 1;
      });
    }, 440);
  }

  build() {
    Stack() {
      if (this.isWide) {
        this.TabletLayout()
      } else {
        this.PhoneLayout()
      }
      if (this.showReview) {
        this.ReviewOverlay()
      }
      if (this.showComposer && !this.isWide) {
        this.ComposerOverlay()
      }
      if (this.showItemActions) {
        this.ItemActionsOverlay()
      }
      if (this.showConfirm) {
        this.ConfirmOverlay()
      }
      if (this.showCurvePicker) {
        this.CurvePickerOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBg())
    .animation({ duration: 320, curve: Curve.EaseOut })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.isWide = Number(newValue.width) >= 840;
      this.isTablet = Number(newValue.width) >= 700;
    })
  }

  @Builder TabletLayout() {
    Row() {
      this.Rail()
      Column() {
        this.TopBar(false)
        if (this.tab === 0) {
          Row() {
            this.TodayPane()
            this.ComposerPane(false)
          }
          .width('100%')
          .layoutWeight(1)
          .alignItems(VerticalAlign.Top)
          .padding({ left: 44, right: 44, top: 12, bottom: 32 })
        } else {
          this.OtherPage()
        }
      }
      .layoutWeight(1)
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topInset, bottom: this.bottomInset })
  }

  @Builder PhoneLayout() {
    Column() {
      this.TopBar(true)
      if (this.tab === 0) {
        this.TodayPane()
      } else {
        this.OtherPage()
      }
      this.BottomNav()
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topInset, bottom: this.bottomInset })
  }

  @Builder Rail() {
    Column() {
      Column({ space: 34 }) {
        ForEach([0, 1, 2, 3], (index: number) => {
          this.NavItem(index)
        })
      }
      .width(112)
      .margin({ top: 56 })

      Blank()
      Text('v1.0')
        .fontSize(7)
        .fontColor(Tokens.mutedSoft)
        .margin({ bottom: 20 })
    }
    .width(124)
    .height('100%')
    .backgroundColor(this.pageBg())
    .animation({ duration: 320, curve: Curve.EaseOut })
  }

  @Builder NavItem(index: number) {
    Column() {
      Image(this.tab === index ? this.navIcons[index] : this.navIconsMuted[index])
        .width(30)
        .height(30)
        .objectFit(ImageFit.Contain)

      Text(this.navLabel(index))
        .fontSize(11.5)
        .fontWeight(this.tab === index ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.tab === index ? '#6C4B00' : Tokens.mutedSoft)
        .margin({ top: 4 })
        .animation({ duration: 180, curve: Curve.EaseOut })
    }
    .width(112)
    .height(88)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.switchTab(index);
    })
  }

  @Builder TopBar(showAdd: boolean) {
    Row() {
      Text(this.todayLabel)
        .fontSize(12)
        .fontColor(Tokens.muted)
      Blank()
      if (showAdd) {
        Button(this.t('newEntry'))
          .height(34)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#3D2A00')
          .backgroundColor(Tokens.yellow)
          .borderRadius(17)
          .padding({ left: 14, right: 14 })
          .onClick(() => {
            this.openComposer();
          })
      }
    }
    .width('100%')
    .height(72)
    .padding({ left: this.isWide ? 44 : 20, right: this.isWide ? 44 : 20 })
    .backgroundColor(this.pageBg())
    .animation({ duration: 320, curve: Curve.EaseOut })
  }

  @Builder TodayPane() {
    Column() {
      Row() {
        Text(this.t('todayTitle'))
          .fontSize(this.isWide ? 48 : 34)
          .fontWeight(FontWeight.Bold)
          .fontColor(Tokens.ink)
          .letterSpacing(-1)
        Row() {
          Circle({ width: 5, height: 5 })
            .fill(Tokens.orange)
          Text(this.t('items', this.dueItems().length))
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor('#9B5C00')
            .margin({ left: 6 })
        }
        .height(30)
        .padding({ left: 11, right: 11 })
        .backgroundColor(Tokens.surfaceSoft)
        .borderWidth(1)
        .borderColor('#A6FFC531')
        .borderRadius(15)
        .margin({ left: 12 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: this.isWide ? 10 : 8, bottom: 22 })

      Scroll() {
        Column({ space: 12 }) {
          if (this.dueItems().length === 0) {
            this.EmptyToday()
          } else {
            ForEach(this.dueItems(), (item: StudyItem, index: number) => {
              Column() {
                this.ReviewRow(item)
              }
              .width('100%')
              .translate({ y: (1 - this.calendarProgress) * (18 + index * 4) })
              .opacity(Math.min(1, this.calendarProgress))
            }, (item: StudyItem) => item.id)
          }
          if (this.dueItems().length === 0 && this.todayCreatedItems().length > 0 && !this.isWide) {
            Row()
              .width('100%')
              .height(90)
          }
          if (this.todayCreatedItems().length > 0) {
            this.TodayLogged()
          }
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .padding({ bottom: 24 })
      }
      .width('100%')
      .layoutWeight(1)
      .opacity(this.listOpacity)
      .translate({ y: this.listShift })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .layoutWeight(1)
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .opacity(this.pageOpacity)
    .translate({ x: this.pageShift })
    .clip(true)
    .padding({
      left: this.isWide ? 44 : 20,
      right: this.isWide ? 24 : 20,
      top: this.isWide ? 10 : 8,
      bottom: this.isWide ? 24 : 12
    })
    .clip(true)
  }

  @Builder EmptyToday() {
    Column() {
      Text(this.t('todayEmptyTitle'))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Tokens.inkSoft)
      Text(this.t('todayEmptyBody'))
        .fontSize(11)
        .fontColor(Tokens.muted)
        .margin({ top: 8 })
      Button(this.t('newEntry'))
        .height(38)
        .fontSize(12)
        .fontColor('#3D2A00')
        .backgroundColor(Tokens.yellow)
        .borderRadius(19)
        .padding({ left: 18, right: 18 })
        .margin({ top: 18 })
        .onClick(() => {
          if (this.isWide) {
            focusControl.requestFocus('titleInput');
          } else {
            this.openComposer();
          }
        })
    }
    .width('100%')
    .height(230)
    .justifyContent(FlexAlign.Center)
  }

  @Builder TodayLogged() {
    Column({ space: 8 }) {
      Row() {
        Text(this.t('todayLogged'))
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(Tokens.inkSoft)
        Text(this.t('items', this.todayCreatedItems().length))
          .fontSize(9)
          .fontColor(Tokens.mutedSoft)
          .margin({ left: 7 })
        Blank()
        Text(this.t('seeAll'))
          .fontSize(9)
          .fontColor('#B16A0A')
          .onClick(() => {
            this.switchTab(1);
          })
      }
      .width('100%')
      .margin({ top: 8, bottom: 2 })

      ForEach(this.todayCreatedItems(), (item: StudyItem, index: number) => {
        Row() {
          Circle({ width: 7, height: 7 })
            .fill(this.findSubject(item.subjectId).color)
          Column() {
            Text(item.title)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Tokens.ink)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.findSubject(item.subjectId).name + '  ·  ' + this.t('next') + ' ' + formatShort(item.nextReviewAt))
              .fontSize(9)
              .fontColor(Tokens.muted)
              .margin({ top: 3 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 10 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .backgroundColor(Tokens.surface)
        .borderRadius(16)
        .borderWidth(1)
        .borderColor('#B3FFFFFF')
        .translate({ y: (1 - this.calendarProgress) * (18 + index * 4) })
        .opacity(Math.min(1, this.calendarProgress))
        .onClick(() => {
          this.openItemActions(item);
        })
        .gesture(LongPressGesture().onAction(() => {
          this.openItemActions(item);
        }))
      }, (item: StudyItem) => item.id)
    }
    .width('100%')
  }

  @Builder ReviewRow(item: StudyItem) {
    Row() {
      Stack() {
        Circle({ width: 28, height: 28 })
          .fill(Color.Transparent)
          .stroke(this.findSubject(item.subjectId).color)
          .strokeWidth(2)
        Circle({ width: 8, height: 8 })
          .fill(this.findSubject(item.subjectId).color)
      }
      .width(30)
      .height(30)

      Column() {
        Row() {
          Text(this.findSubject(item.subjectId).name)
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor(Tokens.muted)
          Text(item.scheduleMode === 'fixed' ? this.t('fixed') : this.t('curve'))
            .fontSize(9)
            .fontColor(Tokens.mutedSoft)
            .margin({ left: 8 })
        }
        Text(item.title)
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor(Tokens.ink)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
        Text(this.itemSubtitle(item))
          .fontSize(11.5)
          .fontColor(Tokens.muted)
          .margin({ top: 4 })
        Row() {
          Row()
            .width(this.progressFor(item) + '%')
            .height(3)
            .backgroundColor(this.findSubject(item.subjectId).color)
            .borderRadius(2)
        }
        .width('100%')
        .height(3)
        .backgroundColor('#0D5E4B30')
        .borderRadius(2)
        .margin({ top: 10 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 14, right: 12 })

      Button(this.t('review'))
        .height(32)
        .fontSize(10.5)
        .fontColor(Tokens.inkSoft)
        .backgroundColor(Tokens.surface)
        .borderWidth(1)
        .borderColor(Tokens.line)
        .borderRadius(16)
        .padding({ left: 12, right: 12 })
        .onClick(() => {
          this.openReview(item);
        })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(Tokens.surfaceSoft)
    .borderRadius(22)
    .borderWidth(1)
    .borderColor('#B3FFFFFF')
    .shadow({ radius: 24, color: Tokens.shadow, offsetX: 0, offsetY: 8 })
    .backdropBlur(18)
    .scale({ x: this.pressedItemId === item.id ? 0.985 : 1, y: this.pressedItemId === item.id ? 0.985 : 1 })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        animateTo({ duration: 90, curve: Curve.EaseOut }, () => {
          this.pressedItemId = item.id;
        });
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        animateTo({ duration: 160, curve: Curve.EaseOut }, () => {
          this.pressedItemId = '';
        });
      }
    })
  }

  @Builder ComposerPane(showClose: boolean) {
    Column() {
      Row() {
        Text(this.t('newEntry'))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Tokens.ink)
          .letterSpacing(-0.6)
        Blank()
        Column() {
          Text(formatShort(Date.now()))
            .fontSize(7.5)
            .fontColor(Tokens.mutedSoft)
          Text(weekdayCN(Date.now()))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Tokens.inkSoft)
            .margin({ top: 3 })
        }
        if (showClose) {
          Button(this.t('close'))
            .height(26)
            .fontSize(9)
            .fontColor('#6C4B00')
            .backgroundColor(Tokens.yellowSoft)
            .borderRadius(13)
            .padding({ left: 10, right: 10 })
            .margin({ left: 10 })
            .onClick(() => {
              this.closeComposer();
            })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .margin({ bottom: 16 })

      Text(this.t('subject'))
        .fontSize(9)
        .fontColor(Tokens.muted)
        .margin({ bottom: 8 })

      Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        ForEach(this.subjects, (subject: Subject) => {
          Button(subject.name)
            .height(31)
            .fontSize(11)
            .fontColor(this.draftSubjectId === subject.id ? '#3D2A00' : Tokens.inkSoft)
            .backgroundColor(this.draftSubjectId === subject.id ? Tokens.yellow : Tokens.surface)
            .borderWidth(1)
            .borderColor(this.draftSubjectId === subject.id ? '#CCFFC531' : Tokens.line)
            .borderRadius(16)
            .padding({ left: 12, right: 12 })
            .margin({ right: 6, bottom: 6 })
            .scale({ x: this.draftSubjectId === subject.id ? 1.04 : 1, y: this.draftSubjectId === subject.id ? 1.04 : 1 })
            .animation({ duration: 180, curve: Curve.EaseOut })
            .onClick(() => {
              this.draftSubjectId = subject.id;
            })
        }, (subject: Subject) => subject.id)
      }
      .width('100%')
      .margin({ bottom: 18 })

      Text(this.t('chapter'))
        .fontSize(9)
        .fontColor(Tokens.muted)
        .margin({ bottom: 8 })

      TextInput({ placeholder: this.t('titlePlaceholder'), text: this.draftTitle })
        .id('titleInput')
        .height(50)
        .fontSize(20)
        .fontColor(Tokens.ink)
        .placeholderColor(Tokens.mutedSoft)
        .caretColor(Tokens.orange)
        .backgroundColor(Tokens.surface)
        .borderWidth(1)
        .borderColor(this.titleBorderColor)
        .borderRadius(14)
        .padding({ left: 14, right: 14 })
        .focusBox({ margin: LengthMetrics.vp(0), strokeWidth: LengthMetrics.vp(0) })
        .onFocus(() => {
          this.titleFocused = true;
          animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
            this.titleBorderColor = '#C9A24A';
          });
        })
        .onBlur(() => {
          this.titleFocused = false;
          animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
            this.titleBorderColor = '#B3FFFFFF';
          });
        })
        .onChange((value: string) => {
          this.draftTitle = value;
        })

      Text(this.t('plan'))
        .fontSize(9)
        .fontColor(Tokens.muted)
        .margin({ top: 18, bottom: 8 })

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('50%')
          .height(32)
          .backgroundColor(Tokens.surface)
          .borderRadius(9)
          .translate({ x: this.draftMode === 'curve' ? 0 : '100%' })
          .animation({ duration: 220, curve: Curve.EaseOut })

        Row() {
          Button(this.t('curve'))
            .layoutWeight(1)
            .height(32)
            .fontSize(11)
            .fontColor(this.draftMode === 'curve' ? Tokens.ink : Tokens.muted)
            .backgroundColor(Color.Transparent)
            .borderRadius(9)
            .animation({ duration: 180, curve: Curve.EaseOut })
            .onClick(() => {
              this.draftMode = 'curve';
              this.playDots();
            })
          Button(this.t('fixed'))
            .layoutWeight(1)
            .height(32)
            .fontSize(11)
            .fontColor(this.draftMode === 'fixed' ? Tokens.ink : Tokens.muted)
            .backgroundColor(Color.Transparent)
            .borderRadius(9)
            .animation({ duration: 180, curve: Curve.EaseOut })
            .onClick(() => {
              this.draftMode = 'fixed';
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding(3)
      .backgroundColor('#EBDFC6')
      .borderRadius(12)

      Stack({ alignContent: Alignment.TopStart }) {
        Row() {
          ForEach(this.curveLabels(), (label: string, index: number) => {
            Column() {
              Circle({ width: 8, height: 8 })
                .fill(index === 0 ? Tokens.orange : Tokens.surface)
                .stroke(index === 0 ? Tokens.orange : '#80FF9C2C')
                .strokeWidth(1.5)
              Text(label)
                .fontSize(7.5)
                .fontColor(index === 0 ? '#B16A0A' : Tokens.mutedSoft)
                .margin({ top: 5 })
            }
            .layoutWeight(1)
            .opacity(this.dotVisible > index ? 1 : 0)
            .translate({ y: this.dotVisible > index ? 0 : 10 })
            .scale({ x: this.dotVisible > index ? 1 : 0.5, y: this.dotVisible > index ? 1 : 0.5 })
            .animation({ duration: 220, curve: Curve.EaseOut })
          })
        }
        .width('100%')
        .margin({ top: 12 })
        .opacity(this.draftMode === 'curve' ? 1 : 0)
        .scale({ x: this.draftMode === 'curve' ? 1 : 0.96, y: this.draftMode === 'curve' ? 1 : 0.96 })
        .translate({ y: this.draftMode === 'curve' ? 0 : -4 })
        .enabled(this.draftMode === 'curve')
        .animation({ duration: 220, curve: Curve.EaseOut })

        Row() {
          Text(this.t('every'))
            .fontSize(11)
            .fontColor(Tokens.muted)
          Stack({ alignContent: Alignment.Center }) {
            Text('−')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#6C4B00')
          }
          .width(26)
          .height(26)
          .backgroundColor('#FBF4E5')
          .borderWidth(1)
          .borderColor('#DCC49A')
          .borderRadius(13)
          .margin({ left: 10, right: 8 })
          .onClick(() => {
            this.draftFixedDays = Math.max(1, this.draftFixedDays - 1);
          })
          TextInput({ text: this.draftFixedDays + '' })
            .width(52)
            .height(30)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(Tokens.ink)
            .textAlign(TextAlign.Center)
            .maxLength(2)
            .backgroundColor(Tokens.surface)
            .borderRadius(8)
            .onChange((value: string) => {
              const days = Number(value);
              if (!isNaN(days) && days >= 1) {
                this.draftFixedDays = Math.min(90, Math.round(days));
              }
            })
          Text(this.t('dayUnit'))
            .fontSize(11)
            .fontColor(Tokens.muted)
            .margin({ left: 4 })
          Stack({ alignContent: Alignment.Center }) {
            Text('+')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#6C4B00')
          }
          .width(26)
          .height(26)
          .backgroundColor('#FBF4E5')
          .borderWidth(1)
          .borderColor('#DCC49A')
          .borderRadius(13)
          .margin({ left: 8 })
          .onClick(() => {
            this.draftFixedDays = Math.min(90, this.draftFixedDays + 1);
          })
        }
        .width('100%')
        .margin({ top: 10 })
        .opacity(this.draftMode === 'fixed' ? 1 : 0)
        .scale({ x: this.draftMode === 'fixed' ? 1 : 0.96, y: this.draftMode === 'fixed' ? 1 : 0.96 })
        .translate({ y: this.draftMode === 'fixed' ? 0 : 4 })
        .enabled(this.draftMode === 'fixed')
        .animation({ duration: 220, curve: Curve.EaseOut })
      }
      .width('100%')
      .height(this.draftMode === 'fixed' ? 52 : 40)
      .clip(true)
      .animation({ duration: 280, curve: Curve.EaseInOut })

      Row() {
        Column() {
          Text(this.t('remindMe'))
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(Tokens.inkSoft)
          Text(this.settings.reminderTime)
            .fontSize(12)
            .fontColor(Tokens.muted)
            .margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: this.settings.reminderEnabled })
          .selectedColor(Tokens.yellow)
          .onChange((value: boolean) => {
            this.updateReminderEnabled(value);
          })
      }
      .width('100%')
      .padding(13)
      .backgroundColor(Tokens.yellowSoft)
      .borderWidth(1)
      .borderColor('#4DFFD687')
      .borderRadius(15)
      .margin({ top: 14 })

      Button(this.t('save'))
        .width('100%')
        .height(50)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3D2A00')
        .backgroundColor(Tokens.yellow)
        .borderRadius(15)
        .margin({ top: 14 })
        .onClick(() => {
          this.addItem();
        })

      Text(this.t('localOnly'))
        .fontSize(8.5)
        .fontColor(Tokens.mutedSoft)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 10 })
    }
    .width(this.isWide ? 400 : '100%')
    .alignItems(HorizontalAlign.Start)
    .padding(24)
    .backgroundColor(Tokens.surfaceSoft)
    .borderRadius(26)
    .borderWidth(1)
    .borderColor('#CCFFFFFF')
    .shadow({ radius: 32, color: Tokens.shadow, offsetX: 0, offsetY: 16 })
    .backdropBlur(22)
    .opacity(this.formProgress)
    .translate({ y: (1 - this.formProgress) * 18 })
  }

  @Builder OtherPage() {
    if (this.tab === 1) {
      this.RecordsPage()
    } else if (this.tab === 2) {
      this.CalendarPage()
    } else {
      this.SettingsPage()
    }
  }

  @Builder RecordsPage() {
    Column() {
      Row() {
        Text(this.t('recordsTitle'))
          .fontSize(this.isWide ? 44 : 32)
          .fontWeight(FontWeight.Bold)
          .fontColor(Tokens.ink)
        Blank()
        Text(this.t('longPressManage'))
          .fontSize(9)
          .fontColor(Tokens.mutedSoft)
          .margin({ right: 10 })
        Text(this.t('items', this.items.length))
          .fontSize(11)
          .fontColor(Tokens.muted)
      }
      .width('100%')
      .margin({ top: 24, bottom: 18 })

      if (this.items.length === 0) {
        Text(this.t('noRecords'))
          .fontSize(14)
          .fontColor(Tokens.muted)
          .margin({ top: 80 })
      } else {
        List({ space: 10 }) {
          ForEach(this.sortedItems(), (item: StudyItem, index: number) => {
            ListItem() {
              Row() {
                Column() {
                  Text(formatShort(item.createdAt))
                    .fontSize(11)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Tokens.muted)
                  Text(weekdayCN(item.createdAt))
                    .fontSize(9)
                    .fontColor(Tokens.mutedSoft)
                    .margin({ top: 2 })
                }
                .width(54)
                .alignItems(HorizontalAlign.Start)

                Column() {
                  Text(this.findSubject(item.subjectId).name)
                    .fontSize(9.5)
                    .fontColor(this.findSubject(item.subjectId).color)
                  Text(item.title)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Tokens.ink)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 3 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Column() {
                  Text(this.t('next'))
                    .fontSize(8)
                    .fontColor(Tokens.mutedSoft)
                  Text(formatShort(item.nextReviewAt))
                    .fontSize(10)
                    .fontColor(Tokens.muted)
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.End)
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Tokens.surfaceSoft)
              .borderRadius(18)
              .borderWidth(1)
              .borderColor('#B3FFFFFF')
              .translate({ y: (1 - this.calendarProgress) * (16 + index * 4) })
              .opacity(Math.min(1, this.calendarProgress))
              .onClick(() => {
                this.openItemActions(item);
              })
              .gesture(LongPressGesture().onAction(() => {
                this.openItemActions(item);
              }))
            }
          }, (item: StudyItem) => item.id)
        }
        .layoutWeight(1)
        .width('100%')
        .opacity(this.listOpacity)
        .translate({ y: this.listShift })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .opacity(this.pageOpacity)
    .translate({ x: this.pageShift })
    .clip(true)
    .padding({ left: this.isWide ? 52 : 20, right: this.isWide ? 52 : 20, top: 6, bottom: 24 })
  }

  @Builder CalendarPage() {
    Column() {
      Text(this.t('calendarTitle'))
        .fontSize(this.isWide ? 44 : 32)
        .fontWeight(FontWeight.Bold)
        .fontColor(Tokens.ink)
        .margin({ top: 24 })
      Text(this.t('next7'))
        .fontSize(11)
        .fontColor(Tokens.muted)
        .margin({ top: 6, bottom: 18 })

      Scroll() {
        Column({ space: 8 }) {
          ForEach(this.upcoming(), (day: DayCount, index: number) => {
            Row() {
              Column() {
                Text(formatShort(day.date))
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Tokens.ink)
                Text(weekdayCN(day.date))
                  .fontSize(9)
                  .fontColor(Tokens.muted)
                  .margin({ top: 2 })
              }
              .width(64)
              .alignItems(HorizontalAlign.Start)

              Row() {
                if (day.count === 0) {
                  Text(this.t('noPlan'))
                    .fontSize(11)
                    .fontColor(Tokens.mutedSoft)
                } else {
                  ForEach(this.items.filter((value: StudyItem) => value.status === 'active' && startOfDay(new Date(value.nextReviewAt)).getTime() === day.date), (item: StudyItem) => {
                    Row() {
                      Circle({ width: 6, height: 6 })
                        .fill(this.findSubject(item.subjectId).color)
                      Text(item.title)
                        .fontSize(11)
                        .fontColor(Tokens.inkSoft)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .margin({ left: 7 })
                    }
                    .padding({ left: 9, right: 9, top: 6, bottom: 6 })
                    .backgroundColor(Tokens.surface)
                    .borderRadius(10)
                    .margin({ right: 6 })
                  }, (item: StudyItem) => item.id)
                }
              }
              .layoutWeight(1)
            }
            .width('100%')
            .padding(16)
            .backgroundColor(Tokens.surfaceSoft)
            .borderRadius(18)
            .borderWidth(1)
            .borderColor('#B3FFFFFF')
            .opacity(this.calendarAlpha[index])
            .translate({ x: this.calendarX[index] })
          }, (day: DayCount) => '' + day.date)
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .padding({ bottom: 24 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .opacity(this.pageOpacity)
    .translate({ x: this.pageShift })
    .clip(true)
    .padding({ left: this.isWide ? 52 : 20, right: this.isWide ? 52 : 20, bottom: 24 })
  }

  @Builder SettingsPage() {
    Column() {
      Text(this.t('settingsTitle'))
        .fontSize(this.isWide ? 44 : 32)
        .fontWeight(FontWeight.Bold)
        .fontColor(Tokens.ink)
        .margin({ top: 24, bottom: 18 })

      Scroll() {
        Column({ space: 16 }) {
          Column() {
            Row() {
              Column() {
                Text(this.t('remindMe'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Tokens.ink)
            Text(this.t('reminderSub'))
              .fontSize(9.5)
              .fontColor(Tokens.muted)
              .margin({ top: 3 })
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.settings.reminderEnabled })
            .selectedColor(Tokens.yellow)
            .onChange((value: boolean) => {
              this.updateReminderEnabled(value);
            })
        }
        .width('100%')

        Row() {
          Text(this.t('reminderTime'))
            .fontSize(11)
            .fontColor(Tokens.muted)
          Blank()
          TextInput({ text: this.settings.reminderTime })
            .width(84)
            .height(34)
            .fontSize(12)
            .fontColor(Tokens.inkSoft)
            .textAlign(TextAlign.End)
            .backgroundColor(Tokens.surface)
            .borderRadius(10)
            .onChange((value: string) => {
              this.updateReminderTime(value);
            })
        }
        .width('100%')
        .margin({ top: 16 })

        Row() {
          Text(this.t('reminderMethod'))
            .fontSize(10)
            .fontColor(Tokens.muted)
          Blank()
          Text(this.reminderMode === 'calendar' ? this.t('systemCalendar') : (this.reminderMode === 'off' ? this.t('off') : this.t('unscheduled')))
            .fontSize(10)
            .fontColor(this.reminderMode === 'calendar' ? '#6E8C4D' : Tokens.mutedSoft)
          Text('  ·  ' + this.t('schedules', this.reminderCount > 0 ? this.reminderCount : 0))
            .fontSize(9)
            .fontColor(Tokens.mutedSoft)
        }
        .width('100%')
        .margin({ top: 10 })

        if (this.reminderError.length > 0) {
          Text(this.reminderError)
            .fontSize(8.5)
            .fontColor('#C7422C')
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 6 })
        }

        Button(this.t('saveSettings'))
          .width('100%')
          .height(42)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#3D2A00')
          .backgroundColor(Tokens.yellow)
          .borderRadius(13)
          .margin({ top: 16 })
          .onClick(() => {
            this.saveSettings();
          })
      }
      .width('100%')
      .padding(18)
      .backgroundColor(Tokens.surfaceSoft)
      .borderRadius(22)
      .borderWidth(1)
      .borderColor('#B3FFFFFF')
      .translate({ y: (1 - this.calendarProgress) * 14 })
      .opacity(Math.min(1, this.calendarProgress))

      Column() {
        Text(this.t('curveDaysTitle'))
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(Tokens.muted)
          .margin({ bottom: 10 })
        Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach([0, 1, 2, 3, 4, 5, 6], (index: number) => {
            Column() {
              Text((index + 1) + '')
                .fontSize(8)
                .fontColor(Tokens.mutedSoft)
                .margin({ bottom: 3 })
              Stack({ alignContent: Alignment.Center }) {
                Text(this.settings.curveDays[index] + '')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Tokens.ink)
              }
              .width(48)
              .height(32)
              .backgroundColor(Tokens.surface)
              .borderWidth(1)
              .borderColor('#E6DCC8')
              .borderRadius(8)
              .onClick(() => {
                this.openCurvePicker(index);
              })
            }
            .margin({ right: 8, bottom: 8 })
          })
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(18)
      .backgroundColor(Tokens.surfaceSoft)
      .borderRadius(22)
      .borderWidth(1)
      .borderColor('#B3FFFFFF')
      .translate({ y: (1 - this.calendarProgress) * 16 })
      .opacity(Math.min(1, this.calendarProgress))

      Column() {
        Text(this.t('subject'))
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(Tokens.muted)
          .margin({ bottom: 10 })

        Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach(this.subjects, (subject: Subject) => {
            Row() {
              Circle({ width: 7, height: 7 })
                .fill(subject.color)
              Text(subject.name)
                .fontSize(10)
                .fontColor(Tokens.inkSoft)
                .margin({ left: 6 })
              Text('×')
                .fontSize(11)
                .fontColor(Tokens.mutedSoft)
                .margin({ left: 6 })
                .onClick(() => {
                  this.confirmDeleteSubject(subject);
                })
            }
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .backgroundColor(Tokens.surface)
            .borderRadius(12)
            .borderWidth(1)
            .borderColor('#B3FFFFFF')
            .margin({ right: 6, bottom: 6 })
          }, (subject: Subject) => subject.id)
        }
        .width('100%')

        Row() {
          TextInput({ text: this.newSubjectName })
            .layoutWeight(1)
            .height(36)
            .fontSize(12)
            .fontColor(Tokens.ink)
            .placeholderColor(Tokens.mutedSoft)
            .backgroundColor(Tokens.surface)
            .borderWidth(1)
            .borderColor('#E6DCC8')
            .borderRadius(10)
            .padding({ left: 12, right: 12 })
            .onChange((value: string) => {
              this.newSubjectName = value;
            })
          Button(this.t('addSubject'))
            .height(36)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor('#3D2A00')
            .backgroundColor(Tokens.yellow)
            .borderRadius(10)
            .padding({ left: 16, right: 16 })
            .margin({ left: 8 })
            .onClick(() => {
              this.addSubject();
            })
        }
        .width('100%')
        .margin({ top: 6 })

      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(18)
      .backgroundColor(Tokens.surfaceSoft)
      .borderRadius(22)
      .borderWidth(1)
      .borderColor('#B3FFFFFF')
      .translate({ y: (1 - this.calendarProgress) * 20 })
      .opacity(Math.min(1, this.calendarProgress))

      Column() {
        Text(this.t('palette'))
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(Tokens.muted)
        Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          ForEach(['奶油', '雾蓝', '暖砂', '鼠尾草'], (name: string, index: number) => {
            Column() {
              Row({ space: 6 }) {
                Row()
                  .width(26)
                  .height(26)
                  .backgroundColor(this.themeAccent(index))
                  .borderRadius(8)
                Row({ space: 3 }) {
                  ForEach([0, 1, 2, 3], (slot: number) => {
                    Circle({ width: 13, height: 13 })
                      .fill(this.pageColors(index)[slot])
                      .stroke('#44000000')
                      .strokeWidth(1)
                  })
                }
              }
            }
            .width(this.isTablet ? '24%' : '48%')
            .height(46)
            .margin({ bottom: 8 })
            .justifyContent(FlexAlign.Center)
            .backgroundColor(Tokens.surface)
            .borderRadius(12)
            .borderWidth(this.settings.themeIndex === index ? 2 : 1)
            .borderColor(this.settings.themeIndex === index ? '#E8A21A' : '#E6DCC8')
            .scale({ x: this.settings.themeIndex === index ? 1.02 : 1, y: this.settings.themeIndex === index ? 1.02 : 1 })
            .animation({ duration: 240, curve: Curve.EaseOut })
            .onClick(() => {
              this.updateTheme(index);
            })
          }, (name: string, index: number) => name)
        }
        .width('100%')
        .margin({ top: 10 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(18)
      .backgroundColor(Tokens.surfaceSoft)
      .borderRadius(22)
      .borderWidth(1)
      .borderColor('#B3FFFFFF')
      .translate({ y: (1 - this.calendarProgress) * 14 })
      .opacity(Math.min(1, this.calendarProgress))

      Column() {
        Text(this.t('language'))
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(Tokens.muted)
          .margin({ bottom: 10 })
        Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach(I18n.languages, (option: LanguageOption) => {
            Button(option.name)
              .height(30)
              .fontSize(10)
              .fontColor(this.settings.language === option.code ? '#3D2A00' : Tokens.inkSoft)
              .backgroundColor(this.settings.language === option.code ? Tokens.yellow : Tokens.surface)
              .borderWidth(1)
              .borderColor(this.settings.language === option.code ? '#CCFFC531' : '#E6DCC8')
              .borderRadius(15)
              .padding({ left: 12, right: 12 })
              .margin({ right: 6, bottom: 6 })
              .scale({ x: this.settings.language === option.code ? 1.04 : 1, y: this.settings.language === option.code ? 1.04 : 1 })
              .animation({ duration: 180, curve: Curve.EaseOut })
              .onClick(() => {
                this.setLanguage(option.code);
              })
          }, (option: LanguageOption) => option.code)
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(18)
      .backgroundColor(Tokens.surfaceSoft)
      .borderRadius(22)
      .borderWidth(1)
      .borderColor('#B3FFFFFF')
      .translate({ y: (1 - this.calendarProgress) * 18 })
      .opacity(Math.min(1, this.calendarProgress))


        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
        .constraintSize({ minHeight: '100%' })
        .padding({ bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .opacity(this.pageOpacity)
    .translate({ x: this.pageShift })
    .clip(true)
    .padding({ left: this.isWide ? 52 : 20, right: this.isWide ? 52 : 20, bottom: 24 })
  }

  @Builder BottomNav() {
    Row() {
      ForEach([0, 1, 2, 3], (index: number) => {
        Column() {
          Image(this.tab === index ? this.navIcons[index] : this.navIconsMuted[index])
            .width(22)
            .height(22)
            .objectFit(ImageFit.Contain)
    
          Text(this.navLabel(index))
            .fontSize(8)
            .fontColor(this.tab === index ? '#6C4B00' : Tokens.mutedSoft)
            .margin({ top: 3 })
            .animation({ duration: 180, curve: Curve.EaseOut })
        }
        .layoutWeight(1)
        .height(62)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.switchTab(index);
        })
      })
    }
    .width('92%')
    .height(60)
    .padding({ left: 8, right: 8 })
    .backgroundColor(Tokens.surface)
    .borderRadius(30)
    .borderWidth(1)
    .borderColor('#CCFFFFFF')
    .shadow({ radius: 22, color: '#1A000000', offsetX: 0, offsetY: 8 })
    .margin({ bottom: 18 })
  }

  @Builder ReviewOverlay() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Tokens.dim)

      Column() {
        if (this.isWide) {
          Row({ space: 48 }) {
            this.ReviewCard()
            this.CurvePanel()
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
        } else {
          Column({ space: 16 }) {
            this.ReviewCard()
            this.CurvePanel()
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Start)
          .backgroundColor(this.pageBg())
    .animation({ duration: 320, curve: Curve.EaseOut })
          .padding({ left: 12, right: 12, top: 10, bottom: 12 })
          .borderRadius(28)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: this.isWide ? 40 : 16, right: this.isWide ? 40 : 16, top: 10, bottom: 20 })
      .backgroundColor(this.isWide ? '#00000000' : Tokens.bg)
    }
    .width('100%')
    .height('100%')
    .scale({ x: this.reviewScale, y: this.reviewScale })
  }

  @Builder ReviewCard() {
    Column() {
      Row() {
        Text(this.findSubject(this.reviewItem.subjectId).name)
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor(Tokens.muted)
        Text(this.t('reviewN', this.reviewItem.reviewCount + 1))
          .fontSize(9)
          .fontColor(Tokens.mutedSoft)
          .margin({ left: 8 })
        Blank()
        Text((this.reviewItem.reviewCount + 1) + ' / 06')
          .fontSize(9)
          .fontColor(Tokens.mutedSoft)
        Button(this.t('close'))
          .height(26)
          .fontSize(9)
          .fontColor('#6C4B00')
          .backgroundColor(Tokens.yellowSoft)
          .borderRadius(13)
          .padding({ left: 10, right: 10 })
          .margin({ left: 10 })
          .onClick(() => {
            this.showReview = false;
          })
      }
      .width('100%')

      Text(this.reviewItem.title)
        .width('100%')
        .fontSize(this.isWide ? 38 : 30)
        .fontWeight(FontWeight.Bold)
        .fontColor(Tokens.ink)
        .letterSpacing(-1)
        .margin({ top: 14 })
      Text(this.t('lastReview', formatShort(this.reviewItem.lastReviewedAt > 0 ? this.reviewItem.lastReviewedAt : this.reviewItem.createdAt)))
        .width('100%')
        .fontSize(10.5)
        .fontColor(Tokens.muted)
        .margin({ top: 8 })

      Row()
        .width('100%')
        .height(1)
        .backgroundColor(Tokens.line)
        .margin({ top: 22, bottom: 18 })

      Text(this.t('howRemember'))
        .width('100%')
        .fontSize(11)
        .fontColor(Tokens.muted)
      Text(this.t('autoNext'))
        .width('100%')
        .fontSize(8)
        .fontColor(Tokens.mutedSoft)
        .margin({ top: 4, bottom: 12 })

      Row({ space: 8 }) {
        this.RateButton(this.t('forgot'), this.intervalHint('forgot'), 'forgot', '#D95F3F')
        this.RateButton(this.t('fuzzy'), this.intervalHint('fuzzy'), 'fuzzy', '#B17A12')
        this.RateButton(this.t('got'), this.intervalHint('got'), 'got', '#8F5600')
      }
      .width('100%')
    }
    .width(this.isWide ? 680 : '100%')
    .padding(this.isWide ? 32 : 22)
    .backgroundColor(Tokens.surface)
    .borderRadius(28)
    .borderWidth(1)
    .borderColor('#CCFFFFFF')
    .shadow({ radius: 40, color: '#24000000', offsetX: 0, offsetY: 20 })
  }

  @Builder RateButton(label: string, hint: string, rating: string, color: string) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(hint)
        .fontSize(8)
        .fontColor(Tokens.mutedSoft)
        .margin({ top: 3 })
    }
    .layoutWeight(1)
    .height(58)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.pressedRating === rating ? Tokens.yellow : '#FFF7DF')
    .borderWidth(1)
    .borderColor('#F0D9A8')
    .borderRadius(13)
    .scale({ x: this.pressedRating === rating ? 0.96 : 1, y: this.pressedRating === rating ? 0.96 : 1 })
    .onClick(() => {
      this.finishReview(rating);
    })
  }

  @Builder CurvePanel() {
    Column() {
      Text(this.t('memoryCurve'))
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(Tokens.ink)
        .letterSpacing(-0.6)
      Text(this.t('reviewInterval', this.reviewItem.reviewCount + 1, this.reviewItem.currentIntervalDays))
        .fontSize(10.5)
        .fontColor(Tokens.muted)
        .margin({ top: 6, bottom: 16 })

      Stack() {
        Row()
          .width('100%')
          .height(1)
          .backgroundColor(Tokens.line)
          .margin({ top: 7 })
        Row() {
          ForEach(this.curveNodes, (index: number) => {
            Column() {
              if (index < 3) {
                Circle({ width: 10, height: 10 }).fill(Tokens.yellow)
              } else if (index === 3) {
                Circle({ width: 12, height: 12 })
                  .fill(Tokens.surface)
                  .stroke(Tokens.orange)
                  .strokeWidth(2)
              } else {
                Circle({ width: 9, height: 9 })
                  .fill(Tokens.surface)
                  .stroke('#475E4B30')
                  .strokeWidth(1.5)
              }
              Text(this.curveLabels()[index])
                .fontSize(7)
                .fontColor(index === 3 ? '#B16A0A' : Tokens.mutedSoft)
                .margin({ top: 8 })
            }
            .layoutWeight(1)
          })
        }
        .width('100%')
      }
      .width('100%')
      .height(48)

      Row() {
        Row() {
          Circle({ width: 5, height: 5 }).fill(Tokens.orange)
          Text(this.t('lastPrefix', this.lastRating(this.reviewItem.id)))
            .fontSize(9)
            .fontColor(Tokens.muted)
            .margin({ left: 6 })
        }
        Blank()
        Text(this.t('days', this.lastInterval(this.reviewItem.id)) + '  →  ' + this.t('days', this.reviewItem.currentIntervalDays))
          .fontSize(9)
          .fontColor(Tokens.muted)
      }
      .width('100%')
      .padding(12)
      .backgroundColor(Tokens.surfaceSoft)
      .borderRadius(12)
      .margin({ top: 12 })
    }
    .width(this.isWide ? 360 : '100%')
    .padding(20)
    .backgroundColor('#FFFDF8')
    .borderRadius(22)
    .borderWidth(1)
    .borderColor('#FFFFFF')
  }

  @Builder CurvePickerOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Tokens.dim)
        .backdropBlur(6)
        .onClick(() => {
          this.closeCurvePicker();
        })

      Column() {
        Text(this.t('curveDayTitle', this.curvePickIndex + 1))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Tokens.ink)
          .width('100%')
        Text(this.curvePickValue + ' ' + this.t('dayUnit'))
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(Tokens.yellow)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 12, bottom: 8 })
        Slider({
          value: this.curvePickValue,
          min: 1,
          max: 90,
          step: 1,
          style: SliderStyle.OutSet
        })
          .width('100%')
          .selectedColor(Tokens.yellow)
          .blockColor(Tokens.yellow)
          .trackColor('#E6DCC8')
          .onChange((value: number, mode: SliderChangeMode) => {
            this.curvePickValue = Math.round(value);
          })
        Row() {
          Text('1')
            .fontSize(9)
            .fontColor(Tokens.mutedSoft)
          Blank()
          Text('90')
            .fontSize(9)
            .fontColor(Tokens.mutedSoft)
        }
        .width('100%')

        Row({ space: 10 }) {
          Button(this.t('cancel'))
            .layoutWeight(1)
            .height(42)
            .fontSize(12)
            .fontColor(Tokens.inkSoft)
            .backgroundColor(Tokens.surfaceSoft)
            .borderRadius(12)
            .onClick(() => {
              this.closeCurvePicker();
            })
          Button(this.t('save'))
            .layoutWeight(1)
            .height(42)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#3D2A00')
            .backgroundColor(Tokens.yellow)
            .borderRadius(12)
            .onClick(() => {
              this.confirmCurvePicker();
            })
        }
        .width('100%')
        .margin({ top: 18 })
      }
      .width(this.isWide ? 420 : '84%')
      .padding(24)
      .backgroundColor(Tokens.surface)
      .borderRadius(24)
      .borderWidth(1)
      .borderColor('#CCFFFFFF')
      .shadow({ radius: 40, color: '#24000000', offsetX: 0, offsetY: 20 })
      .scale({ x: this.curvePickScale, y: this.curvePickScale })
    }
    .width('100%')
    .height('100%')
  }

  @Builder ConfirmOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Tokens.dim)
        .backdropBlur(6)
        .onClick(() => {
          this.cancelConfirm();
        })

      Column() {
        Text(this.confirmTitle)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(Tokens.ink)
          .width('100%')
        Text(this.confirmMessage)
          .fontSize(11)
          .fontColor(Tokens.muted)
          .lineHeight(18)
          .width('100%')
          .margin({ top: 10, bottom: 18 })
        Button(this.confirmKind === 'subject' ? this.t('deleteSubjectTitle') : this.t('deleteRecordTitle'))
          .width('100%')
          .height(46)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#3D2A00')
          .backgroundColor(Tokens.yellow)
          .borderRadius(14)
          .onClick(() => {
            this.executeConfirm();
          })
        Button(this.t('cancel'))
          .width('100%')
          .height(38)
          .fontSize(12)
          .fontColor(Tokens.muted)
          .backgroundColor(Color.Transparent)
          .margin({ top: 4 })
          .onClick(() => {
            this.cancelConfirm();
          })
      }
      .width(this.isWide ? 440 : '88%')
      .padding(24)
      .backgroundColor(Tokens.surface)
      .borderRadius(24)
      .borderWidth(1)
      .borderColor('#CCFFFFFF')
      .shadow({ radius: 40, color: '#24000000', offsetX: 0, offsetY: 20 })
      .scale({ x: this.confirmScale, y: this.confirmScale })
    }
    .width('100%')
    .height('100%')
  }

  @Builder ItemActionsOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Tokens.dim)
        .backdropBlur(6)
        .onClick(() => {
          this.closeItemActions();
        })

      Column() {
        Row() {
          Text(this.actionMode === 'view' ? this.t('detailRecord') : this.t('editRecord'))
            .fontSize(11)
            .fontColor(Tokens.muted)
          Blank()
          Button(this.t('close'))
            .height(30)
            .fontSize(9)
            .fontColor('#6C4B00')
            .backgroundColor(Tokens.yellowSoft)
            .borderRadius(14)
            .padding({ left: 11, right: 11 })
            .onClick(() => {
              this.closeItemActions();
            })
        }
        .width('100%')

        Text(this.actionItem.title)
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(Tokens.ink)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 16 })

        Text(this.findSubject(this.actionItem.subjectId).name + '  ·  ' + this.t('next') + ' ' + formatShort(this.actionItem.nextReviewAt))
          .fontSize(10)
          .fontColor(Tokens.muted)
          .width('100%')
          .margin({ top: 7 })

        Row() {
          Column() {
            Text(this.t('created'))
              .fontSize(8)
              .fontColor(Tokens.mutedSoft)
            Text(formatShort(this.actionItem.createdAt))
              .fontSize(11)
              .fontColor(Tokens.inkSoft)
              .margin({ top: 3 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Column() {
            Text(this.t('reviewed'))
              .fontSize(8)
              .fontColor(Tokens.mutedSoft)
            Text(this.t('times', this.actionItem.reviewCount))
              .fontSize(11)
              .fontColor(Tokens.inkSoft)
              .margin({ top: 3 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Column() {
            Text(this.t('currentInterval'))
              .fontSize(8)
              .fontColor(Tokens.mutedSoft)
            Text(this.t('days', this.actionItem.currentIntervalDays))
              .fontSize(11)
              .fontColor(Tokens.inkSoft)
              .margin({ top: 3 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(Tokens.surfaceSoft)
        .borderRadius(14)
        .margin({ top: 14 })

        Row()
          .width('100%')
          .height(1)
          .backgroundColor(Tokens.line)
          .margin({ top: 18, bottom: 16 })

        if (this.actionMode === 'view') {
          Row({ space: 10 }) {
            Button(this.t('modify'))
              .layoutWeight(1)
              .height(44)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#3D2A00')
              .backgroundColor(Tokens.yellow)
              .borderRadius(13)
              .onClick(() => {
                this.startEditItem();
              })
            Button(this.t('deleteAction'))
              .layoutWeight(1)
              .height(44)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#C7422C')
              .backgroundColor('#FFE9E4')
              .borderRadius(13)
              .onClick(() => {
                this.deleteFromAction();
              })
          }
          .width('100%')
        } else {
          Text(this.t('titleLabel'))
            .fontSize(9)
            .fontColor(Tokens.muted)
            .width('100%')
          TextInput({ text: this.editTitle })
            .height(44)
            .fontSize(15)
            .fontColor(Tokens.ink)
            .backgroundColor(Tokens.surface)
            .borderWidth(1)
            .borderColor('#B3FFFFFF')
            .borderRadius(12)
            .padding({ left: 12, right: 12 })
            .margin({ top: 7 })
            .onChange((value: string) => {
              this.editTitle = value;
            })

          Text(this.t('subject'))
            .fontSize(9)
            .fontColor(Tokens.muted)
            .width('100%')
            .margin({ top: 14 })
          Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(this.subjects, (subject: Subject) => {
              Button(subject.name)
                .height(30)
                .fontSize(10)
                .fontColor(this.editSubjectId === subject.id ? '#3D2A00' : Tokens.inkSoft)
                .backgroundColor(this.editSubjectId === subject.id ? Tokens.yellow : Tokens.surface)
                .borderWidth(1)
                .borderColor(this.editSubjectId === subject.id ? '#CCFFC531' : Tokens.line)
                .borderRadius(15)
                .padding({ left: 11, right: 11 })
                .margin({ right: 6, bottom: 6 })
                .scale({ x: this.editSubjectId === subject.id ? 1.04 : 1, y: this.editSubjectId === subject.id ? 1.04 : 1 })
                .animation({ duration: 180, curve: Curve.EaseOut })
                .onClick(() => {
                  this.editSubjectId = subject.id;
                })
            }, (subject: Subject) => subject.id)
          }
          .width('100%')
          .margin({ top: 5 })

          Row({ space: 10 }) {
            Button(this.t('cancel'))
              .layoutWeight(1)
              .height(42)
              .fontSize(12)
              .fontColor(Tokens.inkSoft)
              .backgroundColor(Tokens.surfaceSoft)
              .borderRadius(12)
              .onClick(() => {
                this.changeActionMode('view');
              })
            Button(this.t('save'))
              .layoutWeight(1)
              .height(42)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#3D2A00')
              .backgroundColor(Tokens.yellow)
              .borderRadius(12)
              .onClick(() => {
                this.saveItemEdit();
              })
          }
          .width('100%')
          .margin({ top: 10 })
        }
      }
      .width(this.isWide ? 560 : '92%')
      .padding(24)
      .backgroundColor(Tokens.surface)
      .borderRadius(26)
      .borderWidth(1)
      .borderColor('#CCFFFFFF')
      .shadow({ radius: 40, color: '#24000000', offsetX: 0, offsetY: 20 })
      .scale({ x: this.actionScale, y: this.actionScale })
      .opacity(this.actionContentOpacity)
    }
    .width('100%')
    .height('100%')
    .opacity(this.actionOverlayOpacity)
  }

  @Builder ComposerOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Tokens.dim)
        .opacity(this.composerDim)
        .backdropBlur(6)
        .onClick(() => {
          this.closeComposer();
        })

      Scroll() {
        Column() {
          this.ComposerPane(true)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .width(this.isWide ? 430 : '92%')
      .constraintSize({ maxHeight: '84%' })
      .scrollBar(BarState.Off)
      .scale({ x: this.composerScale, y: this.composerScale })
      .translate({ y: this.composerShift })
      .opacity(this.composerOpacity)
    }
    .width('100%')
    .height('100%')
  }
}
