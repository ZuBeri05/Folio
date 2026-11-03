# Folio · 结绳

A local-first spaced-repetition reminder for HarmonyOS 7. No account, no cloud, no AI — everything stays on the device.

一个只做三件事的本地复习提醒 App：

1. 记下今天学了什么。
2. 默认用 FSRS-6 记忆算法排期，也可以切到固定间隔；到点用系统提醒叫你。
3. 复习后按「忘记 / 困难 / 良好 / 简单」评分，自动排下一次。

<img src="docs/screenshots/01-home.png" width="260"> <img src="docs/screenshots/02-records.png" width="260"> <img src="docs/screenshots/03-pomodoro.png" width="260">

## 功能

- 今日复习队列、快速记录（自建科目 + 章节 / 知识点）
- 默认 FSRS-6 动态排期，可切固定间隔并直接输入天数
- 记忆保持率 80%–95% 可调（默认 90%），评分前能看到四档对应的下次间隔
- 番茄钟：全屏圆盘、连续循环（专注 25 分钟 / 休息 5 分钟，每 4 轮休息 15 分钟）、按分钟刻度递减、专注结束响一声
- 记录时间轴、接下来 7 / 14 / 30 天日历、四套页面配色
- 单条记录管理：点击看详情，长按改标题 / 科目或删除；没有「清空全部」
- 手机单列 / 平板横屏左右分栏（`isWide = 宽度 ≥ 840vp 且 宽度 > 高度 × 1.05`）
- 界面语言：中文 / English / 日本語 / 한국어 / Français / Español

## 提醒

系统代理提醒（Reminder Agent）在 HarmonyOS 7 上对普通应用配额为 0（`The number of reminders exceeds the limit.`），所以提醒走 **Calendar Kit**：

- 在系统日历里创建独立账户「结绳复习」，写入一条每天 20:00 的重复日程，提前 0 分钟提醒
- 日程重复 60 天，App 每次启动、增删记录、改设置时重写
- 关闭提醒或删除全部记录时删掉这条日程
- 需要 `ohos.permission.READ_CALENDAR` / `ohos.permission.WRITE_CALENDAR`

设置页会显示提醒方式、已安排日程数，写入失败时显示原因。拒绝日历权限也不影响记录和复习，只是关掉 App 后没有系统提醒。

## 构建

环境：DevEco Studio 26.0.0.851、HarmonyOS SDK 26.0.0（`compileSdkVersion` / `compatibleSdkVersion` / `targetSdkVersion` 均为 `26.0.0`）。

~~~powershell
$env:DEVECO_CLI_STUDIO_PATH = "D:\DevEco Studio"
$cli = ".\node_modules\@deveco\deveco-cli\cli.js"   # 或 IDE 自带的 DevEco CLI
Set-Location .\app
node $cli build --build-mode debug
~~~

仓库里 `app/build-profile.json5` 不含任何签名材料。首次构建时用 DevEco Studio 的「Project Structure → Signing Configs → Automatically generate signature」生成一份调试签名，它会写回这个文件；或者手动填 `signingConfigs` 里的 `certpath` / `profile` / `storeFile` 和密码。

产物在 `app/entry/build/default/outputs/default/entry-default-signed.hap`，安装：

~~~powershell
$hdc = "<SDK>\toolchains\hdc.exe"
& $hdc install -r .\app\entry\build\default\outputs\default\entry-default-signed.hap
~~~

## 测试

纯函数层（FSRS-6、调度、迁移、专注计时）有单元测试，不依赖设备：

~~~bash
cd tests
npm install
node node_modules/vitest/vitest.mjs run
~~~

## 工程结构

~~~text
app/
  AppScope/                       应用名、图标、包名
  entry/src/main/ets/
    pages/Index.ets               今日、复习卡、记录、日历、设置、番茄钟
    domain/Models.ets             数据模型
    domain/Scheduling.ets         FSRS-6 / 固定间隔调度
    data/Store.ets                preferences 本地持久化
    services/ReminderService.ets  系统日历提醒 + 权限
    theme/Tokens.ets              颜色、排版、动效 token
tests/                            vitest 单元测试与 golden fixture
docs/                             设计文档、隐私政策、截图
~~~

## 动效

动效统一由 `theme/Tokens.ets` 里的 `Motion` 驱动，页面里不出现手填的时长和曲线。

| 时长 | 值 | 用途 |
|---|---|---|
| `instant` | 110ms | 按下、勾选这类微反馈 |
| `quick` | 170ms | 图标、小控件状态切换 |
| `base` | 260ms | 卡片、面板 |
| `slow` | 380ms | 整块入场 |
| `page` | 520ms | 页面切换 |

| 曲线 | 值 | 用途 |
|---|---|---|
| `decel()` | cubic-bezier(0.05, 0.7, 0.1, 1) | 入场，快起慢停 |
| `accel()` | cubic-bezier(0.3, 0, 1, 1) | 退场，慢起快走 |
| `standard()` | cubic-bezier(0.2, 0, 0, 1) | 同屏过渡 |
| `settle()` | interpolatingSpring(0, 1, 180, 26) | 列表、面板落位，几乎不过冲 |
| `snap()` | interpolatingSpring(0, 1, 420, 34) | 按钮、小元素，脆快 |
| `bounce()` | interpolatingSpring(0, 1, 340, 20) | 撞击回弹，阻尼比约 0.54 |
| `follow()` | responsiveSpringMotion(0.3, 0.85) | 拖拽跟手 |

弹簧是物理曲线，`animateTo` 的 `duration` 对它不生效，调用时一律不传。位移幅度走 `Motion.travel(base, 屏宽)` 按屏宽缩放，时长跟着幅度小幅收敛（0.86–1.14 倍），手机和平板节奏一致。

四个页面各一套入场机制，避免同一个回弹动作反复出现：今日是标题左 / 列表下 / 已记右的三段接力，记录是时间轴逐段生长、卡片被牵出，日历是单行从右撞入、逐行错峰，设置是 5 张卡轮流左 / 下 / 右。记录和日历的总时长对齐（约 0.73–0.75s），切页不会一快一慢。

## 数据

所有数据存在本机 preferences（`app_data_v1`），不上传、不联网。卸载 App 即全部删除。详见 [隐私政策](docs/privacy-policy.md)。

## 许可

[MIT](LICENSE)
