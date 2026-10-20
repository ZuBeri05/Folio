import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AppData, Subject, StudyItem, ReviewLog, Settings, DayCount, SUBJECT_COLORS, createDefaultData, emptyItem, newId } from '../domain/Models';
import { Store } from '../data/Store';
import { scheduleNext, firstReviewAt, startOfDay, addDays, daysBetween, formatDate, formatShort, formatFull, weekdayCN, ratingLabel } from '../domain/Scheduling';
import { ReminderService } from '../services/ReminderService';
import { Tokens } from '../theme/Tokens';

@Entry
@Component
struct Index {
  @State items: StudyItem[] = [];
  @State logs: ReviewLog[] = [];
  @State subjects: Subject[] = [];
  @State settings: Settings = createDefaultData().settings;
  @State tab: number = 0;
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
  @State dotVisible: number = 6;
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
  private reviewBusy: boolean = false;

  private readonly navGlyphs: string[] = ['今', '记', '历', '设'];
  private readonly navLabels: string[] = ['今日', '记录', '日历', '设置'];
  private readonly curveNodes: number[] = [0, 1, 2, 3, 4, 5];

  aboutToAppear(): void {
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
    if (this.subjects.length > 0) {
      this.draftSubjectId = this.subjects[0].id;
    }
    this.playEntry();
    this.playDots();
    this.refreshNotificationState();
    if (this.settings.reminderEnabled && this.items.length > 0) {
      this.syncReminder();
    }
  }

  private playEntry(): void {
    this.listOpacity = 0;
    this.listShift = 16;
    setTimeout(() => {
      animateTo({ duration: 420, curve: Curve.EaseOut }, () => {
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
    this.composerScale = 0.92;
    this.composerShift = 24;
    this.composerOpacity = 0;
    this.composerDim = 0;
    animateTo({ duration: 360, curve: Curve.EaseOut }, () => {
      this.composerScale = 1;
      this.composerShift = 0;
      this.composerOpacity = 1;
      this.composerDim = 1;
    });
  }

  private closeComposer(): void {
    animateTo({ duration: 180, curve: Curve.EaseIn }, () => {
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
    }, 180);
  }

  private persist(): void {
    const context = getContext(this) as common.UIAbilityContext;
    const data: AppData = {
      subjects: this.subjects,
      items: this.items,
      logs: this.logs,
      settings: this.settings
    };
    Store.save(context, data).catch(() => {
      this.toast('保存失败，请重试');
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
      this.reminderError = error.message !== undefined ? error.message : '日历提醒未开启';
      this.toast('提醒设置失败，请检查日历权限');
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
    animateTo({ duration: 80, curve: Curve.EaseIn }, () => {
      this.pageOpacity = 0;
      this.pageShift = 0;
    });
    setTimeout(() => {
      this.tab = next;
      this.pageOpacity = 0;
      this.pageShift = next === 2 ? 0 : 14;
      animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
        this.pageOpacity = 1;
        this.pageShift = 0;
      });
      if (next === 0) {
        this.playEntry();
        this.playDots();
      }
      this.playCalendar();
    }, 80);
  }

  private itemSubtitle(item: StudyItem): string {
    const base = item.lastReviewedAt > 0 ? item.lastReviewedAt : item.createdAt;
    const days = daysBetween(base, new Date());
    const prefix = days === 0 ? '今天' : days + ' 天前';
    return prefix + '  ·  第 ' + (item.reviewCount + 1) + ' 次';
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
    return { id: '', itemId: '', reviewedAt: 0, rating: '', previousIntervalDays: 0, nextIntervalDays: 0, nextReviewAt: 0 };
  }

  private lastRating(itemId: string): string {
    const log = this.previousLog(itemId);
    return log.id.length > 0 ? ratingLabel(log.rating) : '首次';
  }

  private lastInterval(itemId: string): number {
    const log = this.previousLog(itemId);
    return log.id.length > 0 ? log.previousIntervalDays : 1;
  }

  private intervalHint(rating: string): string {
    const result = scheduleNext(this.reviewItem, rating, new Date());
    return result.nextIntervalDays === 1 ? '明天' : result.nextIntervalDays + ' 天后';
  }

  private curveLabels(): string[] {
    return ['开始', '第 1 次', '第 2 次', '今天', '下次', '之后'];
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
    animateTo({ duration: 120, curve: Curve.EaseOut }, () => {
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
    const result = scheduleNext(item, rating, now);
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
      status: item.status
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
      nextReviewAt: result.nextAt
    };
    this.logs = [log, ...this.logs];
    this.showReview = false;
    this.reviewScale = 1;
    this.pressedRating = '';
    this.reviewBusy = false;
    this.persist();
    this.syncReminder();
    this.toast('下次 ' + formatDate(result.nextAt));
  }

  private addItem(): void {
    const title = this.draftTitle.trim();
    if (title.length === 0) {
      this.toast('先写一句今天学了什么');
      return;
    }
    const now = new Date();
    const firstAt = firstReviewAt(this.draftMode, this.draftFixedDays, now);
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
      status: 'active'
    };
    animateTo({ duration: 320, curve: Curve.EaseOut }, () => {
      this.items = [item, ...this.items];
    });
    this.draftTitle = '';
    this.showComposer = false;
    this.switchTab(0);
    this.persist();
    this.syncReminder();
    this.toast('已保存，' + formatDate(firstAt) + ' 提醒');
  }

  private updateReminderEnabled(value: boolean): void {
    this.settings = {
      reminderEnabled: value,
      reminderTime: this.settings.reminderTime,
      subjectTimes: this.settings.subjectTimes
    };
    this.persist();
    this.syncReminder();
  }

  private updateReminderTime(value: string): void {
    this.settings = {
      reminderEnabled: this.settings.reminderEnabled,
      reminderTime: value,
      subjectTimes: this.settings.subjectTimes
    };
  }

  private saveSettings(): void {
    const pattern: RegExp = /^([01]?[0-9]|2[0-3]):[0-5][0-9]$/;
    if (!pattern.test(this.settings.reminderTime)) {
      this.toast('时间格式请用 20:00');
      return;
    }
    this.persist();
    this.syncReminder();
    this.toast('设置已保存');
  }

  private addSubject(): void {
    const name = this.newSubjectName.trim();
    if (name.length === 0) {
      this.toast('先写科目名');
      return;
    }
    for (let i = 0; i < this.subjects.length; i++) {
      if (this.subjects[i].name === name) {
        this.toast('这个科目已经有了');
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
    this.toast('已添加 ' + name);
  }

  private openItemActions(item: StudyItem): void {
    this.actionItem = item;
    this.editTitle = item.title;
    this.editSubjectId = item.subjectId;
    this.actionMode = 'view';
    this.showItemActions = true;
    this.actionScale = 0.94;
    animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.actionScale = 1;
    });
  }

  private closeItemActions(): void {
    this.showItemActions = false;
  }

  private startEditItem(): void {
    this.editTitle = this.actionItem.title;
    this.editSubjectId = this.actionItem.subjectId;
    this.actionMode = 'edit';
  }

  private saveItemEdit(): void {
    const title = this.editTitle.trim();
    if (title.length === 0) {
      this.toast('标题不能为空');
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
      status: this.actionItem.status
    };
    this.items = this.items.map((item: StudyItem) => item.id === updated.id ? updated : item);
    this.showItemActions = false;
    this.persist();
    this.toast('已修改');
  }

  private deleteFromAction(): void {
    const id = this.actionItem.id;
    this.showItemActions = false;
    this.deleteItem(id);
  }

  private deleteItem(id: string): void {
    this.items = this.items.filter((item: StudyItem) => item.id !== id);
    this.logs = this.logs.filter((log: ReviewLog) => log.itemId !== id);
    if (this.reviewItem.id === id) {
      this.showReview = false;
    }
    this.persist();
    this.syncReminder();
    this.toast('已删除');
  }

  private playDots(): void {
    this.dotVisible = 0;
    for (let i = 0; i < 6; i++) {
      setTimeout(() => {
        this.dotVisible = i + 1;
      }, i * 70);
    }
  }

  private playCalendar(): void {
    this.calendarProgress = 0;
    animateTo({ duration: 250, curve: Curve.EaseOut }, () => {
      this.calendarProgress = 1;
    });
    setTimeout(() => {
      animateTo({ duration: 80, curve: Curve.EaseOut }, () => {
        this.calendarProgress = 0.92;
      });
    }, 250);
    setTimeout(() => {
      animateTo({ duration: 120, curve: Curve.EaseOut }, () => {
        this.calendarProgress = 1;
      });
    }, 330);
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Tokens.bg)
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
  }

  @Builder Rail() {
    Column() {
      Column() {
        Image($r('app.media.app_icon'))
          .width(44)
          .height(44)
          .borderRadius(14)
        Text('结绳')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(Tokens.ink)
          .letterSpacing(2)
          .margin({ top: 8 })
        Text('JIESHENG')
          .fontSize(6)
          .fontColor(Tokens.mutedSoft)
          .letterSpacing(1.4)
          .margin({ top: 2 })
      }
      .margin({ top: 24 })
      .alignItems(HorizontalAlign.Center)

      Stack({ alignContent: Alignment.TopStart }) {
        Row()
          .width(64)
          .height(58)
          .backgroundColor(Tokens.yellowSoft)
          .borderRadius(18)
          .borderWidth(1)
          .borderColor('#B3FFD45E')
          .translate({ y: this.tab * 67 })
          .animation({ duration: 180, curve: Curve.EaseOut })

        Column({ space: 9 }) {
          ForEach(this.navLabels, (label: string, index: number) => {
            this.NavItem(index, this.navGlyphs[index], label)
          })
        }
        .width(64)
      }
      .width(64)
      .height(259)
      .margin({ top: 42 })

      Blank()
      Text('v1.0')
        .fontSize(7)
        .fontColor(Tokens.mutedSoft)
        .margin({ bottom: 20 })
    }
    .width(92)
    .height('100%')
    .backgroundColor(Tokens.bg)
  }

  @Builder NavItem(index: number, glyph: string, label: string) {
    Column() {
      Text(glyph)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tab === index ? '#6C4B00' : Tokens.muted)
      Text(label)
        .fontSize(9)
        .fontColor(this.tab === index ? '#6C4B00' : Tokens.mutedSoft)
        .margin({ top: 3 })
    }
    .width(64)
    .height(58)
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
        Button('记一条')
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
    .backgroundColor(Tokens.bg)
  }

  @Builder TodayPane() {
    Column() {
      Row() {
        Text('今日复习')
          .fontSize(this.isWide ? 48 : 34)
          .fontWeight(FontWeight.Bold)
          .fontColor(Tokens.ink)
          .letterSpacing(-1)
        Row() {
          Circle({ width: 5, height: 5 })
            .fill(Tokens.orange)
          Text(this.dueItems().length + ' 条')
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
              .translate({ x: (1 - this.calendarProgress) * (30 + index * 8) })
              .opacity(Math.min(1, this.calendarProgress))
            }, (item: StudyItem) => item.id)
          }
          if (this.todayCreatedItems().length > 0) {
            this.TodayLogged()
          }
        }
        .width('100%')
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
      Text('今天还没有要复习的')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Tokens.inkSoft)
      Text('记下今天学的内容，到点提醒你。')
        .fontSize(11)
        .fontColor(Tokens.muted)
        .margin({ top: 8 })
      Button('记一条')
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
        Text('今天已记')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(Tokens.inkSoft)
        Text(this.todayCreatedItems().length + ' 条')
          .fontSize(9)
          .fontColor(Tokens.mutedSoft)
          .margin({ left: 7 })
        Blank()
        Text('查看全部')
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
            Text(this.findSubject(item.subjectId).name + '  ·  下次 ' + formatShort(item.nextReviewAt))
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
        .translate({ x: (1 - this.calendarProgress) * (30 + index * 8) })
        .opacity(Math.min(1, this.calendarProgress))
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
          Text(item.scheduleMode === 'fixed' ? '固定间隔' : '遗忘曲线')
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
          .fontSize(10.5)
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

      Button('复习')
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
        Text('记一条')
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
          Button('关闭')
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

      Text('科目')
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
            .onClick(() => {
              this.draftSubjectId = subject.id;
            })
        }, (subject: Subject) => subject.id)
      }
      .width('100%')
      .margin({ bottom: 18 })

      Text('章节 / 知识点')
        .fontSize(9)
        .fontColor(Tokens.muted)
        .margin({ bottom: 8 })

      TextInput({ placeholder: '例如：导数的几何意义', text: this.draftTitle })
        .id('titleInput')
        .height(50)
        .fontSize(20)
        .fontColor(Tokens.ink)
        .placeholderColor(Tokens.mutedSoft)
        .caretColor(Tokens.orange)
        .backgroundColor(Tokens.surface)
        .borderWidth(1)
        .borderColor('#B3FFFFFF')
        .borderRadius(14)
        .padding({ left: 14, right: 14 })
        .onChange((value: string) => {
          this.draftTitle = value;
        })

      Text('复习安排')
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
          .animation({ duration: 260, curve: Curve.EaseOut })

        Row() {
          Button('遗忘曲线')
            .layoutWeight(1)
            .height(32)
            .fontSize(11)
            .fontColor(this.draftMode === 'curve' ? Tokens.ink : Tokens.muted)
            .backgroundColor(Color.Transparent)
            .borderRadius(9)
            .onClick(() => {
              this.draftMode = 'curve';
              this.playDots();
            })
          Button('固定间隔')
            .layoutWeight(1)
            .height(32)
            .fontSize(11)
            .fontColor(this.draftMode === 'fixed' ? Tokens.ink : Tokens.muted)
            .backgroundColor(Color.Transparent)
            .borderRadius(9)
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

      if (this.draftMode === 'fixed') {
        Row() {
          Text('每')
            .fontSize(11)
            .fontColor(Tokens.muted)
          Button('-')
            .width(30)
            .height(30)
            .fontSize(16)
            .fontColor(Tokens.inkSoft)
            .backgroundColor(Tokens.surface)
            .borderRadius(15)
            .margin({ left: 10, right: 8 })
            .onClick(() => {
              this.draftFixedDays = Math.max(1, this.draftFixedDays - 1);
            })
          Text(this.draftFixedDays + ' 天')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(Tokens.ink)
          Button('+')
            .width(30)
            .height(30)
            .fontSize(16)
            .fontColor(Tokens.inkSoft)
            .backgroundColor(Tokens.surface)
            .borderRadius(15)
            .margin({ left: 8 })
            .onClick(() => {
              this.draftFixedDays = Math.min(90, this.draftFixedDays + 1);
            })
        }
        .width('100%')
        .margin({ top: 10 })
      } else {
        Row() {
          ForEach(['今天', '1 天', '2 天', '4 天', '7 天', '15 天'], (label: string, index: number) => {
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
            .translate({ y: this.dotVisible > index ? 0 : 6 })
            .scale({ x: this.dotVisible > index ? 1 : 0.6, y: this.dotVisible > index ? 1 : 0.6 })
            .animation({ duration: 180, curve: Curve.EaseOut })
          })
        }
        .width('100%')
        .margin({ top: 12 })
      }

      Row() {
        Column() {
          Text('到点提醒我')
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

      Button('保存')
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

      Text('只保存在本机')
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
        Text('记录')
          .fontSize(this.isWide ? 44 : 32)
          .fontWeight(FontWeight.Bold)
          .fontColor(Tokens.ink)
        Blank()
        Text('长按管理')
          .fontSize(9)
          .fontColor(Tokens.mutedSoft)
          .margin({ right: 10 })
        Text(this.items.length + ' 条')
          .fontSize(11)
          .fontColor(Tokens.muted)
      }
      .width('100%')
      .margin({ top: 24, bottom: 18 })

      if (this.items.length === 0) {
        Text('还没有记录')
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
                  Text('下次')
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
              .translate({ x: (1 - this.calendarProgress) * (40 + index * 8) })
              .opacity(Math.min(1, this.calendarProgress))
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
      Text('日历')
        .fontSize(this.isWide ? 44 : 32)
        .fontWeight(FontWeight.Bold)
        .fontColor(Tokens.ink)
        .margin({ top: 24 })
      Text('接下来 7 天')
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
                  Text('没有安排')
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
            .translate({ x: (1 - this.calendarProgress) * (54 + index * 9) })
            .opacity(Math.min(1, this.calendarProgress))
          }, (day: DayCount) => '' + day.date)
        }
        .width('100%')
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
      Text('设置')
        .fontSize(this.isWide ? 44 : 32)
        .fontWeight(FontWeight.Bold)
        .fontColor(Tokens.ink)
        .margin({ top: 24, bottom: 18 })

      Scroll() {
        Column({ space: 16 }) {
          Column() {
            Row() {
              Column() {
                Text('到点提醒我')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Tokens.ink)
            Text('每天一次，汇总今天的复习')
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
          Text('提醒时间')
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
          Text('提醒方式')
            .fontSize(10)
            .fontColor(Tokens.muted)
          Blank()
          Text(this.reminderMode === 'calendar' ? '系统日历' : (this.reminderMode === 'off' ? '已关闭' : '未安排'))
            .fontSize(10)
            .fontColor(this.reminderMode === 'calendar' ? '#6E8C4D' : Tokens.mutedSoft)
          Text('  ·  ' + (this.reminderCount > 0 ? this.reminderCount : 0) + ' 个日程')
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

        Button('保存设置')
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
      .translate({ x: (1 - this.calendarProgress) * 30 })
      .opacity(Math.min(1, this.calendarProgress))

      Column() {
        Text('科目')
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
          TextInput({ placeholder: '新增科目，如政治', text: this.newSubjectName })
            .layoutWeight(1)
            .height(36)
            .fontSize(12)
            .fontColor(Tokens.ink)
            .placeholderColor(Tokens.mutedSoft)
            .backgroundColor(Tokens.surface)
            .borderRadius(10)
            .padding({ left: 12, right: 12 })
            .onChange((value: string) => {
              this.newSubjectName = value;
            })
          Button('添加')
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

        Text('颜色按顺序自动分配，可继续添加。')
          .fontSize(8)
          .fontColor(Tokens.mutedSoft)
          .margin({ top: 8 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(18)
      .backgroundColor(Tokens.surfaceSoft)
      .borderRadius(22)
      .borderWidth(1)
      .borderColor('#B3FFFFFF')
      .translate({ x: (1 - this.calendarProgress) * 42 })
      .opacity(Math.min(1, this.calendarProgress))

      Text('所有数据只保存在本机，不上传，也不需要账号。')
        .fontSize(9)
        .fontColor(Tokens.mutedSoft)
        .margin({ top: 18 })
        }
        .width('100%')
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
    Column() {
      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('25%')
          .height(50)
          .backgroundColor(Tokens.yellowSoft)
          .borderRadius(16)
          .translate({ x: (this.tab * 100) + '%' })
          .animation({ duration: 180, curve: Curve.EaseOut })

        Row() {
          ForEach(this.navLabels, (label: string, index: number) => {
            Column() {
              Text(this.navGlyphs[index])
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.tab === index ? '#6C4B00' : Tokens.mutedSoft)
              Text(label)
                .fontSize(8)
                .fontColor(this.tab === index ? '#6C4B00' : Tokens.mutedSoft)
                .margin({ top: 3 })
            }
            .layoutWeight(1)
            .height(50)
            .justifyContent(FlexAlign.Center)
            .margin({ left: 3, right: 3 })
            .onClick(() => {
              this.switchTab(index);
            })
          })
        }
        .width('100%')
        .height(50)
      }
      .width('100%')
      .height(58)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .backgroundColor(Tokens.surface)
      .borderRadius(29)
      .borderWidth(1)
      .borderColor('#CCFFFFFF')
      .shadow({ radius: 24, color: '#18000000', offsetX: 0, offsetY: 8 })
    }
    .width('100%')
    .padding({ left: 14, right: 14, bottom: 8 })
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
          .backgroundColor(Tokens.bg)
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
        Text('第 ' + (this.reviewItem.reviewCount + 1) + ' 次')
          .fontSize(9)
          .fontColor(Tokens.mutedSoft)
          .margin({ left: 8 })
        Blank()
        Text((this.reviewItem.reviewCount + 1) + ' / 06')
          .fontSize(9)
          .fontColor(Tokens.mutedSoft)
        Button('关闭')
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
      Text('上次复习 ' + formatShort(this.reviewItem.lastReviewedAt > 0 ? this.reviewItem.lastReviewedAt : this.reviewItem.createdAt))
        .width('100%')
        .fontSize(10.5)
        .fontColor(Tokens.muted)
        .margin({ top: 8 })

      Row()
        .width('100%')
        .height(1)
        .backgroundColor(Tokens.line)
        .margin({ top: 22, bottom: 18 })

      Text('这次记得怎么样？')
        .width('100%')
        .fontSize(11)
        .fontColor(Tokens.muted)
      Text('选择后自动安排下次')
        .width('100%')
        .fontSize(8)
        .fontColor(Tokens.mutedSoft)
        .margin({ top: 4, bottom: 12 })

      Row({ space: 8 }) {
        this.RateButton('忘了', this.intervalHint('forgot'), 'forgot', '#D95F3F')
        this.RateButton('模糊', this.intervalHint('fuzzy'), 'fuzzy', '#B17A12')
        this.RateButton('记得', this.intervalHint('got'), 'got', '#8F5600')
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
      Text('记忆曲线')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(Tokens.ink)
        .letterSpacing(-0.6)
      Text('第 ' + (this.reviewItem.reviewCount + 1) + ' 次复习 · 间隔 ' + this.reviewItem.currentIntervalDays + ' 天')
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
          Text('上次 ' + this.lastRating(this.reviewItem.id))
            .fontSize(9)
            .fontColor(Tokens.muted)
            .margin({ left: 6 })
        }
        Blank()
        Text(this.lastInterval(this.reviewItem.id) + ' 天  →  ' + this.reviewItem.currentIntervalDays + ' 天')
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
          Text(this.actionMode === 'view' ? '记录' : '修改记录')
            .fontSize(11)
            .fontColor(Tokens.muted)
          Blank()
          Button('关闭')
            .height(28)
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

        Text(this.findSubject(this.actionItem.subjectId).name + '  ·  下次 ' + formatShort(this.actionItem.nextReviewAt))
          .fontSize(10)
          .fontColor(Tokens.muted)
          .width('100%')
          .margin({ top: 7 })

        Row()
          .width('100%')
          .height(1)
          .backgroundColor(Tokens.line)
          .margin({ top: 18, bottom: 16 })

        if (this.actionMode === 'view') {
          Row({ space: 10 }) {
            Button('修改')
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
            Button('删除')
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
          Text('标题')
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

          Text('科目')
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
                .onClick(() => {
                  this.editSubjectId = subject.id;
                })
            }, (subject: Subject) => subject.id)
          }
          .width('100%')
          .margin({ top: 5 })

          Row({ space: 10 }) {
            Button('取消')
              .layoutWeight(1)
              .height(42)
              .fontSize(12)
              .fontColor(Tokens.inkSoft)
              .backgroundColor(Tokens.surfaceSoft)
              .borderRadius(12)
              .onClick(() => {
                this.actionMode = 'view';
              })
            Button('保存')
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
      .width(this.isWide ? 480 : '90%')
      .padding(22)
      .backgroundColor(Tokens.surface)
      .borderRadius(26)
      .borderWidth(1)
      .borderColor('#CCFFFFFF')
      .shadow({ radius: 40, color: '#24000000', offsetX: 0, offsetY: 20 })
      .scale({ x: this.actionScale, y: this.actionScale })
    }
    .width('100%')
    .height('100%')
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
