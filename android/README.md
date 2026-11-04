# Folio Android · 结绳（安卓移植）

鸿蒙版 Folio（`../`）的 Android 移植，用 **Kotlin + Jetpack Compose** 重写。
目标是把原版的界面、节奏、配色和交互原封不动搬过来，不是"做一个类似的 App"。

## 与原版的对应关系

| 鸿蒙版 | Android 版 | 说明 |
|---|---|---|
| `pages/Index.ets` | `ui/FolioState.kt` + `ui/*Page.kt` | 状态与交互逐段搬过来；页面拆成今日 / 记录 / 日历 / 设置 / 浮层几个文件 |
| `theme/Tokens.ets` | `theme/Tokens.kt` | 颜色、动效刻度一字不改 |
| `domain/fsrs/Fsrs.ts` | `domain/fsrs/Fsrs.kt` | FSRS-6，权重和公式完全一致 |
| `domain/fsrs/Scheduling.ts` | `domain/fsrs/Scheduling.kt` | 含逾期奖励封顶（1.5×）与最长间隔截断 |
| `domain/fsrs/Migration.ts` | `domain/fsrs/Migration.kt` | 旧数据迁移，判断条件一致 |
| `domain/focus/Focus.ts` | `domain/focus/Focus.kt` | 番茄钟纯逻辑 |
| `services/I18n.ets` | `services/I18nTables.kt` + `I18n.kt` | 6 种语言 × 161 个键，由脚本从原文件机械转换 |
| `data/Store.ets` | `data/Store.kt` + `Codec.kt` | 同名 preferences（`jiesheng_app` / `app_data_v1`），JSON 结构完全相同 |
| `services/ReminderService.ets` | `services/ReminderService.kt` | 见下方「提醒」一节 |
| `theme/Tokens.ets` 里的 `Motion` | `theme/Tokens.kt` 的 `Motion` + `ui/Anim.kt` | ArkUI `animateTo` 的等价写法 |

数据 JSON 结构和鸿蒙版**逐字段相同**，所以两边数据可以直接互换。

## 动效怎么搬的

原版所有动效都由 `Motion` 里的 5 个时长刻度和 7 条曲线驱动，Android 版保留同一套：

| 名称 | 原版 | Android 实现 |
|---|---|---|
| `instant` / `quick` / `base` / `slow` / `page` | 110 / 170 / 260 / 380 / 520ms | 同名常量，值不变 |
| `decel()` | cubic-bezier(0.05, 0.7, 0.1, 1) | `CubicBezierEasing` 同参数 |
| `accel()` | cubic-bezier(0.3, 0, 1, 1) | 同上 |
| `standard()` | cubic-bezier(0.2, 0, 0, 1) | 同上 |
| `settle()` | interpolatingSpring(0, 1, 180, 26) | `spring(dampingRatio = 1f, stiffness = 180f)` |
| `snap()` | interpolatingSpring(0, 1, 420, 34) | `spring(dampingRatio = 0.86f, stiffness = 420f)` |
| `bounce()` | interpolatingSpring(0, 1, 340, 20) | `spring(dampingRatio = 0.54f, stiffness = 340f)` |
| `follow()` | responsiveSpringMotion(0.3, 0.85) | `spring(dampingRatio = 0.85f, stiffness = 300f)` |

ArkUI 的 `animateTo({ curve }) { x = v }` 在 Compose 里没有直接对应物
（`animateFloatAsState` 一改目标就立刻按新 spec 补间，无法"分阶段"），
所以 `ui/Anim.kt` 里做了个 `Anim` 类：**目标值 + 本次曲线** 一起存，
写 `x.set(v, spec)` 就等于原版的一次 `animateTo`。这样：

- 中途改目标会从当前进度接着走（和 ArkUI 一样，不会跳）；
- 分阶段入场（今日页 40ms 后列表落下、90ms 标题、180ms 已记）靠 `after()` 排程，时序与原版逐毫秒一致；
- 弹簧不配 duration。

位移幅度统一走 `Motion.travel(base, 屏宽)`，手机和平板拿到不同数值，公式与原版相同。

### 四个页面的入场

| 页面 | 原版机制 | 是否照搬 |
|---|---|---|
| 今日 | 标题左 / 列表下 / 已记右，三段接力，各错 40·90·180ms | 是 |
| 记录 | 时间轴竖线 `scaleY` 0→1 生长，卡片从 -26 滑入，逐张错峰 `min(i,8)×55ms` | 是 |
| 日历 | 每行从 +48 撞入（`bounce`），行间隔 `min(55, 780/n)`，切换 7/14/30 天时整体重放 | 是 |
| 设置 | 5 张卡左 / 下 / 右 / 左 / 下，逐张错 80ms | 是 |

页面切换也照搬：离开 200ms（日历）/ 300ms（其它）`accel`，进入 `md(380/520)` 的 `decel`，
位移 24（日历）/ 52（其它），并且进入后立刻触发目标页自己的入场。

## 提醒

鸿蒙版因为 ReminderAgent 配额为 0，改用系统日历写每日重复日程。**Android 上不需要这个绕路**，
回到正统做法：

- `AlarmManager.setInexactRepeating` 每日闹钟 + `DailyReminderReceiver`，到点数一遍今天要复习几条再弹通知；
- 专注结束用 `setExactAndAllowWhileIdle` 一次性闹钟 + `FocusEndReceiver`；
- 开机 / 应用更新后由 `BootReceiver` 重新挂上；
- 设置页仍然显示「提醒方式 · N 个日程」，语义和原版一致（开着 = 1）。

权限只有 `POST_NOTIFICATIONS`（Android 13+）、`SCHEDULE_EXACT_ALARM`、`RECEIVE_BOOT_COMPLETED`。
用户拒绝通知权限只影响系统提醒，记录和复习照常。

## 构建

需要 JDK 17 和 Android SDK 35：

```bash
cd android
./gradlew testDebugUnitTest   # 纯逻辑单元测试
./gradlew assembleDebug       # 产物：app/build/outputs/apk/debug/app-debug.apk
```

也可以直接交给 CI：推到 `main` 后 GitHub Actions 会自动跑测试并构建，
APK 出现在 workflow 的 `folio-debug-apk` artifact 里；打 `v*` 标签会额外挂到 Release。

## 测试

`app/src/test` 里是与鸿蒙版 `tests/` 一一对应的断言：

- `FsrsTest` —— 初始权重、四档预览顺序、`[2, 11, 46, 163, 497]` 这条 golden 序列；
- `SchedulingTest` —— 跨天取整、逾期奖励 1.5× 封顶、最长间隔截断、固定间隔模式；
- `FocusTest` —— 倒计时格式（400ms 显示 00:01）、小结统计、周桶、每 4 轮长休息；
- `MigrationTest` —— 旧数据迁移的各个分支与幂等性。

## 目录

```text
android/
  app/src/main/java/com/jiesheng/folio/
    MainActivity.kt
    domain/            Models、Dates、fsrs/、focus/
    data/              Store（SharedPreferences）、Codec（JSON）
    services/          I18n、I18nTables、ReminderService、Receivers
    theme/             Tokens、Motion
    ui/                FolioState（状态与交互）、各页面与浮层、Anim、Common
  app/src/main/res/    图标（由原版 SVG 转的 vector）、配色、文案
  app/src/test/        单元测试
```

## 已知差异

- **半透明卡片的模糊**：原版浮层用 `backdropBlur` 糊掉背后的页面，Compose 没有等价物。
  这里给浮层里的卡片换成同色实底（`Tokens.surfaceSolid`），观感一致，但不会真的模糊背景。
- **通知而不是系统日历**：见上。功能语义相同，实现方式更贴合 Android。
- **系统返回键**：原版全屏窗口没有返回手势处理；Android 上目前按系统默认行为（回到桌面）。

## 许可

与原版一致，[MIT](../LICENSE)。
