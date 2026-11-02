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

**今日页标题下**：一条细胶囊，和「0 条」pill 同高。

- 空闲：`▶ 专注 25 分钟`，点开时长浮层
- 计时中：整条变成进度条 —— 左边剩余 `24:35`，中间一条细进度线，右边「暂停 / 结束」

**时长浮层**：复用时间选择器的样式（暗背景 + 居中卡片 + 滑轮），滑轮 15–90 分钟、步进 5，标题「专注时长」，按钮「取消 / 开始」。

**结束小结**：卡片，大字 `25 分钟`，两行说明「复习 6 条 · 记得 4 条」「20:10 – 20:35」，底部按钮「休息 5 分钟」/「完成」。休息是另一段 5 分钟计时，结束弹「休息结束」，带「再来一轮」/「完成」，不进专注记录。

**记录页顶部**：一张「专注」卡片 —— 今天合计 `1 小时 15 分 · 3 段`，下面 7 根柱子（周一到周日，今天高亮），柱下是星期缩写。没有专注数据时整张卡不渲染。

## 计时

- 只存结束时间戳 `focusEndAt`，显示每 250ms 刷新一次；回到前台立刻重算，切后台、锁屏都不会走偏
- 暂停记 `remainingMs`，恢复时 `endAt = now + remaining`
- 开始时往系统日历写一条一次性事件（结束时刻提醒「专注结束」），提前结束就删掉。专注事件用单独的日历账户 `JieshengFocus`，避免被每日提醒的 `sync()` 顺手清空
- `activeFocus` 每次开始/暂停/结束都落盘；冷启动时若 `endAt` 已过就结算并弹小结，没过就接着倒计时

## 边界

- 不到 1 分钟就结束 → 不记录
- 提前结束 → `completed: false`，≥ 1 分钟照记，小结标「提前结束」
- 计时中不能重复开始
- 日历权限被拒 → 计时照常，只是后台不提醒

## 测试

纯逻辑放 `domain/focus/Focus.ts`（`.ts`，可被 vitest 直接 import）：

- `remainingMs(endAt, now)`
- `formatClock(ms)` → `24:35`
- `summarize(startedAt, endedAt, logs)` → 条数、记得数、分钟
- `todayMinutes(sessions, now)` / `todayCount(sessions, now)`
- `weekBuckets(sessions, now)` → 周一开头的 7 个桶

UI 在模拟器手动验证：开始 → 暂停 → 继续 → 结束 → 记录页出柱子。
