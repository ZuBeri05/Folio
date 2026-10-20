# 结绳 · 鸿蒙复习提醒 App 设计文档

- 日期：2026-10-20
- 目标设备：HarmonyOS 7 平板（横屏优先），兼容手机竖屏
- 开发套件：DevEco Studio 26.0.0 / HarmonyOS SDK API 26
- 应用包名：com.jiesheng.review
- 文档状态：已按用户确认的范围定稿

## 1. 产品定义

结绳是一个本地优先的复习提醒工具。用户每天记录“今天学了什么”，应用按遗忘曲线或固定间隔安排下一次复习，到点用系统提醒把用户叫回来；用户复习后在卡片上选择“忘了 / 模糊 / 记得”，应用自动安排下一次。

它不承担教学、题库、笔记整理或学习分析。没有答案，没有题目，没有 AI 生成内容。

### 核心目标

1. 10 秒内记下一条今天学过的内容。
2. 到点可靠提醒，不依赖 App 一直开着。
3. 每次复习只需一次判断：忘了 / 模糊 / 记得。
4. 用户随时能看懂“为什么是今天”和“下次是哪天”，但解释必须是图形化的，不写大段文字。

### 非目标

- 不做账号、云同步、社交、排行榜。
- 不做题库、答案、选择题、填空、AI 出题。
- 不做学习时长、专注计时、打卡海报。
- 首版不做深色模式；保留后续扩展空间。
- 首版不做数据导出；后续可加。

## 2. 用户流程

### 2.1 首次打开

- 直接进入“今日复习”空状态，不做过场页。
- 空状态只显示一句“今天还没有要复习的”和“记一条”入口。
- 默认科目：数学、英语、物理、语文；可在设置中增删改。
- 默认提醒时间 20:00，开关默认打开；用户保存第一条记录时请求通知授权。

### 2.2 记录今天学的内容

1. 点“记一条”。
2. 选科目。
3. 填章节 / 知识点标题，例如“导数的几何意义”。
4. 选复习安排：遗忘曲线（默认）或固定间隔（每 N 天）。
5. 确认提醒时间（默认每天 20:00，可单科覆盖）。
6. 点“保存”。

保存后：

- 写入本地数据库。
- 计算首次复习日期：遗忘曲线为明天；固定间隔为 N 天后。
- 如果当天还有空位，在“今日复习”顶部用一次轻量插入动画显示新条目。
- 刷新系统提醒。

### 2.3 今日复习

- 首页只显示今天到期和已逾期的条目。
- 排序：逾期最久的在前；同一天按创建时间。
- 每条显示：科目、标题、“X 天前 · 第 N 次”、记忆进度细线。
- 点条目或右侧“复习”进入复习卡片。
- 复习卡片只显示标题，不显示答案。
- 用户在心里回想，然后选“忘了 / 模糊 / 记得”。
- 选择后：
  - 计算下一次日期。
  - 写入复习记录。
  - 卡片收起，条目从今日队列移除。
  - 显示一条极简的结果反馈：下次日期 + 曲线节点动画。
- 如果用户中途关闭卡片，不写记录，条目保留。

### 2.4 记录与日历

- “记录”页按日期倒序列出所有学习条目，可搜索科目/标题。
- 点条目进入详情：创建日期、复习历史、下次日期；可修改标题/科目/节奏，可删除。
- “日历”页按月显示每天到期数量；点某天查看当天条目。
- 日历只做查看，不写入系统日历。

### 2.5 设置

- 提醒总开关。
- 默认提醒时间（默认 20:00）。
- 单科提醒时间覆盖。
- 通知权限状态；未授权时提供“去开启”。
- 科目管理。
- 清空本地数据（二次确认）。
- 关于页：版本、隐私说明“所有数据只保存在本机”。

## 3. 复习算法

### 3.1 数据结构

每条内容保存：

- scheduleMode: curve | fixed
- curveStage: 0..6
- fixedIntervalDays: 固定间隔天数
- currentIntervalDays: 当前间隔
- nextReviewAt: 下一次复习时间戳
- lastReviewedAt: 上次复习时间戳
- reviewCount: 已复习次数

遗忘曲线节点（天）：[1, 2, 4, 7, 15, 30, 60]

新条目：

- curve：curveStage = 0，nextReviewAt = 明天同一时间。
- fixed：nextReviewAt = 今天 + N 天。

### 3.2 评价规则

#### 遗忘曲线

- 记得：curveStage = min(curveStage + 1, 6)；next = 今天 + 节点[curveStage]。
- 模糊：next = 今天 + max(1, round(currentIntervalDays × 0.75))；curveStage 不变。
- 忘了：curveStage = max(0, curveStage - 2)；next = 今天 + 1 天。

#### 固定间隔

- 记得：next = 今天 + N 天。
- 模糊：next = 今天 + max(1, round(N ÷ 2))。
- 忘了：next = 今天 + 1 天。

### 3.3 展示规则

复习卡片右侧显示“记忆曲线”：

- 6 个节点，当前节点用橙色空心圆标出。
- 已完成的节点填充黄色。
- 下方只显示：上次 模糊、4 天 → 3 天。
- 选择评价时，当前节点、下次日期、曲线预览同步变化。
- 不写解释段落，不使用“为什么是今天”这类标题。

### 3.4 边界

- 同一天重复点“复习”不重复生成复习记录；以最后一次评价为准。
- 逾期不会自动跳过节点；逾期越久，首页排序越靠前。
- 修改节奏只影响下一次，不重写历史记录。
- 时区变化后，以本地时间的下一次提醒为准；App 启动时重算并重排系统提醒。

## 4. 提醒方案

> 实现变更（2026-10-21）：本机代理提醒被系统管控，普通应用配额为 0，发布返回 1700002。首版实际使用 Calendar Kit，在独立日历账户「结绳复习」中写入每天 20:00 的重复日程。下文代理提醒内容保留为背景，实际行为以 Calendar Kit 为准。

### 4.1 主方案：代理提醒（Reminder Agent）

- 使用 @kit.BackgroundTasksKit 的 reminderAgentManager。
- 使用 ReminderRequestAlarm 设置每天固定时间重复提醒。
- 全局提醒最多 1 条；单科覆盖最多 4 条，总量远低于 30 条上限。
- 通知内容保持通用：“该复习了，打开看看今天的内容。” 不写会过期的数量，避免通知与实际不一致。
- 点击通知进入 App 的“今日复习”。
- 需要 ohos.permission.PUBLISH_AGENT_REMINDER，并在运行时请求通知授权。
- App 启动、设置变更、条目增删后，重新校准提醒。

### 4.2 权限失败处理

代理提醒在部分设备/账号上可能受管控。处理顺序：

1. 请求通知授权。
2. 发布代理提醒失败时，明确显示“系统提醒未开启”，给出“重试”和“去设置”。
3. 在设置页提供“用系统日历提醒”的可选开关，默认关闭；只有用户主动打开才写入 Calendar Kit。
4. 不静默降级，不假装提醒已生效。

### 4.3 提醒时间

- 默认每天 20:00。
- 设置页可改到任意分钟。
- 单科可覆盖全局时间；未覆盖的科目跟随全局。
- 修改时间后立即取消旧提醒并重发。
- App 被杀死后仍应由系统代理触发。

## 5. 视觉设计

### 5.1 方向

参考“便单”的实际 UI，而不是它的深色宣传图：

- 奶油底色，亮黄 / 橙强调色。
- 半透明圆角卡片，细白边，轻阴影。
- 大字号、粗字重、克制的辅助文字。
- 左侧彩色圆环、底部细进度线。
- 平板横屏左右分栏；手机单列。

### 5.2 色板

- 背景：#F7F2E4
- 卡片：#FFFDF8 / rgba(255,252,244,.58)
- 主文字：#2C251D
- 次文字：#8D7F6C
- 亮黄：#FFC531
- 橙：#FF8A2A
- 珊瑚：#FF6542
- 蓝灰：#7E9FB5
- 粉：#D98F87

### 5.3 字体

- 中文 / UI：HarmonyOS Sans SC（系统字体），回退 Noto Sans SC。
- 数字与日期：等宽数字，优先 HarmonyOS Sans 的 tabular figures。
- 标题：700–800 字重，负字距 -0.03em 到 -0.045em。
- 正文：400–500 字重，字号不低于 12vp；辅助信息不低于 10vp。

### 5.4 布局

平板横屏（≥ 840vp）：

- 左侧 96vp 导航栏。
- 主区左右分栏：左列复习队列，右列“记一条”面板。
- 右栏宽度 400vp，卡片圆角 26vp。
- 首页标题区只保留“今日复习”+ 数量胶囊，不做巨幅装饰标题。

手机竖屏：

- 底部导航。
- 单列复习队列。
- “记一条”使用底部 Sheet，不常驻。
- 复习卡片全屏或 90% 高度 Sheet。

### 5.5 文案原则

- 只写用户要做的动作和必要事实。
- 不用比喻句、不用“解开几个结”这类概念文案。
- 不用“为什么是今天”这类解释型标题。
- 不使用“必填 / 可随时改 / 预计 12 分钟”等碎说明，除非用户会因此卡住。
- 空状态、错误状态直接说明下一步。

## 6. 动效

动效目标：让状态变化清楚，不是堆效果。

- 列表首次进入：卡片 320ms 弹簧升起，逐条延迟 40ms。
- 新条目保存：卡片从右栏位置淡入列表顶部，其余卡片让位。
- 点“复习”：卡片通过 geometryTransition 扩展为复习卡片；背景轻微压暗。
- 选择评价：按钮 0.96 → 1 弹簧回弹；下次日期数字滚动；曲线当前节点移动到下一个位置。
- 完成复习：卡片向下淡出，列表 260ms 重排；不弹全屏庆祝。
- 页面切换：120ms 淡入 + 8vp 位移。
- 尊重系统“减少动态效果”：关闭位移和弹簧，只保留淡入淡出。
- 所有可点击区域不小于 44×44vp。

## 7. 技术架构

### 7.1 技术选型

- 纯 ArkTS + ArkUI 原生，不使用 WebView。
- Stage 模型，单 HAP 模块，API 26。
- 状态管理：V1 稳定写法（@State / @Observed / @ObjectLink），避免首版引入 V2 迁移风险。
- 本地持久化：@kit.ArkData 的 preferences（JSON）。首版数据量小；记录数增长到数千条后再迁移 relationalStore。
- 提醒：@kit.CalendarKit（系统日历）+ @kit.NotificationKit（通知权限查询）。
- 导航：Navigation + NavPathStack。
- 响应式：onAreaChange / 窗口宽度断点 840vp。

### 7.2 目录

~~~text
entry/src/main/ets/
  entryability/EntryAbility.ets
  pages/Index.ets
  pages/TodayPage.ets
  pages/RecordsPage.ets
  pages/CalendarPage.ets
  pages/SettingsPage.ets
  components/AppRail.ets
  components/ReviewCard.ets
  components/QuickAddPanel.ets
  components/MemoryCurve.ets
  components/RatingButtons.ets
  components/EmptyState.ets
  domain/models.ets
  domain/scheduling.ets
  data/Store.ets
  services/ReminderService.ets
  services/NotificationPermission.ets
  theme/Tokens.ets
  utils/date.ets
~~~

### 7.3 数据结构

首版用 preferences 保存等价 JSON；以下 SQL 是后续迁移到 relationalStore 时的目标结构。

~~~sql
CREATE TABLE subjects (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  color TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE items (
  id TEXT PRIMARY KEY,
  subject_id TEXT NOT NULL,
  title TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  schedule_mode TEXT NOT NULL,
  curve_stage INTEGER NOT NULL DEFAULT 0,
  fixed_interval_days INTEGER NOT NULL DEFAULT 3,
  current_interval_days INTEGER NOT NULL DEFAULT 1,
  next_review_at INTEGER NOT NULL,
  last_reviewed_at INTEGER,
  review_count INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active'
);

CREATE TABLE review_logs (
  id TEXT PRIMARY KEY,
  item_id TEXT NOT NULL,
  reviewed_at INTEGER NOT NULL,
  rating TEXT NOT NULL,
  previous_interval_days INTEGER NOT NULL,
  next_interval_days INTEGER NOT NULL,
  next_review_at INTEGER NOT NULL
);

CREATE INDEX idx_items_next_review ON items(next_review_at);
CREATE INDEX idx_logs_item ON review_logs(item_id, reviewed_at DESC);
~~~

### 7.4 关键接口

- Scheduling.next(item, rating, now): ReviewResult
- Scheduling.firstReviewAt(mode, fixedDays, now): number
- Store.load(context): Promise<AppData>
- Store.save(context, data): Promise<void>
- ReminderService.sync(context, settings): Promise<void>
- ReminderService.requestPermission(context): Promise<boolean>

### 7.5 错误与空状态

- 数据库失败：保留当前 UI，显示“保存失败，请重试”，不丢输入。
- 通知权限拒绝：设置页持续显示未开启，不反复弹系统框。
- 代理提醒失败：显示具体原因和“去设置/重试”，不静默。
- 今天没有到期：空状态 + “记一条”。
- 记录为空：说明“还没有记录”。
- 删除条目：二次确认；删除后同步取消相关提醒。

## 8. 测试

### 8.1 算法单测

覆盖：

- 曲线：忘了 / 模糊 / 记得 的 stage、next 日期。
- 固定间隔：三种评价的 next 日期。
- 跨月、跨年、时区变化。
- 同一天重复评价只保留最后一次。
- 逾期多天后仍按当天 + 间隔计算，不补跳节点。

### 8.2 数据测试

- 创建、读取、更新、删除。
- App 重启后数据不丢。
- 数据库升级不丢数据。

### 8.3 设备测试

- 平板横屏 16:10、手机竖屏。
- 通知授权允许/拒绝。
- App 杀死后提醒仍触发。
- 点击通知进入今日队列。
- 修改提醒时间后旧提醒取消。
- 减少动态效果开启时无位移动画。

## 9. 交付与构建

- 使用 DevEco CLI 创建工程、安装依赖、语法检查、构建 HAP。
- 本机已安装 DevEco Studio 26.0.0.851；使用官方 @deveco/deveco-cli 构建。
- HAP 已使用华为开发者调试签名，并安装到 HUAWEI MatePad 11.5 S。
- 代理提醒被系统管控，实际使用 Calendar Kit；首次打开请求日历权限。
- 交付内容：
  - 完整 ArkTS 工程源码。
  - 设计预览图。
  - README：如何用 DevEco 打开、签名、安装。
  - 如果环境允许：可安装的 debug HAP。

## 10. 后续可选

- 桌面小组件：显示今天待复习数量。
- 数据导出 / 备份。
- 深色模式。
- 多设备同步。
- 更细的提醒声音/静音时段。

以上均为后续，不进入首版。
