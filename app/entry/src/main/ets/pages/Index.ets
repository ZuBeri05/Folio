import { common } from '@kit.AbilityKit';
import { promptAction, LengthMetrics, KeyboardAvoidMode, window } from '@kit.ArkUI';
import { AppData, Subject, StudyItem, ReviewLog, Settings, DayCount, FocusSession, SUBJECT_COLORS, createDefaultData, emptyItem, newId } from '../domain/Models';
import { Store } from '../data/Store';
import { scheduleFsrs, previewForGrades, postponeToTomorrow, startOfDay, addDays, daysBetween } from '../domain/Scheduling';
import { fsrsStateFromItem } from '../domain/fsrs/Scheduling.ts';
import { formatClock, durationParts, summarize, todayCount, todayMinutes, weekBuckets, breakMinutesFor, cycleSummary } from '../domain/focus/Focus';
import { ReminderService } from '../services/ReminderService';
import { FocusAlert } from '../services/FocusAlert';
import { Tokens, Motion } from '../theme/Tokens';
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
  @State reviewStage: string = 'entry';
  @State showComposer: boolean = false;
  @State draftSubjectId: string = 'math';
  @State draftTitle: string = '';
  @State draftMode: string = 'fsrs';
  @State modeFade: number = 1;
  private modeTimer: number = -1;
  @State draftFixedDays: number = 3;
  @State dotVisible: number = 6;
  @State newSubjectName: string = '';
  @State calendarDays: number = 14;
  @State calendarX: number[] = [];
  @State calendarAlpha: number[] = [];
  @State formProgress: number = 1;
  @State titleFocused: boolean = false;
  @State titleBorderColor: string = '#B3FFFFFF';
  @State todayLabel: string = '';
  @State reviewScale: number = 0.97;
  @State reviewOpacity: number = 0;
  @State todayProgress: number = 1;
  @State retentionUnlocked: boolean = false;
  @State isTablet: boolean = false;
  @State vpWidth: number = 1000;
  @State vpHeight: number = 800;
  @State keyboardHeight: number = 0;
  private keyboardBound: boolean = false;

  // 记录页：每张卡片 / 每段竖线各自的入场进度
  @State recIn: number[] = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
  // 今日页：标题（左）、列表（下）、今天已记（右）三个方向
  @State todayTitleIn: number = 1;
  @State todayLoggedIn: number = 1;
  // 今日条数变化时，胶囊轻轻弹一下
  @State countPop: number = 1;
  private countPopTimer: number = -1;
  @State clockPop: number = 1;
  private clockPopTimer: number = -1;
  // 设置页：每张分组卡各自的入场进度
  @State setIn: number[] = [1, 1, 1, 1, 1];
  // 记录页：单张卡片实测高度，用于让时间轴竖线连续
  @State recRowH: number = 86;
  @State listOpacity: number = 0;
  @State listShift: number = 16;
  @State pressedGrade: number = 0;
  @State gradePreviewDays: number[] = [1, 1, 1, 1];
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
  @State showTimePicker: boolean = false;
  @State timePickerScale: number = 1;
  @State pickerHour: number = 20;
  @State pickerMinute: number = 0;
  // 专注计时
  @State focusSessions: FocusSession[] = [];
  @State focusRunning: boolean = false;
  @State focusPaused: boolean = false;
  @State focusIsBreak: boolean = false;
  @State focusEndAt: number = 0;
  @State focusStartedAt: number = 0;
  @State focusRemainingMs: number = 0;
  @State focusPlannedMinutes: number = 25;
  /** 循环里第几轮，从 1 开始 */
  @State focusRound: number = 1;
  /** 这一轮循环是什么时候开始的，用来算小结里的累计 */
  @State focusCycleStart: number = 0;
  @State showFocusSummary: boolean = false;
  @State summaryScale: number = 1;
  @State summaryMinutes: number = 0;
  @State summarySegments: number = 0;
  @State summaryItems: number = 0;
  @State summaryRemembered: number = 0;
  @State summaryStart: number = 0;
  @State summaryEnd: number = 0;
  @State showFocusClock: boolean = false;
  @State clockScale: number = 1;
  private focusTimer: number = -1;
  private focusPausedRemaining: number = 0;
  private hourRange: string[] = [];
  private minuteRange: string[] = [];
  private reviewBusy: boolean = false;
  private reviewPressTimer: number = -1;
  private reviewCommitTimer: number = -1;
  private reviewCloseTimer: number = -1;
  private reviewToken: number = 0;

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
  private readonly gradeNodes: number[] = [1, 2, 3, 4];

  aboutToAppear(): void {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.NONE);
    this.bindKeyboard();
    for (let i = 0; i < 24; i++) {
      this.hourRange.push(i < 10 ? '0' + i : '' + i);
    }
    for (let i = 0; i < 60; i++) {
      this.minuteRange.push(i < 10 ? '0' + i : '' + i);
    }
    const now = new Date();
    this.todayLabel = this.longDate(now.getTime()) + '  ·  ' + this.weekday(now.getTime());
    this.loadData();
  }

  onPageShow(): void {
    // 从后台回来时 setInterval 可能被节流，立刻按时间戳重算一次
    this.tickFocus();
  }

  // 全屏窗口在部分机型上不会随键盘收缩，直接监听键盘高度，
  // 把「记一条」限制在键盘上方的可用区域里，避免保存按钮被盖住。
  private bindKeyboard(): void {
    if (this.keyboardBound) {
      return;
    }
    this.keyboardBound = true;
    const context = getContext(this) as common.UIAbilityContext;
    window.getLastWindow(context).then((win: window.Window) => {
      win.on('keyboardHeightChange', (height: number) => {
        this.keyboardHeight = height > 0 ? px2vp(height) : 0;
      });
    }).catch(() => {
    });
  }

  private async loadData(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    const data = await Store.load(context);
    this.subjects = data.subjects;
    this.items = data.items;
    this.logs = data.logs;
    this.settings = data.settings;
    this.focusSessions = data.focusSessions;
    this.focusPlannedMinutes = this.settings.focusMinutes;
    this.todayLabel = this.localizedToday();
    this.restoreFocus(data.activeFocus);
    this.syncSystemBars();
    if (this.subjects.length > 0) {
      this.draftSubjectId = this.subjects[0].id;
    }
    this.playEntry();
    this.playToday();
    this.playForm();
    this.playDots();
    this.refreshNotificationState();
    if (this.settings.reminderEnabled && this.items.length > 0) {
      this.syncReminder();
    }
  }

  /** 位移幅度（vp），随屏宽缩放：手机与平板拿到不同数值 */
  private mv(base: number): number {
    return Motion.travel(base, this.vpWidth);
  }

  /** 动效时长（ms），随幅度收敛 */
  private md(base: number): number {
    return Motion.time(base, this.vpWidth);
  }

  private playEntry(): void {
    this.listOpacity = 0;
    this.listShift = this.mv(30);
    this.todayTitleIn = 0;
    this.todayProgress = 0;
    this.todayLoggedIn = 0;
    setTimeout(() => {
      animateTo({ curve: Motion.settle() }, () => {
        this.listOpacity = 1;
        this.listShift = 0;
      });
      this.playToday();
    }, 40);
  }

  private playToday(): void {
    this.todayTitleIn = 0;
    this.todayProgress = 0;
    this.todayLoggedIn = 0;
    animateTo({ curve: Motion.settle() }, () => {
      this.todayTitleIn = 1;
    });
    animateTo({ curve: Motion.settle(), delay: 90 }, () => {
      this.todayProgress = 1;
    });
    animateTo({ curve: Motion.settle(), delay: 180 }, () => {
      this.todayLoggedIn = 1;
    });
  }

  /** 一段结束、下一段接上：中间的数字先轻轻胀一下 */
  private popClock(): void {
    if (this.clockPopTimer >= 0) {
      clearTimeout(this.clockPopTimer);
      this.clockPopTimer = -1;
    }
    animateTo({ duration: 130, curve: Motion.snap() }, () => {
      this.clockPop = 1.05;
    });
    this.clockPopTimer = setTimeout(() => {
      this.clockPopTimer = -1;
      animateTo({ duration: 240, curve: Motion.settle() }, () => {
        this.clockPop = 1;
      });
    }, 130);
  }

  /** 条数变了：胶囊先胀一下再落回，别让数字硬跳 */
  private popCount(): void {
    if (this.countPopTimer >= 0) {
      clearTimeout(this.countPopTimer);
      this.countPopTimer = -1;
    }
    animateTo({ duration: 120, curve: Motion.snap() }, () => {
      this.countPop = 1.12;
    });
    this.countPopTimer = setTimeout(() => {
      this.countPopTimer = -1;
      animateTo({ duration: 220, curve: Motion.settle() }, () => {
        this.countPop = 1;
      });
    }, 120);
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

  private switchMode(next: string): void {
    if (this.draftMode === next) {
      return;
    }
    // 先把当前这套淡出，换掉内容再淡入，两套排版永远不会叠在一起
    animateTo({ duration: 100, curve: Motion.accel() }, () => {
      this.modeFade = 0;
    });
    if (this.modeTimer >= 0) {
      clearTimeout(this.modeTimer);
    }
    this.modeTimer = setTimeout(() => {
      this.modeTimer = -1;
      this.draftMode = next;
      animateTo({ duration: 220, curve: Motion.decel() }, () => {
        this.modeFade = 1;
      });
      if (next === 'fsrs') {
        this.playDots();
      }
    }, 100);
  }

  private openComposer(): void {
    // 全屏窗口在部分机型上不会随键盘收缩，弹层改为自己监听键盘高度，
    // 窗口保持 NONE，避免不同机型出现「收缩一次又再减一次」。
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.NONE);
    this.showComposer = true;
    this.playForm();
    this.playDots();
    this.composerScale = 0.88;
    this.composerShift = this.mv(32);
    this.composerOpacity = 0;
    this.composerDim = 0;
    animateTo({ curve: Motion.settle() }, () => {
      this.composerScale = 1;
      this.composerShift = 0;
      this.composerOpacity = 1;
      this.composerDim = 1;
    });
  }

  private closeComposer(): void {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.NONE);
    animateTo({ duration: Motion.base, curve: Motion.accel() }, () => {
      this.composerScale = 0.94;
      this.composerShift = this.mv(16);
      this.composerOpacity = 0;
      this.composerDim = 0;
    });
    setTimeout(() => {
      this.showComposer = false;
      this.composerScale = 1;
      this.composerShift = 0;
      this.composerOpacity = 1;
      this.composerDim = 0;
    }, Motion.base);
  }

  private persist(): void {
    const context = getContext(this) as common.UIAbilityContext;
    const data: AppData = {
      schemaVersion: 2,
      subjects: this.subjects,
      items: this.items,
      logs: this.logs,
      settings: this.settings,
      focusSessions: this.focusSessions,
      activeFocus: this.currentFocusRecord()
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

  private subjectInk(color: string): string {
    const raw = color.startsWith('#') ? color.substring(1) : color;
    if (raw.length < 6) {
      return '#FFFFFF';
    }
    const r = parseInt(raw.substring(0, 2), 16);
    const g = parseInt(raw.substring(2, 4), 16);
    const b = parseInt(raw.substring(4, 6), 16);
    return (r * 299 + g * 587 + b * 114) / 1000 >= 160 ? '#3D2A00' : '#FFFFFF';
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
    if (this.tab === 3) {
      // 离开设置页时先收键盘，避免输入法留在下一个页面
      this.getUIContext().getFocusController().clearFocus();
    }
    const forward = next > this.tab;
    const isCalendar = next === 2;
    const outMs = isCalendar ? 200 : 300;
    const inMs = this.md(isCalendar ? Motion.slow : Motion.page);
    const shift = isCalendar ? this.mv(24) : this.mv(52);
    animateTo({ duration: outMs, curve: Motion.accel() }, () => {
      this.pageOpacity = 0;
      this.pageShift = 0;
    });
    setTimeout(() => {
      this.tab = next;
      this.syncSystemBars();
      this.pageOpacity = 0.25;
      this.pageShift = forward ? shift : -shift;
      animateTo({ duration: inMs, curve: Motion.decel() }, () => {
        this.pageOpacity = 1;
        this.pageShift = 0;
      });
      if (next === 0) {
        this.playEntry();
        this.playForm();
        this.playDots();
      }
      if (next === 1) {
        this.playRecords();
      } else if (next === 2) {
        this.playCalendarRows();
      } else if (next === 3) {
        this.playSettings();
      }
    }, outMs);
  }

  private itemSubtitle(item: StudyItem): string {
    const late = this.overdueDaysOf(item);
    if (late > 0) {
      return this.t('times', item.reviewCount) + '  ·  ' + this.t('overdueDays', late);
    }
    return this.t('times', item.reviewCount) + '  ·  ' + this.t('next') + ' ' + this.shortDate(item.nextReviewAt);
  }

  private itemSubtitleColor(item: StudyItem): string {
    return this.overdueDaysOf(item) > 0 ? Tokens.coral : Tokens.muted;
  }

  /** 到期日早于今天且还没做的条目 */
  private overdueItems(): StudyItem[] {
    const today = startOfDay(new Date()).getTime();
    const result: StudyItem[] = [];
    for (let i = 0; i < this.items.length; i++) {
      const item = this.items[i];
      if (item.status === 'active' && startOfDay(new Date(item.nextReviewAt)).getTime() < today) {
        result.push(item);
      }
    }
    return result;
  }

  /** 逾期天数，当天到期算 0 */
  private overdueDaysOf(item: StudyItem): number {
    const due = startOfDay(new Date(item.nextReviewAt)).getTime();
    const today = startOfDay(new Date()).getTime();
    if (due >= today) {
      return 0;
    }
    return Math.max(1, daysBetween(due, new Date()));
  }

  private oldestOverdueLabel(): string {
    const list = this.overdueItems();
    if (list.length === 0) {
      return '';
    }
    let oldest = list[0].nextReviewAt;
    for (let i = 1; i < list.length; i++) {
      if (list[i].nextReviewAt < oldest) {
        oldest = list[i].nextReviewAt;
      }
    }
    return this.shortDate(oldest);
  }

  private upcoming(): DayCount[] {
    const result: DayCount[] = [];
    const base = startOfDay(new Date());
    for (let i = 0; i < this.calendarDays; i++) {
      const day = addDays(base, i);
      const key = day.getTime();
      let count = 0;
      for (let j = 0; j < this.items.length; j++) {
        const item = this.items[j];
        if (item.status !== 'active') {
          continue;
        }
        const at = startOfDay(new Date(item.nextReviewAt)).getTime();
        // 第一天算上逾期：今天要复习的条目（含拖过期的）和首页「今日复习」保持一致
        if (i === 0 ? at <= key : at === key) {
          count++;
        }
      }
      result.push({ date: key, count: count });
    }
    return result;
  }

  /** 某一天要复习的条目；today 为真时把逾期未做的也算进来，最久没做的排最前 */
  private dayItems(day: number, today: boolean): StudyItem[] {
    const result: StudyItem[] = [];
    for (let i = 0; i < this.items.length; i++) {
      const item = this.items[i];
      if (item.status !== 'active') {
        continue;
      }
      const at = startOfDay(new Date(item.nextReviewAt)).getTime();
      if (today ? at <= day : at === day) {
        result.push(item);
      }
    }
    result.sort((a: StudyItem, b: StudyItem) => a.nextReviewAt - b.nextReviewAt);
    return result;
  }

  /** 进入评分前算一次四档预览，四张评分卡共用，避免每张卡各算一遍 */
  private refreshGradePreview(item: StudyItem): void {
    this.gradePreviewDays = previewForGrades(item, Date.now(), this.settings.targetRetention, this.settings.maxIntervalDays);
  }

  private intervalText(days: number): string {
    return days === 1 ? this.t('tomorrow') : this.t('daysAfter', days);
  }

  private gradeColor(grade: number): string {
    if (grade === 1) {
      return '#D95F3F';
    }
    if (grade === 2) {
      return '#B17A12';
    }
    if (grade === 3) {
      return '#8F5600';
    }
    return '#5AA469';
  }

  private gradeTint(grade: number, alpha: string): string {
    return '#' + alpha + this.gradeColor(grade).substring(1);
  }

  private gradeLabel(grade: number): string {
    if (grade === 1) {
      return this.t('gradeAgain');
    }
    if (grade === 2) {
      return this.t('gradeHard');
    }
    if (grade === 3) {
      return this.t('gradeGood');
    }
    return this.t('gradeEasy');
  }

  private gradeMeaning(grade: number): string {
    if (grade === 1) {
      return this.t('gradeAgainHint');
    }
    if (grade === 2) {
      return this.t('gradeHardHint');
    }
    if (grade === 3) {
      return this.t('gradeGoodHint');
    }
    return this.t('gradeEasyHint');
  }

  private gradeIntervalText(grade: number): string {
    const index = grade - 1;
    const days = index >= 0 && index < this.gradePreviewDays.length ? this.gradePreviewDays[index] : 1;
    return this.intervalText(days);
  }

  private legacyRating(grade: number): string {
    if (grade === 1) {
      return 'forgot';
    }
    if (grade === 2) {
      return 'fuzzy';
    }
    return 'got';
  }

  private reviewElapsedDays(item: StudyItem, now: Date): number {
    if (item.lastReviewedAt <= 0) {
      return 0;
    }
    return daysBetween(item.lastReviewedAt, now);
  }

  private clearReviewTimers(): void {
    if (this.reviewPressTimer >= 0) {
      clearTimeout(this.reviewPressTimer);
      this.reviewPressTimer = -1;
    }
    if (this.reviewCommitTimer >= 0) {
      clearTimeout(this.reviewCommitTimer);
      this.reviewCommitTimer = -1;
    }
  }

  private discardPendingReview(): void {
    this.clearReviewTimers();
    this.reviewToken = this.reviewToken + 1;
    this.reviewBusy = false;
    this.pressedGrade = 0;
  }

  private isReviewCommitActive(itemId: string, token: number): boolean {
    return this.showReview && this.reviewStage === 'rating'
      && this.reviewItem.id === itemId && this.reviewToken === token;
  }

  private openReview(item: StudyItem): void {
    this.getUIContext().getFocusController().clearFocus();
    this.discardPendingReview();
    if (this.reviewCloseTimer >= 0) {
      clearTimeout(this.reviewCloseTimer);
      this.reviewCloseTimer = -1;
    }
    this.reviewItem = item;
    this.reviewStage = 'entry';
    this.reviewOpacity = 0;
    this.reviewScale = 0.90;
    this.refreshGradePreview(item);
    this.showReview = true;
    animateTo({ curve: Motion.settle() }, () => {
      this.reviewOpacity = 1;
      this.reviewScale = 1;
    });
  }

  private closeReview(): void {
    if (!this.showReview) {
      return;
    }
    this.discardPendingReview();
    if (this.reviewCloseTimer >= 0) {
      clearTimeout(this.reviewCloseTimer);
      this.reviewCloseTimer = -1;
    }
    animateTo({ duration: Motion.base, curve: Motion.accel() }, () => {
      this.reviewOpacity = 0;
      this.reviewScale = 0.94;
    });
    this.reviewCloseTimer = setTimeout(() => {
      this.reviewCloseTimer = -1;
      this.showReview = false;
      this.reviewStage = 'entry';
      this.reviewScale = 1;
      this.reviewOpacity = 0;
    }, Motion.base);
  }

  private backToEntry(): void {
    this.discardPendingReview();
    // 和进入评分页同一套节奏，退回来也别硬切
    this.reviewScale = 0.96;
    animateTo({ curve: Motion.snap() }, () => {
      this.reviewStage = 'entry';
      this.reviewScale = 1;
    });
  }

  private startRating(): void {
    this.refreshGradePreview(this.reviewItem);
    this.reviewScale = 0.96;
    animateTo({ curve: Motion.snap() }, () => {
      this.reviewStage = 'rating';
      this.reviewScale = 1;
    });
  }

  private postponeReview(): void {
    this.discardPendingReview();
    const next = postponeToTomorrow(this.reviewItem, Date.now());
    this.items = this.items.map((item: StudyItem) => item.id === next.id ? next : item);
    this.popCount();
    this.closeReview();
    this.persist();
    this.syncReminder();
    this.toast(this.t('postponedTomorrow'));
  }

  private finishReview(grade: number): void {
    if (this.reviewBusy || !this.showReview || this.reviewStage !== 'rating') {
      return;
    }
    const itemId = this.reviewItem.id;
    const token = this.reviewToken;
    this.reviewBusy = true;
    this.clearReviewTimers();
    animateTo({ duration: Motion.quick, curve: Motion.snap() }, () => {
      this.pressedGrade = grade;
    });
    this.reviewPressTimer = setTimeout(() => {
      this.reviewPressTimer = -1;
      if (!this.isReviewCommitActive(itemId, token)) {
        return;
      }
      animateTo({ duration: Motion.quick, curve: Motion.accel() }, () => {
        this.reviewScale = 0.95;
      });
      this.reviewCommitTimer = setTimeout(() => {
        this.reviewCommitTimer = -1;
        this.commitReview(grade, itemId, token);
      }, 170);
    }, 130);
  }

  private commitReview(grade: number, itemId: string, token: number): void {
    if (!this.isReviewCommitActive(itemId, token)) {
      return;
    }
    const item = this.reviewItem;
    const now = new Date();
    const result = scheduleFsrs(item, grade, now.getTime(), this.settings.targetRetention,
      this.settings.maxIntervalDays);
    const before = fsrsStateFromItem(item);
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
      fsrsStability: result.stability,
      fsrsDifficulty: result.difficulty,
      fsrsState: result.state,
      fsrsScheduledDays: result.scheduledDays,
      fsrsLapses: result.lapses,
      fsrsVersion: 6
    };
    animateTo({ duration: 260, curve: Motion.decel() }, () => {
      this.items = this.items.map((value: StudyItem) => value.id === updated.id ? updated : value);
    });
    this.popCount();
    const log: ReviewLog = {
      id: newId(),
      itemId: item.id,
      reviewedAt: now.getTime(),
      rating: this.legacyRating(grade),
      previousIntervalDays: item.currentIntervalDays,
      nextIntervalDays: result.nextIntervalDays,
      nextReviewAt: result.nextAt,
      grade: grade,
      stabilityBefore: before.stability,
      stabilityAfter: result.stability,
      difficultyBefore: before.difficulty,
      difficultyAfter: result.difficulty,
      elapsedDays: this.reviewElapsedDays(item, now),
      scheduledDays: result.scheduledDays
    };
    this.logs = [log, ...this.logs];
    this.closeReview();
    this.persist();
    this.syncReminder();
    this.toast(this.t('nextReviewToast', this.longDate(result.nextAt)));
  }

  private addItem(): void {
    const title = this.draftTitle.trim();
    if (title.length === 0) {
      this.toast(this.t('toastWriteToday'));
      return;
    }
    this.getUIContext().getFocusController().clearFocus();
    const now = new Date();
    const useFixed = this.draftMode === 'fixed';
    const fixedDays = Math.max(1, Math.min(90, Math.round(this.draftFixedDays)));
    const nextAt = useFixed
      ? addDays(startOfDay(now), fixedDays).getTime()
      : addDays(startOfDay(now), 1).getTime();
    const item: StudyItem = {
      id: newId(),
      subjectId: this.draftSubjectId,
      title: title,
      createdAt: now.getTime(),
      scheduleMode: useFixed ? 'fixed' : 'fsrs',
      curveStage: 0,
      fixedIntervalDays: useFixed ? fixedDays : 3,
      currentIntervalDays: useFixed ? fixedDays : 1,
      nextReviewAt: nextAt,
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
    animateTo({ duration: 320, curve: Motion.decel() }, () => {
      this.items = [item, ...this.items];
    });
    this.popCount();
    this.draftTitle = '';
    this.showComposer = false;
    this.switchTab(0);
    this.persist();
    this.syncReminder();
    this.toast(this.t('toastSaved', this.longDate(item.nextReviewAt)));
  }

  private updateReminderEnabled(value: boolean): void {
    this.settings = {
      reminderEnabled: value,
      reminderTime: this.settings.reminderTime,
      subjectTimes: this.settings.subjectTimes,
      themeIndex: this.settings.themeIndex,
      language: this.settings.language,
      targetRetention: this.settings.targetRetention,
      maxIntervalDays: this.settings.maxIntervalDays,
      focusMinutes: this.settings.focusMinutes
    };
    this.persist();
    this.syncReminder();
  }

  /** 滑轮选时间：弹出自己的小面板，滚完点确定直接落盘并重写日历 */
  private openTimePicker(): void {
    const parts: string[] = this.settings.reminderTime.split(':');
    let hour = 20;
    let minute = 0;
    if (parts.length === 2) {
      const h = Number(parts[0]);
      const m = Number(parts[1]);
      if (!isNaN(h) && h >= 0 && h <= 23) {
        hour = h;
      }
      if (!isNaN(m) && m >= 0 && m <= 59) {
        minute = m;
      }
    }
    this.pickerHour = hour;
    this.pickerMinute = minute;
    this.showTimePicker = true;
    this.timePickerScale = 0.94;
    animateTo({ curve: Motion.snap() }, () => {
      this.timePickerScale = 1;
    });
  }

  /** 时间选择器收起：缩回去再撤，和别的浮层一个节奏 */
  private closeTimePickerAnimated(): void {
    if (!this.showTimePicker) {
      return;
    }
    animateTo({ duration: Motion.quick, curve: Motion.accel() }, () => {
      this.timePickerScale = 0.94;
    });
    setTimeout(() => {
      this.showTimePicker = false;
      this.timePickerScale = 1;
    }, Motion.quick);
  }

  private cancelTimePicker(): void {
    this.closeTimePickerAnimated();
  }

  private confirmTimePicker(): void {
    this.applyReminderTime(this.pickerHour, this.pickerMinute);
    this.closeTimePickerAnimated();
  }

  private applyReminderTime(hour: number, minute: number): void {
    const h = hour < 10 ? '0' + hour : '' + hour;
    const m = minute < 10 ? '0' + minute : '' + minute;
    const value = h + ':' + m;
    if (value === this.settings.reminderTime) {
      return;
    }
    this.settings = {
      reminderEnabled: this.settings.reminderEnabled,
      reminderTime: value,
      subjectTimes: this.settings.subjectTimes,
      themeIndex: this.settings.themeIndex,
      language: this.settings.language,
      targetRetention: this.settings.targetRetention,
      maxIntervalDays: this.settings.maxIntervalDays,
      focusMinutes: this.settings.focusMinutes
    };
    this.persist();
    this.syncReminder();
  }

  // ---------------- 专注计时 ----------------

  private openFocusClock(): void {
    this.clockScale = 0.94;
    this.showFocusClock = true;
    if (this.focusRunning) {
      this.setKeepScreenOn(true);
    }
    animateTo({ curve: Motion.settle() }, () => {
      this.clockScale = 1;
    });
  }

  private closeFocusClock(): void {
    if (!this.showFocusClock) {
      return;
    }
    animateTo({ duration: Motion.base, curve: Motion.accel() }, () => {
      this.clockScale = 0.94;
    });
    setTimeout(() => {
      this.showFocusClock = false;
      this.clockScale = 1;
      this.setKeepScreenOn(false);
    }, Motion.base);
  }

  private setKeepScreenOn(on: boolean): void {
    const context = getContext(this) as common.UIAbilityContext;
    window.getLastWindow(context).then((win: window.Window) => {
      win.setWindowKeepScreenOn(on).catch(() => {
      });
    }).catch(() => {
    });
  }

  /** 从大圆盘点开始：起一轮新的番茄循环 */
  private startCycle(): void {
    this.focusCycleStart = Date.now();
    this.focusRound = 1;
    this.startSegment(this.settings.focusMinutes, false);
  }

  private startSegment(minutes: number, isBreak: boolean): void {
    const safe = Math.min(90, Math.max(1, Math.round(minutes)));
    const startedAt = Date.now();
    const wasRunning = this.focusRunning;
    // 待机色换专注色、时长换倒计时，都走一段过渡，别硬切
    animateTo({ duration: Motion.base, curve: Motion.decel() }, () => {
      this.focusIsBreak = isBreak;
      this.focusPaused = false;
      this.focusRunning = true;
      this.focusPlannedMinutes = safe;
      this.focusRemainingMs = safe * 60000;
    });
    this.focusStartedAt = startedAt;
    this.focusEndAt = startedAt + safe * 60000;
    this.focusPausedRemaining = 0;
    if (wasRunning) {
      // 专注接休息、休息接专注：数字换掉时给一下反馈
      this.popClock();
    }
    this.beginFocusTick();
    this.persist();
    this.scheduleFocusAlarm(safe);
    FocusAlert.prepare(getContext(this) as common.UIAbilityContext);
  }

  /** 到点了响一声，和消息通知一样；手动结束就不打扰 */
  private ringFocusEnd(wasBreak: boolean, minutes: number, round: number): void {
    const title = wasBreak ? this.t('focusBreakOver') : this.t('focusSummary');
    const text = wasBreak ? this.t('focusNotifyNext', String(round)) : this.t('focusNotifyRest', String(minutes));
    FocusAlert.ring(title, text);
  }

  private beginFocusTick(): void {
    this.stopFocusTick();
    this.focusTimer = setInterval(() => {
      this.tickFocus();
    }, 250);
  }

  private stopFocusTick(): void {
    if (this.focusTimer >= 0) {
      clearInterval(this.focusTimer);
      this.focusTimer = -1;
    }
  }

  private tickFocus(): void {
    if (!this.focusRunning || this.focusPaused) {
      return;
    }
    const left = this.focusEndAt - Date.now();
    this.focusRemainingMs = left > 0 ? left : 0;
    if (left <= 0) {
      this.finishSegment(true);
    }
  }

  private pauseFocus(): void {
    if (!this.focusRunning || this.focusPaused) {
      return;
    }
    this.focusPausedRemaining = Math.max(0, this.focusEndAt - Date.now());
    this.focusRemainingMs = this.focusPausedRemaining;
    animateTo({ duration: Motion.quick, curve: Motion.standard() }, () => {
      this.focusPaused = true;
    });
    this.persist();
    this.clearFocusAlarm();
  }

  private resumeFocus(): void {
    if (!this.focusRunning || !this.focusPaused) {
      return;
    }
    this.focusEndAt = Date.now() + this.focusPausedRemaining;
    animateTo({ duration: Motion.quick, curve: Motion.standard() }, () => {
      this.focusPaused = false;
    });
    this.persist();
    this.scheduleFocusAlarm(Math.max(1, Math.round(this.focusPausedRemaining / 60000)));
  }

  private stopFocusEarly(): void {
    if (!this.focusRunning) {
      return;
    }
    this.finishSegment(false);
  }

  /**
   * 收一段：专注走完自动进休息，休息走完自动进下一轮专注，一直转到手动结束。
   * autoContinue 为 false 时只结算、不续上（冷启动发现已经过点了）。
   */
  private finishSegment(completed: boolean, endOverride?: number, autoContinue: boolean = true): void {
    if (!this.focusRunning) {
      return;
    }
    const startedAt = this.focusStartedAt;
    // 走完的那一段按原定结束时间记，App 被冻结后补算也不会把时长算多
    const nowMs = Date.now();
    let endedAt = nowMs;
    if (endOverride !== undefined) {
      endedAt = endOverride;
    } else if (completed && this.focusEndAt > 0 && this.focusEndAt <= nowMs) {
      endedAt = this.focusEndAt;
    }
    const wasBreak = this.focusIsBreak;
    const planned = this.focusPlannedMinutes;
    const round = this.focusRound;
    this.stopFocusTick();
    animateTo({ duration: Motion.base, curve: Motion.decel() }, () => {
      this.focusRunning = false;
      this.focusPaused = false;
      this.focusIsBreak = false;
      this.focusRemainingMs = 0;
    });
    this.clearFocusAlarm();

    if (wasBreak) {
      if (completed && autoContinue) {
        this.ringFocusEnd(true, 0, round + 1);
        this.focusRound = round + 1;
        this.startSegment(this.settings.focusMinutes, false);
        return;
      }
      this.endCycle(endedAt);
      return;
    }

    const summary = summarize(startedAt, endedAt, this.logs);
    if (summary.minutes >= 1) {
      const session: FocusSession = {
        id: newId(),
        startedAt: startedAt,
        endedAt: endedAt,
        plannedMinutes: planned,
        minutes: summary.minutes,
        itemCount: summary.itemCount,
        remembered: summary.remembered,
        completed: completed
      };
      this.focusSessions = this.focusSessions.concat([session]);
    }
    this.persist();

    if (completed && autoContinue) {
      const breakMinutes = breakMinutesFor(round);
      this.ringFocusEnd(false, breakMinutes, round);
      this.startSegment(breakMinutes, true);
      return;
    }

    this.endCycle(endedAt);
  }

  /** 结束整轮循环，弹一张累计小结 */
  private endCycle(endedAt: number): void {
    const cycleStart = this.focusCycleStart;
    const cycle = cycleSummary(this.focusSessions, cycleStart);
    this.focusCycleStart = 0;
    this.focusRound = 1;
    this.persist();
    this.closeFocusClock();
    if (cycle.segments === 0) {
      this.toast(this.t('focusTooShort'));
      return;
    }
    this.summaryMinutes = cycle.minutes;
    this.summarySegments = cycle.segments;
    this.summaryItems = cycle.itemCount;
    this.summaryRemembered = cycle.remembered;
    this.summaryStart = cycleStart;
    this.summaryEnd = endedAt;
    this.showSummary();
  }

  private showSummary(): void {
    this.summaryScale = 0.94;
    this.showFocusSummary = true;
    animateTo({ curve: Motion.snap() }, () => {
      this.summaryScale = 1;
    });
  }

  private closeSummary(): void {
    if (!this.showFocusSummary) {
      return;
    }
    FocusAlert.clear();
    animateTo({ duration: Motion.base, curve: Motion.accel() }, () => {
      this.summaryScale = 0.94;
    });
    setTimeout(() => {
      this.showFocusSummary = false;
      this.summaryScale = 1;
    }, Motion.base);
  }

  /** 冷启动时把没跑完的那一段接回来 */
  private restoreFocus(active: FocusSession | null): void {
    if (active === null) {
      return;
    }
    this.focusStartedAt = active.startedAt;
    this.focusPlannedMinutes = active.plannedMinutes;
    this.focusEndAt = active.endedAt;
    this.focusIsBreak = active.isBreak === true;
    this.focusRound = active.round !== undefined && active.round > 0 ? active.round : 1;
    this.focusCycleStart = active.cycleStart !== undefined ? active.cycleStart : active.startedAt;
    this.focusPaused = false;
    this.focusRunning = true;
    if (active.endedAt > Date.now()) {
      this.focusRemainingMs = active.endedAt - Date.now();
      this.beginFocusTick();
      return;
    }
    // 关掉 App 期间已经过点了：结算这一段，但不再自动续上
    this.finishSegment(true, active.endedAt, false);
  }

  private currentFocusRecord(): FocusSession | null {
    if (!this.focusRunning) {
      return null;
    }
    return {
      id: 'active',
      startedAt: this.focusStartedAt,
      endedAt: this.focusPaused ? Date.now() + this.focusPausedRemaining : this.focusEndAt,
      plannedMinutes: this.focusPlannedMinutes,
      minutes: 0,
      itemCount: 0,
      remembered: 0,
      completed: false,
      isBreak: this.focusIsBreak,
      round: this.focusRound,
      cycleStart: this.focusCycleStart
    };
  }

  private scheduleFocusAlarm(minutes: number): void {
    const context = getContext(this) as common.UIAbilityContext;
    ReminderService.scheduleFocusEnd(context, this.focusEndAt, minutes).catch(() => {
    });
  }

  private clearFocusAlarm(): void {
    const context = getContext(this) as common.UIAbilityContext;
    ReminderService.clearFocusEnd(context).catch(() => {
    });
  }

  /** 环上还剩多少（0–100）：整圈开始，随时间往回缩 */
  private focusRemainingPercent(): number {
    const total = this.focusPlannedMinutes * 60000;
    if (total <= 0) {
      return 100;
    }
    const left = Math.max(0, Math.min(total, this.focusRemainingMs));
    return left / total * 100;
  }

  /** 这一轮多少分钟就画多少个刻度 */
  private tickCount(): number {
    const minutes = this.focusRunning ? this.focusPlannedMinutes : this.settings.focusMinutes;
    return Math.max(1, Math.min(90, Math.round(minutes)));
  }

  private minuteTicks(): number[] {
    const out: number[] = [];
    const count = this.tickCount();
    for (let i = 0; i < count; i++) {
      out.push(i);
    }
    return out;
  }

  /** 已经走完的分钟数 */
  private elapsedMinutes(): number {
    if (!this.focusRunning) {
      return 0;
    }
    const total = this.focusPlannedMinutes * 60000;
    const passed = Math.floor((total - Math.max(0, this.focusRemainingMs)) / 60000);
    return Math.max(0, Math.min(this.tickCount(), passed));
  }

  private tickOpacity(index: number): number {
    return index < this.elapsedMinutes() ? 0.14 : 0.55;
  }

  private focusClock(): string {
    return formatClock(this.focusRemainingMs);
  }

  /** 大圆盘：放在桌边抬头就能看见，所以尺寸按短边走，平板上封顶 */
  private clockSize(): number {
    const w = this.vpWidth > 0 ? this.vpWidth : 360;
    const h = this.vpHeight > 0 ? this.vpHeight : 720;
    const short = Math.min(w, h);
    // 上下还要留给关闭按钮、已过时间和操作按钮，横屏手机高度不够时按高度收
    const room = h - 170;
    return Math.max(150, Math.min(430, Math.min(short * 0.66, room)));
  }

  private elapsedClock(): string {
    const total = this.focusPlannedMinutes * 60000;
    return formatClock(Math.max(0, total - this.focusRemainingMs));
  }

  /** 专注珊瑚、休息蓝、暂停灰；还没开始时浅一点，整圈就是整段时长 */
  private clockAccent(): string {
    if (!this.focusRunning) {
      return '#FFC4B2';
    }
    if (this.focusPaused) {
      return Tokens.mutedSoft;
    }
    return this.focusIsBreak ? Tokens.blue : Tokens.coral;
  }

  /** 圆盘中心：待机时长和倒计时互换时的过渡 */
  private clockSwap(): TransitionEffect {
    return TransitionEffect.OPACITY
      .combine(TransitionEffect.scale({ x: 0.92, y: 0.92 }))
      .animation({ duration: Motion.base, curve: Motion.decel() });
  }

  /** 第 2 轮 · 专注中 */
  private roundLabel(): string {
    const phase = this.focusIsBreak ? this.t('focusBreaking') : this.t('focusRunning');
    return this.t('focusRound', this.focusRound) + ' · ' + phase;
  }

  /** 25 分钟 / 1 小时 15 分 */
  private minutesLabel(minutes: number): string {
    const parts = durationParts(minutes);
    if (parts[0] <= 0) {
      return this.t('minutesShort', parts[1]);
    }
    if (parts[1] === 0) {
      return this.t('hoursShort', parts[0]);
    }
    return this.t('hoursShort', parts[0]) + ' ' + this.t('minutesShort', parts[1]);
  }

  private todayFocusMinutes(): number {
    return todayMinutes(this.focusSessions, Date.now());
  }

  private todayFocusCount(): number {
    return todayCount(this.focusSessions, Date.now());
  }

  private weekFocus(): number[] {
    return weekBuckets(this.focusSessions, Date.now());
  }

  private weekFocusMax(): number {
    const buckets = this.weekFocus();
    let max = 0;
    for (let i = 0; i < buckets.length; i++) {
      if (buckets[i] > max) {
        max = buckets[i];
      }
    }
    return Math.max(30, max);
  }

  private weekBarHeight(minutes: number): number {
    if (minutes <= 0) {
      return 3;
    }
    return Math.max(6, Math.round(minutes / this.weekFocusMax() * 38));
  }

  /** 本周第 index 天（0 = 周一）的日期戳 */
  private weekDayTs(index: number): number {
    const now = new Date();
    const weekday = (now.getDay() + 6) % 7;
    return startOfDay(now).getTime() + (index - weekday) * 86400000;
  }

  private todayWeekIndex(): number {
    return (new Date().getDay() + 6) % 7;
  }

  private clockLabel(ts: number): string {
    const d = new Date(ts);
    const h = d.getHours();
    const m = d.getMinutes();
    return (h < 10 ? '0' + h : '' + h) + ':' + (m < 10 ? '0' + m : '' + m);
  }

  private updateRetention(value: number): void {
    if (!this.retentionUnlocked) {
      return;
    }
    const retention = Math.min(0.95, Math.max(0.80, Math.round(value) / 100));
    this.settings = {
      reminderEnabled: this.settings.reminderEnabled,
      reminderTime: this.settings.reminderTime,
      subjectTimes: this.settings.subjectTimes,
      themeIndex: this.settings.themeIndex,
      language: this.settings.language,
      targetRetention: retention,
      maxIntervalDays: this.settings.maxIntervalDays,
      focusMinutes: this.settings.focusMinutes
    };
  }

  /** 最长间隔：考研只有几个月，排到三年后没意义，超过上限一律按上限走 */
  private updateMaxInterval(days: number): void {
    if (days === this.settings.maxIntervalDays) {
      return;
    }
    this.settings = {
      reminderEnabled: this.settings.reminderEnabled,
      reminderTime: this.settings.reminderTime,
      subjectTimes: this.settings.subjectTimes,
      themeIndex: this.settings.themeIndex,
      language: this.settings.language,
      targetRetention: this.settings.targetRetention,
      maxIntervalDays: days,
      focusMinutes: this.settings.focusMinutes
    };
    this.persist();
  }

  /** 番茄钟一轮多长，设置页里改 */
  private updateFocusMinutes(minutes: number): void {
    if (minutes === this.settings.focusMinutes) {
      return;
    }
    this.settings = {
      reminderEnabled: this.settings.reminderEnabled,
      reminderTime: this.settings.reminderTime,
      subjectTimes: this.settings.subjectTimes,
      themeIndex: this.settings.themeIndex,
      language: this.settings.language,
      targetRetention: this.settings.targetRetention,
      maxIntervalDays: this.settings.maxIntervalDays,
      focusMinutes: minutes
    };
    this.persist();
  }

  private updateTheme(index: number): void {
    this.settings = {
      reminderEnabled: this.settings.reminderEnabled,
      reminderTime: this.settings.reminderTime,
      subjectTimes: this.settings.subjectTimes,
      themeIndex: index,
      language: this.settings.language,
      targetRetention: this.settings.targetRetention,
      maxIntervalDays: this.settings.maxIntervalDays,
      focusMinutes: this.settings.focusMinutes
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

  /** 日期按当前界面语言格式化，不再固定输出中文 */
  private shortDate(ts: number): string {
    return I18n.dateShort(this.settings.language, ts);
  }

  private longDate(ts: number): string {
    return I18n.dateLong(this.settings.language, ts);
  }

  private weekday(ts: number): string {
    return I18n.weekday(this.settings.language, ts);
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
      return this.longDate(Date.now()) + ' · ' + this.weekday(Date.now());
    }
  }

  private setLanguage(code: string): void {
    this.settings = {
      reminderEnabled: this.settings.reminderEnabled,
      reminderTime: this.settings.reminderTime,
      subjectTimes: this.settings.subjectTimes,
      themeIndex: this.settings.themeIndex,
      language: code,
      targetRetention: this.settings.targetRetention,
      maxIntervalDays: this.settings.maxIntervalDays,
      focusMinutes: this.settings.focusMinutes
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

  private themeButton(): string {
    return this.settings.themeIndex === 0 ? Tokens.yellow : this.themeAccent(this.settings.themeIndex);
  }

  private themeInk(): string {
    return this.subjectInk(this.themeButton());
  }

  private pageBg(): string {
    const colors = this.pageColors(this.settings.themeIndex);
    const index = this.tab >= 0 && this.tab < colors.length ? this.tab : 0;
    return colors[index];
  }

  private nextSubjectColor(): string {
    for (let c = 0; c < SUBJECT_COLORS.length; c++) {
      let used = false;
      for (let i = 0; i < this.subjects.length; i++) {
        if (this.subjects[i].color === SUBJECT_COLORS[c]) {
          used = true;
          break;
        }
      }
      if (!used) {
        return SUBJECT_COLORS[c];
      }
    }
    return SUBJECT_COLORS[this.subjects.length % SUBJECT_COLORS.length];
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
      color: this.nextSubjectColor()
    };
    this.subjects = [...this.subjects, subject];
    this.draftSubjectId = subject.id;
    this.newSubjectName = '';
    this.getUIContext().getFocusController().clearFocus();
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
    animateTo({ curve: Motion.settle() }, () => {
      this.actionScale = 1;
    });
  }

  private closeItemActions(): void {
    if (!this.showItemActions) {
      return;
    }
    animateTo({ duration: Motion.base, curve: Motion.accel() }, () => {
      this.actionOverlayOpacity = 0;
      this.actionScale = 0.94;
    });
    setTimeout(() => {
      this.showItemActions = false;
      this.actionOverlayOpacity = 1;
      this.actionScale = 1;
      this.actionContentOpacity = 1;
    }, Motion.base);
  }

  private startEditItem(): void {
    this.editTitle = this.actionItem.title;
    this.editSubjectId = this.actionItem.subjectId;
    this.changeActionMode('edit');
  }

  private changeActionMode(mode: string): void {
    animateTo({ duration: Motion.instant, curve: Motion.accel() }, () => {
      this.actionContentOpacity = 0;
      this.actionScale = 0.98;
    });
    setTimeout(() => {
      this.actionMode = mode;
      this.actionContentOpacity = 0;
      this.actionScale = 0.98;
      animateTo({ curve: Motion.settle() }, () => {
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
    animateTo({ curve: Motion.snap() }, () => {
      this.confirmScale = 1;
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
    animateTo({ curve: Motion.snap() }, () => {
      this.confirmScale = 1;
    });
  }

  /** 确认框收起：缩回去再撤 */
  private closeConfirmAnimated(): void {
    if (!this.showConfirm) {
      return;
    }
    animateTo({ duration: Motion.quick, curve: Motion.accel() }, () => {
      this.confirmScale = 0.94;
    });
    setTimeout(() => {
      this.showConfirm = false;
      this.confirmScale = 1;
    }, Motion.quick);
  }

  private cancelConfirm(): void {
    this.closeConfirmAnimated();
  }

  private executeConfirm(): void {
    const kind = this.confirmKind;
    const subjectId = this.confirmSubjectId;
    const itemId = this.confirmItemId;
    this.closeConfirmAnimated();
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
    if (this.reviewItem.id === id) {
      this.closeReview();
    }
    this.items = this.items.filter((item: StudyItem) => item.id !== id);
    this.logs = this.logs.filter((log: ReviewLog) => log.itemId !== id);
    this.persist();
    this.syncReminder();
    this.toast(this.t('toastDeleted'));
  }

  /** 记录页：卡片从下方叠上来，逐张落位 */
  private playRecords(): void {
    const total: number = this.items.length;
    const shown: number = Math.min(total, 12);
    const reset: number[] = [];
    for (let i = 0; i < 12; i++) {
      reset.push(i < shown ? 0 : 1);
    }
    this.recIn = reset;
    for (let i = 0; i < shown; i++) {
      setTimeout(() => {
        animateTo({ curve: Motion.snap() }, () => {
          const next = this.recIn.slice();
          next[i] = 1;
          this.recIn = next;
        });
      }, Math.min(i, 8) * 55);
    }
  }

  /** 设置页：和今日页同一套模板，三方向轮流进 */
  private playSettings(): void {
    this.setIn = [0, 0, 0, 0, 0];
    for (let i = 0; i < 5; i++) {
      setTimeout(() => {
        animateTo({ curve: Motion.settle() }, () => {
          const next = this.setIn.slice();
          next[i] = 1;
          this.setIn = next;
        });
      }, i * 80);
    }
  }

  private playForm(): void {
    this.formProgress = 0;
    animateTo({ curve: Motion.settle(), delay: 140 }, () => {
      this.formProgress = 1;
    });
  }

  private playDots(): void {
    this.dotVisible = 0;
    for (let i = 0; i < 6; i++) {
      setTimeout(() => {
        this.dotVisible = i + 1;
      }, i * 90);
    }
  }

  private curveDotLabels(): string[] {
    const labels: string[] = [this.t('todayNode')];
    let cursor: StudyItem = emptyItem();
    cursor.scheduleMode = 'fsrs';
    let at = Date.now();
    for (let i = 0; i < 5; i++) {
      const result = scheduleFsrs(cursor, 3, at, this.settings.targetRetention, this.settings.maxIntervalDays);
      labels.push(this.t('days', result.nextIntervalDays));
      cursor = {
        id: cursor.id,
        subjectId: cursor.subjectId,
        title: cursor.title,
        createdAt: cursor.createdAt,
        scheduleMode: 'fsrs',
        curveStage: 0,
        fixedIntervalDays: 3,
        currentIntervalDays: result.nextIntervalDays,
        nextReviewAt: result.nextAt,
        lastReviewedAt: at,
        reviewCount: cursor.reviewCount + 1,
        status: 'active',
        fsrsStability: result.stability,
        fsrsDifficulty: result.difficulty,
        fsrsState: result.state,
        fsrsScheduledDays: result.scheduledDays,
        fsrsLapses: result.lapses,
        fsrsVersion: 6
      };
      at = result.nextAt;
    }
    return labels;
  }

  private playCalendarRows(): void {
    const total = this.calendarDays;
    const xs: number[] = [];
    const alphas: number[] = [];
    for (let i = 0; i < total; i++) {
      xs.push(this.mv(48));
      alphas.push(0);
    }
    this.calendarX = xs;
    this.calendarAlpha = alphas;
    // 每一行都入场，滑到哪儿切换天数看到的都一样；行多时压缩间隔，整体仍收在 0.8s 内
    const step = Math.min(55, Math.round(780 / total));
    setTimeout(() => {
      for (let i = 0; i < total; i++) {
        setTimeout(() => {
          animateTo({ curve: Motion.bounce() }, () => {
            const hit = this.calendarX.slice();
            hit[i] = 0;
            this.calendarX = hit;
            const lit = this.calendarAlpha.slice();
            lit[i] = 1;
            this.calendarAlpha = lit;
          });
        }, i * step);
      }
    }, 16);
  }

  private calX(index: number): number {
    return index < this.calendarX.length ? this.calendarX[index] : 0;
  }

  private calAlpha(index: number): number {
    return index < this.calendarAlpha.length ? this.calendarAlpha[index] : 1;
  }

  private setCalendarDays(days: number): void {
    if (this.calendarDays === days) {
      return;
    }
    this.calendarDays = days;
    this.playCalendarRows();
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
      if (this.showTimePicker) {
        this.TimePickerOverlay()
      }
      if (this.showFocusClock) {
        this.FocusClockOverlay()
      }
      if (this.showFocusSummary) {
        this.FocusSummaryOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBg())
    .animation({ duration: 320, curve: Motion.decel() })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      const w: number = Number(newValue.width);
      const h: number = Number(newValue.height);
      this.vpWidth = w;
      this.vpHeight = h;
      // 左右分栏只在「够宽且确实是横向」时启用：
      // 竖屏平板（如 960x1440）宽度也超过 840，套用分栏会把内容挤到左上角
      this.isWide = w >= 840 && w > h * 1.05;
      this.isTablet = w >= 700;
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
        if (this.focusRunning && this.tab !== 0) {
          this.FocusMiniBar()
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
      if (this.focusRunning && this.tab !== 0) {
        this.FocusMiniBar()
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
      Text('v1.1.2')
        .fontSize(7)
        .fontColor(Tokens.mutedSoft)
        .margin({ bottom: 20 })
    }
    .width(124)
    .height('100%')
    .backgroundColor(this.pageBg())
    .animation({ duration: 320, curve: Motion.decel() })
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
        .animation({ duration: 180, curve: Motion.decel() })
    }
    .width(112)
    .height(88)
    .justifyContent(FlexAlign.Center)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.94 })
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
      Stack() {
        Image($r('app.media.tomato'))
          .width(20)
          .height(20)
      }
      .width(34)
      .height(34)
      .borderRadius(17)
      .backgroundColor(this.focusRunning ? '#FFE3D8' : '#FFEDE6')
      .borderWidth(1)
      .borderColor(this.focusRunning ? '#FF6542' : '#40FF6542')
      .margin({ right: showAdd ? 8 : 0 })
      // 计时开始/结束时，这枚按钮的底色和描边跟着变，别硬切
      .animation({ duration: Motion.quick, curve: Motion.standard() })
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
      .onClick(() => {
        this.openFocusClock();
      })
      if (showAdd) {
        Button(this.t('newEntry'))
          .height(34)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeInk())
          .backgroundColor(this.themeButton())
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
    .animation({ duration: 320, curve: Motion.decel() })
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
        .scale({ x: this.countPop, y: this.countPop })
        .margin({ left: 12 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .translate({ x: (1 - this.todayTitleIn) * -this.mv(72) })
      .opacity(0.3 + 0.7 * Math.min(1, this.todayTitleIn * 1.8))
      .margin({ top: this.isWide ? 10 : 8, bottom: this.overdueItems().length > 0 ? 10 : 16 })

      // 欠账要摆在明面上：漏了几天、最早欠到哪天
      if (this.overdueItems().length > 0) {
        Text(this.t('overdueHint', this.overdueItems().length, this.oldestOverdueLabel()))
          .fontSize(11.5)
          .fontColor(Tokens.coral)
          .margin({ bottom: 16 })
          .translate({ x: (1 - this.todayTitleIn) * -this.mv(72) })
          .opacity(0.3 + 0.7 * Math.min(1, this.todayTitleIn * 1.8))
      }

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
              .translate({ y: (1 - this.todayProgress) * (this.mv(36) + index * this.mv(8)) })
              .opacity(0.3 + 0.7 * Math.min(1, this.todayProgress * 1.8))
              // 复习完一条就从列表里消失：淡出同时往上收，别让下面整排瞬间跳位
              .transition(TransitionEffect.OPACITY
                .combine(TransitionEffect.translate({ y: this.mv(12) }))
                .animation({ duration: 280, curve: Motion.decel() }))
            }, (item: StudyItem) => item.id)
          }
          if (this.dueItems().length === 0 && this.todayCreatedItems().length > 0 && !this.isWide) {
            Row()
              .width('100%')
              .height(90)
          }
          if (this.todayCreatedItems().length > 0) {
            Column() {
              this.TodayLogged()
            }
            .width('100%')
            .translate({ x: (1 - this.todayLoggedIn) * this.mv(72) })
            .opacity(0.3 + 0.7 * Math.min(1, this.todayLoggedIn * 1.8))
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
        .fontColor(this.themeInk())
        .backgroundColor(this.themeButton())
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
    .transition(TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: this.mv(16) }))
      .animation({ duration: 260, curve: Motion.decel() }))
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
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
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
            Text(this.findSubject(item.subjectId).name + '  ·  ' + this.t('next') + ' ' + this.shortDate(item.nextReviewAt))
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
        .translate({ y: (1 - this.todayProgress) * (this.mv(20) + index * this.mv(5)) })
        .opacity(Math.min(1, this.todayProgress))
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.translate({ y: -10 }))
          .animation({ duration: 280, curve: Motion.decel() }))
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
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
        Text(this.findSubject(item.subjectId).name)
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor(Tokens.muted)
        Text(item.title)
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor(Tokens.ink)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
        Text(this.itemSubtitle(item))
          .fontSize(11.5)
          .fontColor(this.itemSubtitleColor(item))
          .margin({ top: 4 })
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
    .scale({ x: this.pressedItemId === item.id ? 0.985 : 1, y: this.pressedItemId === item.id ? 0.985 : 1 })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        animateTo({ duration: 90, curve: Motion.decel() }, () => {
          this.pressedItemId = item.id;
        });
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        animateTo({ duration: 160, curve: Motion.decel() }, () => {
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
          Text(this.shortDate(Date.now()))
            .fontSize(7.5)
            .fontColor(Tokens.mutedSoft)
          Text(this.weekday(Date.now()))
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
            .fontColor(this.draftSubjectId === subject.id ? this.subjectInk(subject.color) : Tokens.inkSoft)
            .backgroundColor(this.draftSubjectId === subject.id ? subject.color : Tokens.surface)
            .borderWidth(1)
            .borderColor(this.draftSubjectId === subject.id ? subject.color : Tokens.line)
            .borderRadius(16)
            .padding({ left: 12, right: 12 })
            .margin({ right: 6, bottom: 6 })
            .scale({ x: this.draftSubjectId === subject.id ? 1.06 : 1, y: this.draftSubjectId === subject.id ? 1.06 : 1 })
            .animation({ duration: 220, curve: Motion.decel() })
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
          animateTo({ duration: 180, curve: Motion.decel() }, () => {
            this.titleBorderColor = '#C9A24A';
          });
        })
        .onBlur(() => {
          this.titleFocused = false;
          animateTo({ duration: 180, curve: Motion.decel() }, () => {
            this.titleBorderColor = '#B3FFFFFF';
          });
        })
        .onChange((value: string) => {
          this.draftTitle = value;
        })

      Row() {
          Text(this.t('reviewMode'))
            .fontSize(9)
            .fontColor(Tokens.muted)
          Blank()
          Button(this.t('fsrsMode'))
            .height(28)
            .fontSize(9.5)
            .fontColor(this.draftMode === 'fsrs' ? this.themeInk() : Tokens.inkSoft)
            .backgroundColor(this.draftMode === 'fsrs' ? this.themeButton() : Tokens.surface)
            .borderWidth(1)
            .borderColor(this.draftMode === 'fsrs' ? this.themeButton() : Tokens.line)
            .borderRadius(14)
            .padding({ left: 12, right: 12 })
            .animation({ duration: 160, curve: Motion.standard() })
            .onClick(() => {
              this.switchMode('fsrs');
            })
          Button(this.t('fixedMode'))
            .height(28)
            .fontSize(9.5)
            .fontColor(this.draftMode === 'fixed' ? this.themeInk() : Tokens.inkSoft)
            .backgroundColor(this.draftMode === 'fixed' ? this.themeButton() : Tokens.surface)
            .borderWidth(1)
            .borderColor(this.draftMode === 'fixed' ? this.themeButton() : Tokens.line)
            .borderRadius(14)
            .padding({ left: 12, right: 12 })
            .margin({ left: 6 })
            .animation({ duration: 160, curve: Motion.standard() })
            .onClick(() => {
              this.switchMode('fixed');
            })
        }
        .width('100%')
        .margin({ top: 14 })

          Column() {
            Stack({ alignContent: Alignment.TopStart }) {
              Row() {
                ForEach(this.curveDotLabels(), (label: string, index: number) => {
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
                  .translate({ y: this.dotVisible > index ? 0 : this.mv(10) })
                  .scale({ x: this.dotVisible > index ? 1 : 0.5, y: this.dotVisible > index ? 1 : 0.5 })
                  .animation({ duration: 220, curve: Motion.decel() })
                })
              }
              .width('100%')
              .margin({ top: 12 })
              .opacity(this.draftMode === 'fsrs' ? 1 : 0)
              .enabled(this.draftMode === 'fsrs')

              Row() {
                Stack({ alignContent: Alignment.Center }) {
                  Text('-')
                    .fontSize(18)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Tokens.inkSoft)
                }
                .width(34)
                .height(30)
                .backgroundColor(Tokens.surface)
                .borderWidth(1)
                .borderColor(Tokens.line)
                .borderRadius(10)
                .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                .onClick(() => {
                  this.draftFixedDays = Math.max(1, this.draftFixedDays - 1);
                })
                Text(this.t('fixedDaysHint', this.draftFixedDays))
                  .layoutWeight(1)
                  .fontSize(10)
                  .fontColor(Tokens.muted)
                  .textAlign(TextAlign.Center)
                Stack({ alignContent: Alignment.Center }) {
                  Text('+')
                    .fontSize(18)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Tokens.inkSoft)
                }
                .width(34)
                .height(30)
                .backgroundColor(Tokens.surface)
                .borderWidth(1)
                .borderColor(Tokens.line)
                .borderRadius(10)
                .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                .onClick(() => {
                  this.draftFixedDays = Math.min(90, this.draftFixedDays + 1);
                })
              }
              .width('100%')
              .margin({ top: 10 })
              .opacity(this.draftMode === 'fixed' ? 1 : 0)
              .enabled(this.draftMode === 'fixed')
            }
            .width('100%')
            .height(this.draftMode === 'fixed' ? 52 : 40)
            .clip(true)
            .animation({ duration: 240, curve: Motion.standard() })
          }
          .width('100%')
          .opacity(this.modeFade)
          .scale({ x: 0.96 + 0.04 * this.modeFade, y: 0.96 + 0.04 * this.modeFade })

        Column() {
          Text(this.t('curveForecastHint'))
            .width('100%')
            .fontSize(8.5)
            .fontColor(Tokens.muted)
            .textAlign(TextAlign.Center)
            .margin({ top: 3 })
        }
        .width('100%')
        .height(this.draftMode === 'fsrs' ? 18 : 0)
        .opacity(this.draftMode === 'fsrs' ? 1 : 0)
        .clip(true)
        .animation({ duration: 240, curve: Motion.standard() })

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
          .selectedColor(this.themeButton())
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
        .fontColor(this.themeInk())
        .backgroundColor(this.themeButton())
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
    .translate({ y: (1 - this.formProgress) * this.mv(18) })
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
        Text(this.t('items', this.items.length))
          .fontSize(11)
          .fontColor(Tokens.muted)
      }
      .width('100%')
      .margin({ top: 24, bottom: 18 })

      if (this.focusSessions.length > 0) {
        this.FocusWeekCard()
      }

      if (this.items.length === 0) {
        Text(this.t('noRecords'))
          .fontSize(14)
          .fontColor(Tokens.muted)
          .margin({ top: 80 })
      } else {
        List() {
          ForEach(this.sortedItems(), (item: StudyItem, index: number) => {
            ListItem() {
              Row() {
                // 时间轴：竖线从上往下生长，长到哪行哪行被牵出来
                Column() {
                  Column()
                    .width(1.5)
                    .height('100%')
                    .backgroundColor(Tokens.lineStrong)
                    .scale({ x: 1, y: this.recIn[Math.min(index, 11)], centerY: 0 })
                }
                .width(14)
                .height(this.recRowH + 10)
                .alignItems(HorizontalAlign.Center)

                // 日期：在线的右边、卡片外面
                Column() {
                  Text(this.shortDate(item.createdAt))
                    .fontSize(11)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Tokens.muted)
                  Text(this.weekday(item.createdAt))
                    .fontSize(9)
                    .fontColor(Tokens.mutedSoft)
                    .margin({ top: 2 })
                }
                .width(62)
                .padding({ top: 16 })
                .alignItems(HorizontalAlign.Start)
                .opacity(this.recIn[Math.min(index, 11)])

                Row() {
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
                  Text(this.shortDate(item.nextReviewAt))
                    .fontSize(10)
                    .fontColor(Tokens.muted)
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.End)
                .margin({ right: this.isWide ? 14 : 8 })
              }
              .layoutWeight(1)
              .padding(16)
              .backgroundColor(Tokens.surfaceSoft)
              .borderRadius(18)
              .borderWidth(1)
              .borderColor('#B3FFFFFF')
              .translate({ x: (1 - this.recIn[Math.min(index, 11)]) * -this.mv(26) })
              .opacity(this.recIn[Math.min(index, 11)])
              .transition(TransitionEffect.OPACITY
                .combine(TransitionEffect.translate({ x: -this.mv(20) }))
                .animation({ duration: 280, curve: Motion.decel() }))
              .onAreaChange((_o: Area, n: Area) => {
                const h: number = Number(n.height);
                if (h > 1 && Math.abs(h - this.recRowH) > 0.5) {
                  this.recRowH = h;
                }
              })
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
              .onClick(() => {
                this.openItemActions(item);
              })
              .gesture(LongPressGesture().onAction(() => {
                this.openItemActions(item);
              }))
                }
                .width('100%')
                .alignItems(VerticalAlign.Top)
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
      Column() {
        Row() {
          Column() {
            Text(this.t('calendarTitle'))
              .fontSize(this.isWide ? 44 : 32)
              .fontWeight(FontWeight.Bold)
              .fontColor(Tokens.ink)
            Text(this.t('nextDays', this.calendarDays))
              .fontSize(11)
              .fontColor(Tokens.muted)
              .margin({ top: 6 })
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          // 看多远由自己定：7 天够用，30 天看一整月
          Row({ space: 6 }) {
            ForEach([7, 14, 30], (value: number) => {
              Text(this.t('days', value))
                .fontSize(10.5)
                .fontWeight(this.calendarDays === value ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.calendarDays === value ? '#6C4B00' : Tokens.muted)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .backgroundColor(this.calendarDays === value ? Tokens.yellowSoft : Tokens.surfaceSoft)
                .borderRadius(12)
                // 选哪个范围，底色和字色滑过去，别硬切
                .animation({ duration: Motion.quick, curve: Motion.standard() })
                .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.92 })
                .onClick(() => {
                  this.setCalendarDays(value);
                })
            }, (value: number) => '' + value)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)
        .margin({ top: 24, bottom: 18 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: this.isWide ? 52 : 20, right: this.isWide ? 52 : 20 })

      Scroll() {
        Column({ space: 8 }) {
          ForEach(this.upcoming(), (day: DayCount, index: number) => {
            Row() {
              Column() {
                Text(this.shortDate(day.date))
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Tokens.ink)
                Text(this.weekday(day.date))
                  .fontSize(9)
                  .fontColor(Tokens.muted)
                  .margin({ top: 2 })
                if (index === 0 && this.overdueItems().length > 0) {
                  Text(this.t('overdueInDay', this.overdueItems().length))
                    .fontSize(8.5)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Tokens.coral)
                    .margin({ top: 3 })
                    .maxLines(1)
                }
              }
              .width(64)
              .alignItems(HorizontalAlign.Start)

              Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
                if (day.count === 0) {
                  Text(this.t('noPlan'))
                    .fontSize(11)
                    .fontColor(Tokens.mutedSoft)
                } else {
                  ForEach(this.dayItems(day.date, index === 0), (item: StudyItem) => {
                    Row() {
                      Circle({ width: 6, height: 6 })
                        .fill(this.findSubject(item.subjectId).color)
                      Text(item.title)
                        .fontSize(11)
                        .fontColor(Tokens.inkSoft)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .flexShrink(1)
                        .margin({ left: 7 })
                    }
                    .padding({ left: 9, right: 9, top: 6, bottom: 6 })
                    .backgroundColor(Tokens.surface)
                    .borderRadius(10)
                    .margin({ right: 6, bottom: 6 })
                    .constraintSize({ maxWidth: '100%' })
                  }, (item: StudyItem) => item.id)
                }
              }
              .layoutWeight(1)
            }
            .width('100%')
            .padding(day.count === 0
              ? { left: 16, right: 16, top: 10, bottom: 10 }
              : { left: 16, right: 16, top: 16, bottom: 16 })
            .alignItems(VerticalAlign.Top)
            .backgroundColor(day.count === 0 ? '#66FFFDF8' : Tokens.surfaceSoft)
            .borderRadius(18)
            .borderWidth(day.count === 0 ? 0 : 1)
            .borderColor('#B3FFFFFF')
            .opacity(Math.min(1, this.calAlpha(index)))
            .translate({ x: this.calX(index) })
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
      .padding({ left: this.isWide ? 52 : 20, right: this.isWide ? 52 : 20 })
    }
    .width('100%')
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .opacity(this.pageOpacity)
    .translate({ x: this.pageShift })
    .clip(true)
    .padding({ bottom: 24 })
  }

  @Builder SettingsPage() {
    Column() {
      Column() {
        Text(this.t('settingsTitle'))
          .fontSize(this.isWide ? 44 : 32)
          .fontWeight(FontWeight.Bold)
          .fontColor(Tokens.ink)
          .margin({ top: 24, bottom: 18 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: this.isWide ? 52 : 20, right: this.isWide ? 52 : 20 })

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
            .selectedColor(this.themeButton())
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
          Row({ space: 5 }) {
            Text(this.settings.reminderTime)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.settings.reminderEnabled ? Tokens.inkSoft : Tokens.mutedSoft)
            Text('▾')
              .fontSize(9)
              .fontColor(Tokens.mutedSoft)
              .margin({ bottom: 2 })
          }
          .padding({ left: 14, right: 12, top: 8, bottom: 8 })
          .backgroundColor(Tokens.surface)
          .borderRadius(10)
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.94 })
          .onClick(() => {
            this.openTimePicker();
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
            .transition(TransitionEffect.OPACITY
              .combine(TransitionEffect.translate({ y: -6 }))
              .animation({ duration: Motion.quick, curve: Motion.decel() }))
        }

      }
      .width('100%')
      .padding(18)
      .backgroundColor(Tokens.surfaceSoft)
      .borderRadius(22)
      .borderWidth(1)
      .borderColor('#B3FFFFFF')
      .translate({ x: (1 - this.setIn[0]) * -this.mv(72) })
      .opacity(0.3 + 0.7 * Math.min(1, this.setIn[0] * 1.8))

      Column() {
        Row() {
          Column() {
            Text(this.t('retentionTitle'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Tokens.ink)
            Text(this.t('retentionHint'))
              .fontSize(9.5)
              .fontColor(Tokens.muted)
              .margin({ top: 3 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Blank()
          Text(Math.round(this.settings.targetRetention * 100) + '%')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeAccent(this.settings.themeIndex))
            .margin({ left: 12 })
          Button(this.retentionUnlocked ? this.t('retentionDone') : this.t('retentionAdjust'))
            .height(26)
            .fontSize(9)
            .fontColor(this.themeInk())
            .backgroundColor(this.themeButton())
            .borderRadius(13)
            .padding({ left: 10, right: 10 })
            .margin({ left: 8 })
            .onClick(() => {
              this.retentionUnlocked = !this.retentionUnlocked;
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Slider({ value: Math.round(this.settings.targetRetention * 100), min: 80, max: 95, step: 1, style: SliderStyle.OutSet })
          .width('100%')
          .selectedColor(this.themeButton())
          .blockColor(this.themeButton())
          .trackColor('#E6DCC8')
          .enabled(this.retentionUnlocked)
          .opacity(this.retentionUnlocked ? 1 : 0.35)
          .margin({ top: 12 })
          .onChange((value: number, mode: SliderChangeMode) => {
            this.updateRetention(value);
            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
              this.persist();
            }
          })

        Row() {
          Text('80%')
            .fontSize(9)
            .fontColor(Tokens.mutedSoft)
          Blank()
          Text('95%')
            .fontSize(9)
            .fontColor(Tokens.mutedSoft)
        }
        .width('100%')

        Text(this.t('retentionExplain'))
          .width(this.isWide ? 520 : '100%')
          .fontSize(this.isWide ? 10.5 : 10)
          .lineHeight(this.isWide ? 16 : 15)
          .fontColor(Tokens.inkSoft)
          .margin({ top: 10 })

        Divider()
          .color(Tokens.line)
          .margin({ top: 16, bottom: 14 })

        // 超过上限的间隔一律按上限走
        Text(this.t('maxIntervalTitle'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Tokens.ink)

        Row({ space: 6 }) {
          ForEach([90, 180, 365, 0], (value: number) => {
            Text(value === 0 ? this.t('unlimited') : this.t('daysShort', value))
              .fontSize(10)
              .fontWeight(this.settings.maxIntervalDays === value ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.settings.maxIntervalDays === value ? '#6C4B00' : Tokens.muted)
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .backgroundColor(this.settings.maxIntervalDays === value ? Tokens.yellowSoft : Tokens.surface)
              .borderRadius(11)
              .animation({ duration: Motion.quick, curve: Motion.standard() })
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.92 })
              .onClick(() => {
                this.updateMaxInterval(value);
              })
          }, (value: number) => '' + value)
        }
        .margin({ top: 10 })

        Divider()
          .color(Tokens.line)
          .margin({ top: 16, bottom: 14 })

        // 番茄钟一轮多长；大圆盘上不再调，统一在这儿改
        Text(this.t('focusSettingTitle'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Tokens.ink)

        Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach([15, 20, 25, 30, 45, 60], (value: number) => {
            Text(this.t('minutesShort', value))
              .fontSize(10)
              .fontWeight(this.settings.focusMinutes === value ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.settings.focusMinutes === value ? '#6C4B00' : Tokens.muted)
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .backgroundColor(this.settings.focusMinutes === value ? Tokens.yellowSoft : Tokens.surface)
              .borderRadius(11)
              .margin({ right: 6, bottom: 6 })
              .animation({ duration: Motion.quick, curve: Motion.standard() })
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.92 })
              .onClick(() => {
                this.updateFocusMinutes(value);
              })
          }, (value: number) => '' + value)
        }
        .margin({ top: 10 })

      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(18)
      .backgroundColor(Tokens.surfaceSoft)
      .borderRadius(22)
      .borderWidth(1)
      .borderColor('#B3FFFFFF')
      .translate({ y: (1 - this.setIn[1]) * this.mv(44) })
      .opacity(0.3 + 0.7 * Math.min(1, this.setIn[1] * 1.8))

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
                .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.85 })
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
            .fontColor(this.themeInk())
            .backgroundColor(this.themeButton())
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
      .translate({ x: (1 - this.setIn[2]) * this.mv(72) })
      .opacity(0.3 + 0.7 * Math.min(1, this.setIn[2] * 1.8))

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
            .borderColor(this.settings.themeIndex === index ? this.themeAccent(index) : '#E6DCC8')
            .scale({ x: this.settings.themeIndex === index ? 1.02 : 1, y: this.settings.themeIndex === index ? 1.02 : 1 })
            .animation({ duration: 240, curve: Motion.decel() })
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
      .translate({ x: (1 - this.setIn[3]) * -this.mv(72) })
      .opacity(0.3 + 0.7 * Math.min(1, this.setIn[3] * 1.8))

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
              .fontColor(this.settings.language === option.code ? this.themeInk() : Tokens.inkSoft)
              .backgroundColor(this.settings.language === option.code ? this.themeButton() : Tokens.surface)
              .borderWidth(1)
              .borderColor(this.settings.language === option.code ? this.themeButton() : '#E6DCC8')
              .borderRadius(15)
              .padding({ left: 12, right: 12 })
              .margin({ right: 6, bottom: 6 })
              .scale({ x: this.settings.language === option.code ? 1.04 : 1, y: this.settings.language === option.code ? 1.04 : 1 })
              .animation({ duration: 180, curve: Motion.decel() })
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
      .translate({ y: (1 - this.setIn[4]) * this.mv(44) })
      .opacity(0.3 + 0.7 * Math.min(1, this.setIn[4] * 1.8))


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
      .padding({ left: this.isWide ? 52 : 20, right: this.isWide ? 52 : 20 })
    }
    .width('100%')
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .opacity(this.pageOpacity)
    .translate({ x: this.pageShift })
    .clip(true)
    .padding({ bottom: 24 })
  }

  @Builder BottomNav() {
    Row() {
      ForEach([0, 1, 2, 3], (index: number) => {
        Column() {
          Image(this.tab === index ? this.navIcons[index] : this.navIconsMuted[index])
            .width(22)
            .height(22)
            .objectFit(ImageFit.Contain)
            .scale({ x: this.tab === index ? 1.08 : 1, y: this.tab === index ? 1.08 : 1 })
            .animation({ duration: 200, curve: Motion.snap() })
    
          Text(this.navLabel(index))
            .fontSize(8)
            .fontColor(this.tab === index ? '#6C4B00' : Tokens.mutedSoft)
            .margin({ top: 3 })
            .animation({ duration: 180, curve: Motion.decel() })
        }
        .layoutWeight(1)
        .height(62)
        .justifyContent(FlexAlign.Center)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.92 })
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
          .onClick(() => {
            this.closeReview();
          })

      Column() {
        if (this.isWide) {
          Row() {
            if (this.reviewStage === 'rating') {
              this.RatingCard()
            } else {
              this.EntryCard()
            }
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
        } else {
          Scroll() {
            Column({ space: 16 }) {
              if (this.reviewStage === 'rating') {
                this.RatingCard()
              } else {
                this.EntryCard()
              }
            }
            .width('100%')
            .justifyContent(FlexAlign.Start)
            .alignItems(HorizontalAlign.Start)
            .backgroundColor(this.pageBg())
            .animation({ duration: 320, curve: Motion.decel() })
            .padding({ left: 12, right: 12, top: 10, bottom: 12 })
            .borderRadius(28)
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: this.isWide ? 40 : 16, right: this.isWide ? 40 : 16, top: 10, bottom: 20 })
      .backgroundColor(this.isWide ? '#00000000' : Tokens.bg)
        .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
    .opacity(this.reviewOpacity)
    .scale({ x: this.reviewScale, y: this.reviewScale })
  }

  @Builder EntryCard() {
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
        Button(this.t('close'))
          .height(26)
          .fontSize(9)
          .fontColor('#6C4B00')
          .backgroundColor(Tokens.yellowSoft)
          .borderRadius(13)
          .padding({ left: 10, right: 10 })
          .onClick(() => {
            this.closeReview();
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
      Text(this.t('lastReview', this.shortDate(this.reviewItem.lastReviewedAt > 0 ? this.reviewItem.lastReviewedAt : this.reviewItem.createdAt)))
        .width('100%')
        .fontSize(10.5)
        .fontColor(Tokens.muted)
        .margin({ top: 8 })

      Row()
        .width('100%')
        .height(1)
        .backgroundColor(Tokens.line)
        .margin({ top: 22, bottom: 18 })

      Row({ space: 10 }) {
        Button(this.t('postponeTomorrow'))
          .layoutWeight(1)
          .height(48)
          .fontSize(12)
          .fontColor(Tokens.inkSoft)
          .backgroundColor(Tokens.surfaceSoft)
          .borderWidth(1)
          .borderColor(Tokens.line)
          .borderRadius(14)
          .onClick(() => {
            this.postponeReview();
          })
        Button(this.t('completeReview'))
          .layoutWeight(1)
          .height(48)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeInk())
          .backgroundColor(this.themeButton())
          .borderRadius(14)
          .onClick(() => {
            this.startRating();
          })
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

  @Builder RatingCard() {
    Column() {
      Row() {
        Button('←')
          .width(30)
          .height(30)
          .fontSize(14)
          .fontColor('#6C4B00')
          .backgroundColor(Tokens.yellowSoft)
          .borderRadius(15)
          .padding({ left: 0, right: 0 })
          .onClick(() => {
            this.backToEntry();
          })
        Text(this.findSubject(this.reviewItem.subjectId).name)
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor(Tokens.muted)
          .margin({ left: 10 })
        Text(this.t('reviewN', this.reviewItem.reviewCount + 1))
          .fontSize(9)
          .fontColor(Tokens.mutedSoft)
          .margin({ left: 8 })
        Blank()
        Button(this.t('close'))
          .height(26)
          .fontSize(9)
          .fontColor('#6C4B00')
          .backgroundColor(Tokens.yellowSoft)
          .borderRadius(13)
          .padding({ left: 10, right: 10 })
          .onClick(() => {
            this.closeReview();
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
      Text(this.t('lastReview', this.shortDate(this.reviewItem.lastReviewedAt > 0 ? this.reviewItem.lastReviewedAt : this.reviewItem.createdAt)))
        .width('100%')
        .fontSize(10.5)
        .fontColor(Tokens.muted)
        .margin({ top: 8 })

      Row()
        .width('100%')
        .height(1)
        .backgroundColor(Tokens.line)
        .margin({ top: 22, bottom: 18 })

      Text(this.t('rateTitle'))
        .width('100%')
        .fontSize(this.isWide ? 24 : 20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Tokens.ink)
      Text(this.t('retentionTitle') + ' ' + Math.round(this.settings.targetRetention * 100) + '%')
        .width('100%')
        .fontSize(11)
        .fontColor(Tokens.muted)
        .margin({ top: 8 })
      Text(this.t('retentionHint'))
        .width('100%')
        .fontSize(10)
        .fontColor(Tokens.mutedSoft)
        .lineHeight(16)
        .margin({ top: 4 })

      this.GradeCards()
    }
    .width(this.isWide ? 680 : '100%')
    .padding(this.isWide ? 32 : 22)
    .backgroundColor(Tokens.surface)
    .borderRadius(28)
    .borderWidth(1)
    .borderColor('#CCFFFFFF')
    .shadow({ radius: 40, color: '#24000000', offsetX: 0, offsetY: 20 })
  }

  @Builder GradeCards() {
    Column() {
      if (this.isWide) {
        Row({ space: 12 }) {
          ForEach(this.gradeNodes, (grade: number) => {
            Column() {
              this.GradeCard(grade)
            }
            .layoutWeight(1)
          }, (grade: number) => 'grade-' + grade)
        }
        .width('100%')
      } else {
        Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          ForEach(this.gradeNodes, (grade: number) => {
            Column() {
              this.GradeCard(grade)
            }
            .width('48%')
            .margin({ bottom: 10 })
          }, (grade: number) => 'grade-' + grade)
        }
        .width('100%')
      }
    }
    .width('100%')
    .margin({ top: 18 })
  }

  @Builder GradeCard(grade: number) {
    Column() {
      Row() {
        Circle({ width: 7, height: 7 })
          .fill(this.gradeColor(grade))
        Text(this.gradeLabel(grade))
          .fontSize(this.isWide ? 14 : 13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.gradeColor(grade))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: 7 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.gradeMeaning(grade))
        .width('100%')
        .fontSize(this.isWide ? 9.5 : 9)
        .fontColor(Tokens.muted)
        .lineHeight(this.isWide ? 13 : 12)
        .maxLines(2)
        .height(this.isWide ? 26 : 24)
        .margin({ top: 6 })

      Text(this.gradeIntervalText(grade))
        .width('100%')
        .fontSize(this.isWide ? 16 : 15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Tokens.ink)
        .margin({ top: 8 })
    }
    .width('100%')
    .padding(this.isWide ? 14 : 12)
    .backgroundColor(this.gradeTint(grade, '14'))
    .borderRadius(16)
    .borderWidth(1)
    .borderColor(this.gradeTint(grade, '3D'))
    .scale({ x: this.pressedGrade === grade ? 0.96 : 1, y: this.pressedGrade === grade ? 0.96 : 1 })
    .animation({ duration: 160, curve: Motion.decel() })
    .onClick(() => {
      this.finishReview(grade);
    })
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
          .fontColor(this.themeInk())
          .backgroundColor(this.themeButton())
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

  @Builder FocusMiniBar() {
    Column() {
      Row() {
        Image($r('app.media.tomato'))
          .width(15)
          .height(15)
          .opacity(this.focusPaused ? 0.4 : 1)
        Text(this.focusClock())
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(Tokens.ink)
          .margin({ left: 8 })
        Text(this.focusIsBreak ? this.t('focusBreaking') : this.t('focusCardTitle'))
          .fontSize(9.5)
          .fontColor(Tokens.muted)
          .margin({ left: 6 })
        Blank()
        Text('›')
          .fontSize(13)
          .fontColor(Tokens.mutedSoft)
      }
      .width(this.isWide ? 520 : '100%')
      .height(36)
      .padding({ left: 14, right: 14 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(Tokens.surfaceSoft)
      .borderRadius(18)
      .borderWidth(1)
      .borderColor('#A6FFC531')
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
      .onClick(() => {
        this.switchTab(0);
      })
    }
    .width('100%')
    .padding({ left: 20, right: 20, bottom: 8 })
    .transition(TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: this.mv(14) }))
      .animation({ duration: 260, curve: Motion.decel() }))
  }

  /** 整页的番茄钟：没开始时选时长，跑起来就是循环里的那一段 */
  @Builder FocusClockOverlay() {
    Column() {
      Row() {
        Blank()
        Text('×')
          .fontSize(24)
          .fontColor(Tokens.muted)
          .textAlign(TextAlign.Center)
          .width(44)
          .height(44)
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.88 })
          .onClick(() => {
            this.closeFocusClock();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 32 })
      .justifyContent(FlexAlign.End)

      Blank()

      Stack({ alignContent: Alignment.Center }) {
        Progress({
          value: this.focusRunning ? this.focusRemainingPercent() : 100,
          total: 100,
          type: ProgressType.Ring
        })
          .width(this.clockSize())
          .height(this.clockSize())
          .color(this.clockAccent())
          .backgroundColor('#2E5E4B30')
          .style({ strokeWidth: Math.max(9, this.clockSize() * 0.032), enableSmoothEffect: true })

        // 一圈一格一分钟：走过的那些淡下去，剩下的跟着圆弧一起减少
        ForEach(this.minuteTicks(), (index: number) => {
          Column() {
            Row()
              .width(Math.max(2, this.clockSize() * 0.008))
              .height(Math.max(4, this.clockSize() * 0.02))
              .borderRadius(2)
              .backgroundColor(this.clockAccent())
              .opacity(this.tickOpacity(index))
              // 每分钟走完一格时，那格是淡下去而不是直接消失
              .animation({ duration: Motion.slow, curve: Motion.standard() })
            Blank()
          }
          .width(this.clockSize() * 0.9)
          .height(this.clockSize() * 0.9)
          .rotate({ angle: index * 360 / this.tickCount() })
        }, (index: number) => '' + index)

        Column() {
          Image($r('app.media.tomato'))
            .width(this.clockSize() * 0.11)
            .height(this.clockSize() * 0.11)
            .opacity(this.focusRunning && this.focusPaused ? 0.45 : 1)

          if (this.focusRunning) {
            Column() {
              Text(this.focusClock())
                .fontSize(this.clockSize() * 0.26)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.focusPaused ? Tokens.muted : Tokens.ink)
                .fontFeature('"tnum" 1')
                .margin({ top: 8 })
              Text(this.roundLabel())
                .fontSize(Math.max(12, this.clockSize() * 0.055))
                .fontColor(Tokens.muted)
                .margin({ top: 6 })
            }
            .alignItems(HorizontalAlign.Center)
            .transition(this.clockSwap())
          } else {
            Column() {
              Text(this.minutesLabel(this.settings.focusMinutes))
                .fontSize(this.clockSize() * 0.15)
                .fontWeight(FontWeight.Bold)
                .fontColor(Tokens.ink)
                .fontFeature('"tnum" 1')
                .margin({ top: 12 })
              Text(this.t('focusTitle'))
                .fontSize(Math.max(10, this.clockSize() * 0.045))
                .fontColor(Tokens.mutedSoft)
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Center)
            .transition(this.clockSwap())
          }
        }
        .alignItems(HorizontalAlign.Center)
        .scale({ x: this.clockPop, y: this.clockPop })
      }
      .width(this.clockSize())
      .height(this.clockSize())

      if (this.focusRunning) {
        Text(this.t('focusElapsed', this.elapsedClock()) + ' · ' + this.minutesLabel(this.focusPlannedMinutes))
          .fontSize(13)
          .fontColor(Tokens.mutedSoft)
          .margin({ top: 22 })
          .transition(TransitionEffect.OPACITY
            .combine(TransitionEffect.translate({ y: 6 }))
            .animation({ duration: Motion.quick, curve: Motion.decel() }))
      }

      Blank()

      if (this.focusRunning) {
        Row() {
          Text(this.focusPaused ? this.t('focusResume') : this.t('focusPause'))
            .fontSize(14)
            .fontColor(Tokens.inkSoft)
            .textAlign(TextAlign.Center)
            .height(44)
            .padding({ left: 22, right: 22 })
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.94 })
            .onClick(() => {
              if (this.focusPaused) {
                this.resumeFocus();
              } else {
                this.pauseFocus();
              }
            })
          Text(this.t('focusEnd'))
            .fontSize(14)
            .fontColor(Tokens.coral)
            .textAlign(TextAlign.Center)
            .height(44)
            .padding({ left: 22, right: 22 })
            .margin({ left: 8 })
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.94 })
            .onClick(() => {
              this.stopFocusEarly();
            })
        }
        .margin({ bottom: 28 })
        .alignItems(VerticalAlign.Center)
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.translate({ y: -8 }))
          .animation({ duration: Motion.base, curve: Motion.decel() }))
      } else {
        Button(this.t('focusStartCycle'))
          .height(46)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeInk())
          .backgroundColor(this.themeButton())
          .borderRadius(23)
          .padding({ left: 30, right: 30 })
          .margin({ bottom: 36 })
          .transition(TransitionEffect.OPACITY
            .combine(TransitionEffect.translate({ y: 10 }))
            .animation({ duration: Motion.base, curve: Motion.decel() }))
          .onClick(() => {
            this.startCycle();
          })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBg())
    .scale({ x: this.clockScale, y: this.clockScale })
  }

  @Builder FocusSummaryOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Tokens.dim)
        .backdropBlur(6)
        .onClick(() => {
          this.closeSummary();
        })

      Column() {
        Text(this.t('focusSummary'))
          .fontSize(11)
          .fontColor(Tokens.muted)
          .margin({ top: 4 })

        Text(this.minutesLabel(this.summaryMinutes))
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(Tokens.ink)
          .letterSpacing(-0.5)
          .margin({ top: 6 })

        Text(this.t('focusReviewed', this.summaryItems, this.summaryRemembered))
          .fontSize(11.5)
          .fontColor(Tokens.inkSoft)
          .margin({ top: 10 })

        Text(this.t('focusSegments', this.summarySegments) + ' · ' + this.clockLabel(this.summaryStart) + ' – ' +
          this.clockLabel(this.summaryEnd))
          .fontSize(10)
          .fontColor(Tokens.mutedSoft)
          .margin({ top: 5 })

        Text(this.t('focusDone'))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeButton())
          .textAlign(TextAlign.Center)
          .width('100%')
          .height(44)
          .margin({ top: 10 })
          .onClick(() => {
            this.closeSummary();
          })
      }
      .width(244)
      .padding({ top: 20, bottom: 2, left: 14, right: 14 })
      .backgroundColor(Tokens.surface)
      .borderRadius(24)
      .borderWidth(1)
      .borderColor('#CCFFFFFF')
      .shadow({ radius: 36, color: '#24000000', offsetX: 0, offsetY: 16 })
      .scale({ x: this.summaryScale, y: this.summaryScale })
    }
    .width('100%')
    .height('100%')
  }

  @Builder FocusWeekCard() {
    Column() {
      Row() {
        Text(this.t('focusCardTitle'))
          .fontSize(10.5)
          .fontWeight(FontWeight.Medium)
          .fontColor(Tokens.muted)
        Blank()
        Text(this.t('focusTodayTotal', this.minutesLabel(this.todayFocusMinutes()), this.todayFocusCount()))
          .fontSize(10)
          .fontColor(Tokens.mutedSoft)
      }
      .width('100%')

      Row() {
        ForEach([0, 1, 2, 3, 4, 5, 6], (index: number) => {
          Column() {
            Row()
              .width(18)
              .height(this.weekBarHeight(this.weekFocus()[index]))
              .backgroundColor(index === this.todayWeekIndex() ? Tokens.coral : '#E8DCC4')
              .borderRadius(3)
              // 专注结束记进去之后，柱子长上来而不是瞬间变高
              .animation({ duration: Motion.base, curve: Motion.settle() })
            Text(this.weekday(this.weekDayTs(index)))
              .fontSize(8)
              .fontColor(index === this.todayWeekIndex() ? Tokens.coral : Tokens.mutedSoft)
              .margin({ top: 5 })
          }
          .layoutWeight(1)
          .height(54)
          .padding({ left: 3, right: 3 })
          .justifyContent(FlexAlign.End)
          .alignItems(HorizontalAlign.Center)
        }, (index: number) => 'w' + index)
      }
      .width('100%')
      .height(54)
      .margin({ top: 10 })
      .alignItems(VerticalAlign.Bottom)
    }
    .width(this.isWide ? 560 : '100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 10 })
    .backgroundColor(Tokens.surfaceSoft)
    .borderRadius(18)
    .borderWidth(1)
    .borderColor('#B3FFFFFF')
    .margin({ bottom: 18 })
    .transition(TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: this.mv(18) }))
      .animation({ duration: 300, curve: Motion.decel() }))
  }

  @Builder TimePickerOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Tokens.dim)
        .backdropBlur(6)
        .onClick(() => {
          this.cancelTimePicker();
        })

      Column() {
        Row() {
          TextPicker({ range: this.hourRange, selected: this.pickerHour })
            .width(58)
            .height(150)
            .defaultPickerItemHeight(34)
            .canLoop(false)
            .textStyle({ color: Tokens.mutedSoft, font: { size: 15 } })
            .selectedTextStyle({ color: Tokens.ink, font: { size: 21, weight: FontWeight.Medium } })
            .disappearTextStyle({ color: '#D8CEBA', font: { size: 13 } })
            .onChange((value: string | string[], index: number | number[]) => {
              this.pickerHour = index as number;
            })

          Text(':')
            .fontSize(19)
            .fontWeight(FontWeight.Medium)
            .fontColor(Tokens.ink)
            .margin({ left: 3, right: 3 })

          TextPicker({ range: this.minuteRange, selected: this.pickerMinute })
            .width(58)
            .height(150)
            .defaultPickerItemHeight(34)
            .canLoop(false)
            .textStyle({ color: Tokens.mutedSoft, font: { size: 15 } })
            .selectedTextStyle({ color: Tokens.ink, font: { size: 21, weight: FontWeight.Medium } })
            .disappearTextStyle({ color: '#D8CEBA', font: { size: 13 } })
            .onChange((value: string | string[], index: number | number[]) => {
              this.pickerMinute = index as number;
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)

        Row() {
          Text(this.t('cancel'))
            .fontSize(12.5)
            .fontColor(Tokens.muted)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(42)
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.94 })
            .onClick(() => {
              this.cancelTimePicker();
            })
          Text(this.t('confirm'))
            .fontSize(12.5)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeButton())
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(42)
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.94 })
            .onClick(() => {
              this.confirmTimePicker();
            })
        }
        .width('100%')
        .margin({ top: 2 })
      }
      .width(198)
      .padding({ top: 8, bottom: 4, left: 10, right: 10 })
      .backgroundColor(Tokens.surface)
      .borderRadius(22)
      .borderWidth(1)
      .borderColor('#CCFFFFFF')
      .shadow({ radius: 36, color: '#24000000', offsetX: 0, offsetY: 16 })
      .scale({ x: this.timePickerScale, y: this.timePickerScale })
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

        Text(this.findSubject(this.actionItem.subjectId).name + '  ·  ' + this.t('next') + ' ' + this.shortDate(this.actionItem.nextReviewAt))
          .fontSize(10)
          .fontColor(Tokens.muted)
          .width('100%')
          .margin({ top: 7 })

        Row() {
          Column() {
            Text(this.t('created'))
              .fontSize(8)
              .fontColor(Tokens.mutedSoft)
            Text(this.shortDate(this.actionItem.createdAt))
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
              .fontColor(this.themeInk())
              .backgroundColor(this.themeButton())
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
                .fontColor(this.editSubjectId === subject.id ? this.themeInk() : Tokens.inkSoft)
                .backgroundColor(this.editSubjectId === subject.id ? this.themeButton() : Tokens.surface)
                .borderWidth(1)
                .borderColor(this.editSubjectId === subject.id ? this.themeButton() : Tokens.line)
                .borderRadius(15)
                .padding({ left: 11, right: 11 })
                .margin({ right: 6, bottom: 6 })
                .scale({ x: this.editSubjectId === subject.id ? 1.04 : 1, y: this.editSubjectId === subject.id ? 1.04 : 1 })
                .animation({ duration: 180, curve: Motion.decel() })
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
              .fontColor(this.themeInk())
              .backgroundColor(this.themeButton())
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
      .constraintSize({
        maxHeight: this.keyboardHeight > 0
          ? Math.max(320, this.vpHeight - this.keyboardHeight - 24)
          : this.vpHeight * 0.84
      })
      .scrollBar(this.keyboardHeight > 0 ? BarState.On : BarState.Off)
      .scale({ x: this.composerScale, y: this.composerScale })
      .translate({ y: this.composerShift })
      .opacity(this.composerOpacity)
    }
    .width('100%')
    .height('100%')
  }
}
