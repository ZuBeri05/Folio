# Folio Switch · 结绳（Switch 移植）

鸿蒙版 Folio（`../` HarmonyOS 7）的 Nintendo Switch 自制程序移植。
界面、配色、文案、动效曲线都照抄原版 `pages/Index.ets` 与 `theme/Tokens.ets`。

Switch 是固定 1280×720 的横屏设备，所以直接用原版的**平板分栏布局**：
左侧 124vp 图标导航栏，右侧"今日复习 + 记一条"双栏，与平板横屏一致。

## 安装

1. 把 `folio.nro` 放到 SD 卡的 `switch/folio/` 目录（或任意 `switch/` 子目录）。
2. 在 HBL / 自制系统里启动 Folio。
3. 数据保存在 `sdmc:/switch/folio/data.json`，格式与原版 JSON 逐字段相同。

操作：触摸屏直接点（与原版一致），`+` 退出。

启动故障排查：新版会把启动阶段和 libnx 返回码写入 SD 卡的
`switch/folio/startup.log`，包括显示初始化、字体读取和首帧绘制。
初始化失败会尝试显示错误提示，并释放已经创建的显示资源。
如果仍然黑屏或崩溃，请提供此日志，以及 Atmosphère 错误画面的错误码、
系统版本和启动方式（相册 HBL / 按 R 启动游戏进入 HBL / forwarder）。
CI 同时保存 `folio-debug-symbols`，用于按崩溃地址定位代码。

## 和原版的对应关系

| 鸿蒙版 | Switch 版 |
|---|---|
| `pages/Index.ets` | `source/ui/app_*.cpp`（状态、动效、绘制）|
| `theme/Tokens.ets` 颜色 | `source/ui/theme.cpp` 一字不改 |
| `theme/Tokens.ets` 的 `Motion` | `source/ui/anim.cpp` 五个时长 + 七条曲线 |
| `domain/fsrs/Fsrs.ts` | `source/domain/fsrs.cpp`，权重与公式完全一致 |
| `domain/fsrs/Scheduling.ts` | 同文件，含逾期封顶 1.5× 与最长间隔截断 |
| `domain/focus/Focus.ts` | `source/domain/focus.cpp` |
| `services/I18n.ets` | `source/gen/i18n_tables.h`（脚本机械转换，6 语言 × 161 键）|
| `data/Store.ets` | `source/data/store.cpp`，JSON 字段名相同 |
| 系统日历提醒 | 去掉（自制程序没有日历权限），专注结束改用结算卡片提示 |

## 动效

原版所有动效由 `Motion` 的五档时长与七条曲线驱动，这里保留同一套：

| 名称 | 原版 | Switch 实现 |
|---|---|---|
| `instant`/`quick`/`base`/`slow`/`page` | 110/170/260/380/520ms | 同名常量，值不变 |
| `decel()` | cubic-bezier(0.05, 0.7, 0.1, 1) | 同一求解器（牛顿迭代） |
| `accel()` / `standard()` | 见 README 原版 | 同上 |
| `settle()` | interpolatingSpring(0,1,180,26) | 半隐式积分弹簧 |
| `snap()` | interpolatingSpring(0,1,420,34) | 同上 |
| `bounce()` | interpolatingSpring(0,1,340,20) | 同上 |

ArkUI 的 `animateTo({curve}) { x = v }` 在 C++ 里对应 `Anim` 类：
目标值 + 本次曲线一起存，`cubic()` / `spring()` 各对应一次 `animateTo`，
中途改目标从当前进度继续，弹簧不配时长。入场时序逐条照搬：

| 页面 | 入场 |
|---|---|
| 今日 | 标题左 72、列表下 30、已记右 72，弹簧 settle，错峰 0/90/180ms |
| 记录 | 时间轴竖线 0→1 生长，卡片从 −26 牵出，错峰 `min(i,8)×55ms` |
| 日历 | 每行从 +48 撞入（bounce），行间隔 `min(55, 780/n)` |
| 设置 | 5 张卡 左/下/右/左/下，逐张错 80ms |
| 页面切换 | 离开 200ms（日历）/300ms（其它）accel，进入 decel，位移 24/52 |

## 渲染

没有 GPU 管线，全部走一个小的软件光栅器（`source/core/`）：

- 圆角矩形用有符号距离场求覆盖率，四角圆弧带抗锯齿；
- 阴影是高斯衰减，模糊走可分离盒式模糊；
- 文字用 stb_truetype 按需栅格化字形并缓存，字号按 em 映射（`ScaleForMappingEmToPixels`）；
- 图标是从原版 SVG 压平的折线数据（`source/gen/icons.h`），自带原始颜色，任意尺寸都清晰。
- 今日卡片、已记列表和记录页的长标题持续向左循环滚动；短标题保持静止。

字体是 Noto Sans SC（OFL），只保留 GB2312 汉字、拉丁、假名、韩文与常用标点，两份合计约 4.9 MB。

因为 Switch 面板固定 1280×720，而原版平板布局按 ~1200vp 排版，这里把界面画在
**1024vp** 宽的逻辑画布上（1vp = 1.25px）：既让正文从 11px 提升到 14px 左右，
也留出 576vp 高度让"记一条"面板完整显示。

## 构建

本机不需要装任何东西，CI 用 devkitPro 官方镜像：

```yaml
container: devkitpro/devkita64:latest
run: make -j"$(nproc)"
```

产物 `folio.nro` 在仓库 Actions 的 `folio-nro` artifact 里。

本地若要自己编（需要 devkitPro + libnx）：

```bash
export DEVKITPRO=/opt/devkitpro
make -j$(nproc)
```

### 桌面预览

`tools/preview.cpp` 用同一套绘制代码离屏出图，方便在没有机器时核对布局：

```bash
g++ -std=gnu++17 -O1 -Isource -I. -D__SWITCH__ -DFOLIO_HOST=1 \
    -o preview tools/preview.cpp source/core/*.cpp source/domain/*.cpp \
    source/data/*.cpp source/services/*.cpp source/ui/*.cpp
FOLIO_SEED=1 FOLIO_DATA_DIR=/tmp/folio ./preview 1280 720 out.png 0 150
```

## 许可

[MIT](../LICENSE)；字体为 SIL Open Font License 1.1（`res/fonts/OFL.txt`）。
