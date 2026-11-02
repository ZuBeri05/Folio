# 专注计时（番茄钟）设计

日期：2026-11-02
状态：已确认，待实现

## 目标

在 Folio 里加一个和复习绑定的专注计时：开始专注后照常刷今日复习，结束时记下这段时间、复习了几条、记得几条，并把时长沉淀成可以回看的记录。

不做：白噪音、任务清单、跨设备同步、独立计时器 App。

## 数据

```ts
interface FocusSession {
  id: string;
  startedAt: number;      // 开始时间戳
  endedAt: number;        // 结束时间戳
  plannedMinutes: number; // 计划时长
  minutes: number;        // 实际分钟数（四舍五入，最少 1）
  itemCount: number;      // 期间复习条数
  remembered: number;     // 其中评分 >= 良好 的条数
  completed: boolean;     // 是否走完计划时长
}
```

- `AppData.focusSessions: FocusSession[]`
- `AppData.activeFocus: FocusSession | null` —— 正在跑的那一段，用于 App 被关掉后恢复
- `Settings.focusMinutes: number` —— 上次选的时长，默认 25

「复习了几条 / 记得几条」不单独记账，结算时从 `logs` 里数：`reviewedAt ∈ [startedAt, endedAt]`，评分 >= 良好 的记入 `remembered`。避免两套计数对不上。

迁移：`Store.load` 里 `focusSessions` 缺省 `[]`，`focusMinutes` 缺省 25，`activeFocus` 缺省 `null`。

## 界面

**入口**：今日页顶栏右侧、和「记一条」并排一枚圆形番茄按钮，点它直接进整页番茄钟。顶栏四个页面共用，所以哪个页面都能点；计时中这枚按钮的底色会深一点。

**大圆盘（整页）**：一个圆环 + 环心，没有别的干扰，放在桌边抬头就能看。

- 没开始：环心是 `25 分钟` + `专注时长`，底部「开始专注」。时长在**设置页**里选（15 / 20 / 25 / 30 / 45 / 60），页面上不调
- 专注中：番茄 + 大号倒计时 + `第 2 轮 · 专注中`，环下 `已过 06:19 · 共 30 分钟`，底部「暂停 / 结束」
- 休息中：同上，环换成蓝色，字幕 `第 2 轮 · 休息中`
- 右上角 `×` 收起，计时照走；圆环按屏幕短边算，平板封顶 430vp，横屏按高度收；打开期间屏幕常亮

**结束小结**：只在手动「结束」时弹，是整轮循环的合计 —— 大字 `65 分钟`，「复习 6 条 · 记得 4 条」，`3 段 · 20:10 – 21:20`，底部「完成」。

**记录页顶部**：一张「专注」卡片 —— 今天合计 `1 小时 15 分 · 3 段`，下面 7 根柱子（周一到周日，今天高亮），柱下是星期缩写。没有专注数据时整张卡不渲染。

## 计时

一轮循环连着转：专注 → 休息 → 专注 → ……，直到手动结束。

- 专注走完自动进休息（`breakMinutesFor(round)`：前 3 轮 5 分钟，第 4 轮 15 分钟长休息），休息走完自动进下一轮专注，轮次 +1
- 只存结束时间戳 `focusEndAt`，显示每 250ms 刷新一次；回到前台立刻重算，切后台、锁屏都不会走偏
- 暂停记 `remainingMs`，恢复时 `endAt = now + remaining`
- 每段开始都往系统日历写一条一次性事件（结束时刻提醒），换段时替换。专注事件用单独的日历账户 `JieshengFocus`，避免被每日提醒的 `sync()` 顺手清空
- `activeFocus` 每次开始/暂停/结束都落盘（含 `isBreak`、`round`、`cycleStart`）；冷启动时还没到点就接着走，已经过点就结算这一段并结束整轮 —— 不自动续上，免得人不在时凭空多跑一段
- 每段专注照常落一条 `FocusSession`，休息不记

## 到点提醒

到点了要听得见，分两条腿走：

- **前台**：`FocusAlert.ring()` 发一条消息类通知（`SlotType.SOCIAL_COMMUNICATION`，即 LEVEL_HIGH：横幅 + 系统提示音 + 震动），标题「专注结束」/「休息结束」，正文「休息 5 分钟」/「开始第 2 轮」。关掉小结时 `cancel` 掉，不在通知栏留痕。手动点「结束」不响，只有倒计时自己走完才响 —— 到点这一声也是循环换段的信号
- **后台/锁屏**：ArkTS 定时器会被冻结，靠日历那条一次性事件兜底（见上）
- 第一次开始专注时 `addSlot` + 检查通知开关，没开就 `requestEnableNotification` 弹一次系统授权

## 边界

- 不到 1 分钟就结束 → 不记录；整轮一段都没够 1 分钟 → 只提示「太短了」，不弹小结
- 提前结束 → 结束整轮循环，小结是这一轮的累计，不是最后那一段
- 休息中点「结束」→ 结束整轮，休息本身不计入
- 计时中不能重复开始
- 日历权限被拒 → 计时照常，只是后台不提醒
- 通知权限被拒 → 前台不响铃，小结照常弹

## 测试

纯逻辑放 `domain/focus/Focus.ts`（`.ts`，可被 vitest 直接 import）：

- `remainingMs(endAt, now)`
- `formatClock(ms)` → `24:35`
- `summarize(startedAt, endedAt, logs)` → 条数、记得数、分钟
- `todayMinutes(sessions, now)` / `todayCount(sessions, now)`
- `weekBuckets(sessions, now)` → 周一开头的 7 个桶
- `breakMinutesFor(round)` → 5 分钟，每 4 轮 15 分钟
- `cycleSummary(sessions, since)` → 一轮循环的段数、分钟、条数、记得数

UI 在模拟器手动验证：开始 → 暂停 → 继续 → 结束 → 记录页出柱子。
