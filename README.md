# 结绳 · HarmonyOS 7 复习提醒

一个只做三件事的本地复习提醒 App：

1. 记下今天学了什么。
2. 按遗忘曲线或固定间隔，到点用系统提醒叫你。
3. 复习后选「忘了 / 模糊 / 记得」，自动排下一次。

没有账号、没有云同步、没有题库、没有 AI 生成内容。所有数据只保存在本机。

## 当前状态

- 设计预览：design/home.html、design/review.html
- 设计文档：docs/superpowers/specs/2026-10-20-jiesheng-review-reminder-design.md
- ArkTS 工程：app/
- 当前阻塞：本机没有 HarmonyOS SDK / Command Line Tools。DevEco CLI 已安装到 .tools/，但创建/构建工程需要 SDK。

## 需要一次手动下载

HarmonyOS SDK 的官方下载页需要登录华为账号。请任选一种：

### 方案 A：Command Line Tools（推荐，体积更小）

1. 打开 https://developer.huawei.com/consumer/cn/download/
2. 登录华为账号。
3. 下载 Windows 版 Command Line Tools 26.0.0。
4. 解压到例如 D:\harmony\command-line-tools。
5. 把路径告诉开发者，或设置：

~~~powershell
$env:DEVECO_CLI_CLT_PATH = "D:\harmony\command-line-tools"
~~~

### 方案 B：DevEco Studio 26.0.0

1. 打开 https://developer.huawei.com/consumer/cn/download/
2. 登录后下载 DevEco Studio 26.0.0（Windows，约 3.1 GB）。
3. 安装到默认路径，或设置：

~~~powershell
$env:DEVECO_CLI_STUDIO_PATH = "C:\Program Files\Huawei\DevEco Studio"
~~~

## 构建

在项目根目录执行：

~~~powershell
$env:DEVECO_CLI_CLT_PATH = "D:\harmony\command-line-tools"
$cli = ".\.tools\node_modules\@deveco\deveco-cli\cli.js"
Set-Location .\app
node $cli build --build-mode debug
~~~

如果需要签名：

~~~powershell
node $cli signature generate
~~~

签名可能需要登录华为账号：

~~~powershell
node $cli auth login
~~~

## 安装到平板

1. 平板打开开发者模式和 USB 调试。
2. 连接电脑，确认设备：

~~~powershell
node $cli device list
~~~

3. 安装构建产物（路径以实际 build 输出为准）：

~~~powershell
hdc install .\entry\build\default\outputs\default\entry-default-signed.hap
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
    services/ReminderService.ets  代理提醒 + 通知授权
    theme/Tokens.ets              颜色与视觉 token
~~~

## 提醒说明

- 使用 HarmonyOS Reminder Agent 设置每天固定时间提醒。
- 需要 ohos.permission.PUBLISH_AGENT_REMINDER。
- 如果系统/账号管控导致代理提醒不可用，App 会提示“系统提醒未开启”，不会假装成功。
- 后续可在设置中增加“用系统日历提醒”的可选降级方案。

## 首版范围

- 今日复习队列
- 快速记录（科目 + 章节/知识点）
- 遗忘曲线 / 固定间隔
- 忘了 / 模糊 / 记得
- 记录列表
- 接下来 7 天
- 每日提醒时间
- 本地清空数据

## 后续

- 桌面小组件
- 数据导出 / 备份
- 深色模式
- 单科提醒时间覆盖
- 系统日历降级
