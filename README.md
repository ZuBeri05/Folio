# Folio · HarmonyOS 7 复习提醒

一个只做三件事的本地复习提醒 App：

1. 记下今天学了什么。
2. 默认用 FSRS-6 记忆算法排期，也可以切到固定间隔；到点用系统提醒叫你。
3. 复习后按「忘记 / 困难 / 良好 / 简单」评分，自动排下一次。

没有账号、没有云同步、没有题库、没有 AI 生成内容。所有数据只保存在本机。

## 当前状态

- 已编译、已签名、已安装到 HUAWEI MatePad 11.5 S。
- App 包名：com.jiesheng.review
- 安装包：dist/jiesheng-debug.hap
- 桌面副本：C:\Users\33065\Desktop\Folio-debug.hap
- 设计预览：design/home.html、design/review.html
- 设计文档：docs/superpowers/specs/2026-10-20-jiesheng-review-reminder-design.md
- 真机截图：design/jiesheng-launch2.png、design/jiesheng-composer-final.png
- 真机已验证：保存后首页「今天已记」立即可见；长按记录打开「修改 / 删除」面板；切页已提速；系统日历可写入。
- 记录保存在本机；具体条数以首页「今天已记」为准。不再有「清空所有记录」入口，删除只能长按单条记录。

首次打开如果出现「日历」权限弹窗，请选择允许。提醒会写入系统日历里的独立账户「结绳复习」，不会混进你的个人日程。

## 提醒方案

代理提醒（Reminder Agent）在当前设备上被系统管控，普通应用配额为 0，发布时返回：

> The number of reminders exceeds the limit.

因此首版使用 **Calendar Kit** 作为可靠提醒通道：

- 在系统日历中创建独立账户「结绳复习」。
- 写入一条每天 20:00 的重复日程，名称为「结绳 · 复习提醒」。
- 日程提前 0 分钟提醒，到点由系统日历弹出通知。
- 日程重复 60 天；App 每次启动、增删记录、修改设置时都会重写。
- 关闭提醒或删除全部记录时，会删除这条日历日程。
- 需要 ohos.permission.READ_CALENDAR / ohos.permission.WRITE_CALENDAR。

设置页会显示：

- 提醒方式：系统日历 / 已关闭 / 未安排
- 已安排 N 个日程
- 若写入失败，显示具体原因

## 动画

动效统一由 `app/entry/src/main/ets/theme/Tokens.ets` 里的 `Motion` 类驱动，页面里不再出现手填的时长和曲线。

### Token

| 类别 | 名称 | 值 | 用途 |
|---|---|---|---|
| 时长 | `instant` | 110ms | 按下、勾选这类微反馈 |
| 时长 | `quick` | 170ms | 图标、小控件状态切换 |
| 时长 | `base` | 260ms | 卡片、面板 |
| 时长 | `slow` | 380ms | 整块入场 |
| 时长 | `page` | 520ms | 页面切换 |

| 类别 | 名称 | 曲线 | 用途 |
|---|---|---|---|
| 曲线 | `decel()` | cubic-bezier(0.05, 0.7, 0.1, 1) | 入场，快起慢停 |
| 曲线 | `accel()` | cubic-bezier(0.3, 0, 1, 1) | 退场，慢起快走 |
| 曲线 | `standard()` | cubic-bezier(0.2, 0, 0, 1) | 同屏过渡 |
| 弹簧 | `settle()` | interpolatingSpring(0, 1, 180, 26) | 列表、面板落位，几乎不过冲 |
| 弹簧 | `snap()` | interpolatingSpring(0, 1, 420, 34) | 按钮、小元素，脆快 |
| 弹簧 | `bounce()` | interpolatingSpring(0, 1, 340, 20) | 撞击回弹，阻尼比约 0.54 |
| 弹簧 | `follow()` | responsiveSpringMotion(0.3, 0.85) | 拖拽跟手 |

弹簧是物理曲线，`animateTo` 的 `duration` 对它不生效，调用时一律不传。

### 机型适配

位移幅度不再写死 vp，统一走 `Motion.travel(base, 屏宽)`：

| 屏宽 | 缩放系数 | 列表位移 | 日历滑入 | 页面横移 |
|---|---|---|---|---|
| 360vp（手机） | 0.55 | 16.5vp | 26.4vp | 28.6vp |
| 700vp（折叠展开） | 0.70 | 21vp | 33.6vp | 36.4vp |
| 900vp（平板竖屏） | 0.90 | 27vp | 43.2vp | 46.8vp |
| 1200vp（Pad 横屏） | 1.15 | 34.5vp | 55.2vp | 59.8vp |

时长由 `Motion.time()` 跟随幅度小幅收敛（0.86–1.14 倍），保证手机与平板的节奏一致，不会出现「平板上很稳、手机上像抽搐」。
布局切换同样按尺寸判断，但只看宽度不够：`isWide = 宽度 ≥ 840vp 且 宽度 > 高度 × 1.05`。
只看宽度的话，960×1440 的竖屏平板也会越过 840 这条线，套用横屏那套左右分栏，结果内容全挤在左上角、下面空掉一大半。
手机上的「记一条」是浮层，打开期间直接监听 keyboardHeightChange，把弹层高度限制在键盘上方。
只依赖窗口的 RESIZE 不够：全屏窗口在部分机型上不会随键盘收缩，弹层下半截连同「保存」会落在键盘后面。现在弹层会缩到键盘上方，内容可滚动到「保存」。
日历行里的条目用 `Flex({ wrap: FlexWrap.Wrap })` 排，单个标签再加 `constraintSize({ maxWidth: '100%' })`、标题 `flexShrink(1)`。
用 `Row` 的话不换行，一天排上四五条就横着顶出卡片，后面的直接被屏幕边缘切掉；超长标题也会把标签撑得比卡片还宽。




### 各处动效

四个页面各一套机制，避免同一个回弹动作反复出现：

| 页面 | 机制 | 运动轴 | 曲线 |
|---|---|---|---|
| 今日 | 标题左 / 列表下 / 已记右，三段接力 | x + y | `settle()` |
| 记录 | 时间轴生长，日期在线右侧，卡片被牵出 | +x | `settle()` |
| 日历 | 单行从右撞入，逐行错峰 | +x | `bounce()` |
| 设置 | 与今日同一套模板，5 张卡轮流左 / 下 / 右 | x + y | `settle()` |

记录和日历的总时长是对齐的：记录 8 × 55 + 弹簧落位 ≈ 0.75s，日历 6 × 55 + 回弹落位 ≈ 0.73s，两页切换不会一快一慢。


- 今日三段入场：标题从左侧 `-travel(72)` 进（0ms）、列表从下方 `travel(36) + 行号 × travel(8)` 进（90ms）、今天已记从右侧 `travel(72)` 进（180ms），统一 `settle()` 弹簧。透明度从 0.3 起步、走到 56% 就到 1，元素一动就看得见，不会「先淡完再动」。
- 切页：旧页 `accel()` 300ms 淡出；新页 `decel()` + 横移 `travel(52)`（日历页 `travel(24)`），方向跟随 tab 前进/后退。新页从 0.25 透明度起步，切页途中不会出现整屏空白帧。
- 日历：7 行每 55ms 错峰，每行从 `travel(48)` 处由 `bounce()` 弹簧撞到位，位移和透明度同步进场。列表的 `Scroll` 横向通栏（页面左右内边距改由内容自己留），裁剪边落在屏幕边缘，卡片不会在屏幕中间被竖着切一刀。
- 记录页「时间轴」：左侧 1.5vp 竖线逐段从上往下生长，日期在线的右侧、卡片外面，卡片从左侧 `travel(26)` 处被牵出来；错峰 55ms（第 8 行之后不再累加），`settle()` 弹簧。竖线高度取卡片实测高度 + 10vp 行距，所以线是连续的。
- 设置页：沿用今日页那套模板，5 张分组卡按「左 → 下 → 右」轮流进，每张错峰 80ms，`settle()` 弹簧，横移 `travel(72)`、下移 `travel(44)`，同样从 0.3 透明度起步。
- 复习卡：`settle()` 从 0.90 放大淡入；关闭 `accel()` 260ms 收回。
- 评分：按压 `snap()`；评分后卡片 `accel()` 缩到 0.95 再提交。
- 长按面板：`settle()` 从 0.9 弹出；关闭 `accel()` 260ms。
- 修改模式切换：内容 `accel()` 淡出 110ms → 换内容 → `settle()` 淡入。
- 删除确认：`snap()` 从 0.94 弹出。
- 记一条表单：`settle()` 弹簧入场，位移 `travel(32)`；关闭 `accel()` 260ms，收起时机与动画时长对齐（原先 220ms 会提前截断 280ms 的动画）。
- 复习曲线小点：90ms 间隔逐颗出现，单颗 `snap()`。
- 页面配色、导航图标、滑块等小控件：`decel()` + `quick`/`instant`。

## 功能范围

- 今日复习队列
- 快速记录（自建科目 + 章节/知识点）
- 默认 FSRS-6 动态排期，也可切固定间隔并直接输入天数
- 点击记录查看详情；长按可修改或删除
- 四套页面配色：每套给四个页面不同浅底，设置里以主色块 + 色点选择
- 科目支持删除：每个科目右侧小 ×，自绘二次确认；科目下有记录时会拦截
- 自绘导航图标：今日 / 记录 / 日历 / 设置
- 科目颜色：数学黄、英语蓝、政治红、专业课紫，新科目按色板自动分配
- 点击记录打开详情；长按或详情内可修改标题 / 科目，或删除单条记录
- FSRS-6 / 固定间隔
- 忘记 / 困难 / 良好 / 简单
- 记录列表
- 接下来 7 天
- 每日提醒时间
- 界面语言：中文 / English / 日本語 / 한국어 / Français / Español
- 记忆保持率可在 80%–95% 调整（默认 90%）；先点「调整」解锁滑块，避免误触
- 竖屏底栏为悬浮胶囊，横屏侧栏为放大的食物图标导航
- 单条记录管理（无全量清空）
- 平板横屏左右分栏；竖屏 / 手机单列布局
- 设置页所有改动即时保存，没有保存按钮；记忆保持率需先点「调整」解锁滑块

## 语言

设置 →「语言 / Language」可切换中文、English、日本語、한국어、Français、Español。选择会保存，重新打开仍生效。

## 构建

环境：DevEco Studio 26.0.0.851，HarmonyOS SDK 26.0.0。

~~~powershell
$env:DEVECO_CLI_STUDIO_PATH = "D:\DevEco Studio"
$cli = ".\.tools\node_modules\@deveco\deveco-cli\cli.js"
Set-Location .\app
node $cli build --build-mode debug
~~~

签名：

~~~powershell
node $cli auth login --no-prompt
node $cli signature generate --type debug --team-id 10086000915735486 --force
~~~

安装：

~~~powershell
$env:DEVECO_CLI_STUDIO_PATH = "D:\DevEco Studio"
$hdc = "D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
& $hdc install -r .\dist\jiesheng-debug.hap
~~~

## 工程结构

~~~text
app/
  AppScope/                       应用名、图标、包名
  entry/src/main/ets/
    pages/Index.ets               首页、复习卡、记录、日历、设置
    domain/Models.ets             数据模型
    domain/Scheduling.ets         FSRS-6 / 固定间隔调度
    data/Store.ets                preferences 本地持久化
    services/ReminderService.ets  系统日历提醒 + 权限
    theme/Tokens.ets              颜色与视觉 token
~~~

## 已知说明

- 当前安装包已装在 Pad 上、处于解锁运行状态；屏幕灭了解锁后打开桌面上的「Folio」即可。
- 首次添加记录或首次打开时，系统会请求日历权限；允许后设置页会显示「系统日历 · 1 个日程」。
- 如果拒绝日历权限，App 内仍可记录和查看，但不会有关闭 App 后的系统提醒；设置页会显示原因。
- 当前记录数以首页为准。旧版的「清空所有记录」已移除；点击记录看详情，长按记录管理；科目用右侧 × 删除。
- 弹层（复习卡、长按面板、删除确认）改用不透明底色，底下的页面内容不会再透上来；点弹层本体也不会再误触遮罩把弹窗关掉。
