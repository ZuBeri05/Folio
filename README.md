# 结绳 · HarmonyOS 7 复习提醒

一个只做三件事的本地复习提醒 App：

1. 记下今天学了什么。
2. 按遗忘曲线或固定间隔，到点用系统提醒叫你。
3. 复习后选「忘了 / 模糊 / 记得」，自动排下一次。

没有账号、没有云同步、没有题库、没有 AI 生成内容。所有数据只保存在本机。

## 当前状态

- 已编译、已签名、已安装到 HUAWEI MatePad 11.5 S。
- App 包名：com.jiesheng.review
- 安装包：dist/jiesheng-debug.hap
- 桌面副本：C:\Users\33065\Desktop\结绳-debug.hap
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

这是首版已经实现的动效，不是设计稿里的静态效果：

- 今日列表 / 今天已记：480ms 淡入 + 24vp 上移。
- 切页：旧页原地 130ms 淡出；新页 240ms 淡入，整页轻微横移。
- 内容入场：今日、记录、设置使用 300ms 纵向进入，停住后 140ms 回弹、140ms 落位。
- 日历：7 张卡片每 70ms 出现一张，从右 64vp 滑到 0，撞到内容边界后回弹 10vp，再落回 0；单张 300 / 100 / 120ms。
- 底部导航：和页面同色的全宽底栏，没有滑块和胶囊；选中项只改变图标/文字颜色，180ms 过渡。
- 复习曲线：今天 / 1 / 2 / 4 / 7 / 15 天的小点按 90ms 间隔逐颗出现。
- 「记一条」表单：整块 360ms 淡入 + 18vp 上移；科目选中 1.04 倍缩放；标题聚焦时边框变黄并轻微放大。
- 遗忘曲线 / 固定间隔：白色滑块 220ms 横移；容器 280ms 在 40 / 52vp 之间伸长压缩。
- 页面配色：每个主题显示一个主色块 + 四个页面浅色点；选中项 1.02 倍放大。
- 固定间隔天数：可直接输入 1–90 天，也可用 +/- 调整。
- 点击记录：放大为详情卡，显示创建日期、已复习次数、当前间隔；长按同样进入管理。
- 修改模式：卡片先 160ms 缩小淡出，切到编辑表单后再 320ms 放大淡入。
- 页面配色：四套低饱和方案，每套四个页面有不同浅底；选中色板 1.03 倍放大。
- 打开复习：卡片 360ms 从 0.94 放大到 1。
- 评分按压：按钮缩放 + 变色，随后卡片缩小收起。
- 复习完成：条目从今日队列移除，列表在 260ms 内重排。
- 复习卡：按下 0.985 缩放，松开回弹。
- 手机 / 平板竖屏「记一条」：居中弹层，背景 6vp 模糊，卡片 360ms 从 0.92 放大 + 淡入；关闭 180ms 收回。
- 长按记录：弹出「修改 / 删除」面板；修改可改标题和科目，删除会同时清掉复习日志。
- 删除确认：自绘白色圆角确认卡（标题、说明、黄色主按钮、取消），不再用系统 AlertDialog。
- 导航图标：自绘 home / list / calendar / settings 线性图标，选中态为棕色，未选中为灰棕。

## 功能范围

- 今日复习队列
- 快速记录（自建科目 + 章节/知识点）
- 固定间隔可直接输入天数
- 点击记录查看详情；长按可修改或删除
- 四套页面配色：每套给四个页面不同浅底，设置里以主色块 + 色点选择
- 科目支持删除：每个科目右侧小 ×，自绘二次确认；科目下有记录时会拦截
- 自绘导航图标：今日 / 记录 / 日历 / 设置
- 科目颜色：数学黄、英语蓝、政治红、专业课紫，新科目按色板自动分配
- 点击记录打开详情；长按或详情内可修改标题 / 科目，或删除单条记录
- 遗忘曲线 / 固定间隔
- 忘了 / 模糊 / 记得
- 记录列表
- 接下来 7 天
- 每日提醒时间
- 单条记录管理（无全量清空）
- 平板横屏左右分栏；竖屏 / 手机单列布局

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
    domain/Scheduling.ets         遗忘曲线 / 固定间隔算法
    data/Store.ets                preferences 本地持久化
    services/ReminderService.ets  系统日历提醒 + 权限
    theme/Tokens.ets              颜色与视觉 token
~~~

## 已知说明

- 平板最后处于锁屏状态，清理数据后没有再次启动；解锁后打开桌面上的「结绳」即可。
- 首次添加记录或首次打开时，系统会请求日历权限；允许后设置页会显示「系统日历 · 1 个日程」。
- 如果拒绝日历权限，App 内仍可记录和查看，但不会有关闭 App 后的系统提醒；设置页会显示原因。
- 当前记录数以首页为准。旧版的「清空所有记录」已移除；点击记录看详情，长按记录管理；科目用右侧 × 删除。
