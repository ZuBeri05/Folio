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
- 真机已验证：保存后首页「今天已记」立即可见；切页淡出/滑入；系统日历里 1 个日程。
- 当前保留了你的 4 条记录（返回房间、292、1、1），没有清空。

首次打开如果出现「日历」权限弹窗，请选择允许。提醒会写入系统日历里的独立账户「结绳复习」，不会混进你的个人日程。

## 提醒方案

代理提醒（Reminder Agent）在当前设备上被系统管控，普通应用配额为 0，发布时返回：

> The number of reminders exceeds the limit.

因此首版使用 **Calendar Kit** 作为可靠提醒通道：

- 在系统日历中创建独立账户「结绳复习」。
- 写入一条每天 20:00 的重复日程，名称为「结绳 · 复习提醒」。
- 日程提前 0 分钟提醒，到点由系统日历弹出通知。
- 日程重复 60 天；App 每次启动、增删记录、修改设置时都会重写。
- 关闭提醒或在设置里清空数据时，会删除这条日历日程。
- 需要 ohos.permission.READ_CALENDAR / ohos.permission.WRITE_CALENDAR。

设置页会显示：

- 提醒方式：系统日历 / 已关闭 / 未安排
- 已安排 N 个日程
- 通知权限是否开启
- 若写入失败，显示具体原因

## 动画

这是首版已经实现的动效，不是设计稿里的静态效果：

- 今日列表 / 今天已记：420ms 淡入 + 16vp 上移。
- 切页：旧页 150ms 淡出并横移，新页 300ms 淡入滑入；底部导航胶囊同步移动。
- 底部导航：悬浮白色胶囊，选中项黄色底 + 1.03 倍缩放。
- 打开复习：卡片 360ms 从 0.94 放大到 1。
- 评分按压：按钮缩放 + 变色，随后卡片缩小收起。
- 复习完成：条目从今日队列移除，列表在 260ms 内重排。
- 复习卡：按下 0.985 缩放，松开回弹。
- 手机 / 平板竖屏「记一条」：居中弹层，背景 6vp 模糊，卡片 360ms 从 0.92 放大 + 淡入；关闭 180ms 收回。

## 功能范围

- 今日复习队列
- 快速记录（科目 + 章节/知识点）
- 遗忘曲线 / 固定间隔
- 忘了 / 模糊 / 记得
- 记录列表
- 接下来 7 天
- 每日提醒时间
- 本地清空数据
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
- 当前有 4 条记录，保存在本机；可在设置里「清空所有记录」。
