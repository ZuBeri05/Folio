# Folio FSRS 调度替换设计

- 日期：2026-10-22
- 状态：待实现（设计已确认）
- 范围：用 FSRS-6 替换现有“遗忘曲线”调度
- 目标版本：1.1.0（当前 1.0.0 正在华为审核，不能修改已提交的包）

## 1. 背景

Folio 当前的复习调度有两套模式：

- 固定间隔：每条记录固定天数
- 经典曲线：所有记录共用 `1, 2, 4, 7, 15, 30, 60` 天，按 `curveStage` 前进/后退

现有数据模型只有 `curveStage`、`currentIntervalDays`、`reviewCount`，评分只有三档：
`forgot / fuzzy / got`。这不能表达 FSRS 需要的 stability、difficulty 和四档评分。

产品决定：**不保留经典曲线，FSRS 成为唯一调度算法**。当前应用尚未正式发布，适合在 1.1.0 一次完成替换。

## 2. 目标

- 每张记录维护独立的 FSRS 记忆状态
- 四档评分：忘记、困难、良好、简单
- 评分按钮显示含义和预计下次间隔
- 到期复习支持“推迟到明天”和“完成复习”两步
- 设置页用目标记忆率滑杆替换曲线天数
- 平滑迁移已有记录，不丢记录和已排日期
- 完全本地运行，不引入网络服务

## 3. 非目标

- 根据用户历史自动训练 FSRS 参数
- 分钟级 learning steps
- 提前复习（第一版只允许到期复习）
- 云同步、账号体系
- 多设备同步

## 4. 架构

```
pages/Index.ets
  └─ 复习入口 / 四档评分 / 设置滑杆
domain/Scheduling.ets
  └─ 应用层适配：日期取整、推迟、日历时间
domain/fsrs/Fsrs.ets
  └─ 纯 FSRS-6：初始状态、评分更新、可回忆度、间隔预览
data/Store.ets
  └─ schemaVersion 迁移、旧数据兼容
```

### Fsrs.ets

纯函数模块，不访问 UI、不访问 preferences、不访问日历。

核心接口：

```ts
export interface FsrsState {
  stability: number;
  difficulty: number;
  state: string;        // new | learning | review | relearning
  lapses: number;
  scheduledDays: number;
  lastReviewedAt: number;
}

export interface FsrsPreview {
  grade: number;        // 1..4
  intervalDays: number;
}

export function initialState(grade: number, now: number): FsrsState;
export function review(
  state: FsrsState,
  grade: number,
  elapsedDays: number,
  retention: number,
  now: number
): FsrsState;
export function preview(
  state: FsrsState,
  elapsedDays: number,
  retention: number
): FsrsPreview[];
export function retrievability(state: FsrsState, elapsedDays: number): number;
```

实现采用 FSRS-6 默认参数，不训练用户参数。移植时使用官方测试向量做对照。

## 5. 数据模型

### StudyItem 新增

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `fsrsStability` | number | 稳定度 S，单位天 |
| `fsrsDifficulty` | number | 难度 D，1–10 |
| `fsrsState` | string | new / learning / review / relearning |
| `fsrsScheduledDays` | number | 上次排期给出的天数 |
| `fsrsLapses` | number | 遗忘次数 |
| `fsrsVersion` | number | 固定为 6 |

现有字段处理：

- `lastReviewedAt`、`nextReviewAt`、`reviewCount` 继续使用
- `scheduleMode` 迁移后统一为 `fsrs`
- `curveStage`、`fixedIntervalDays` 保留在持久化结构中，但不再参与新调度
- `currentIntervalDays` 表示实际排期天数

### ReviewLog 新增

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `grade` | number | 1=忘记，2=困难，3=良好，4=简单 |
| `stabilityBefore` | number | 评分前 S |
| `stabilityAfter` | number | 评分后 S |
| `difficultyBefore` | number | 评分前 D |
| `difficultyAfter` | number | 评分后 D |
| `elapsedDays` | number | 距上次复习实际天数 |
| `scheduledDays` | number | 上次排期天数 |

`grade` 是新日志的权威字段，历史展示优先使用 `grade`；旧 `rating` 保留用于兼容旧数据和旧版本显示，不再参与 FSRS 计算。

### Settings

删除：

```text
curveDays
```

新增：

```text
targetRetention: number  // 0.80–0.95，默认 0.90
```

### AppData

新增：

```text
schemaVersion: 2
```

## 6. FSRS 调度规则

### 评分

| 评分 | grade | 含义 | 状态变化 |
| --- | --- | --- | --- |
| 忘记 | 1 | 完全没想起来 | 进入 relearning，S 下降 |
| 困难 | 2 | 想得很吃力，勉强想起 | S 小幅增加，D 上升 |
| 良好 | 3 | 正常想起 | S 正常增加 |
| 简单 | 4 | 很轻松，几乎秒答 | S 增加最多，D 下降 |

### 按天取整

Folio 是每日提醒，不做分钟级复习。

- FSRS 计算出的间隔小于 1 天：排到明天
- 大于等于 1 天：四舍五入到整天
- 下次时间落在 `startOfDay(now) + intervalDays`
- 所有条目最早只能排到明天，不排今天

### 新卡

- 新记录 `fsrsState = new`
- 第一次评分时由 `initialState` 生成初始 S/D
- 评分后进入 learning 或 review，具体由 FSRS 状态机决定

### 迟到与提前

- 迟到：`elapsedDays` 用实际经过天数，FSRS 自然缩短下次间隔
- 提前：第一版不允许；只有到期条目能进入复习流程

### 推迟到明天

“推迟到明天”只做：

- `nextReviewAt = startOfDay(now) + 1 天`
- 更新日历
- 不修改 S/D
- 不增加 `reviewCount`
- 不写 `ReviewLog`

连续点击也只把日期设为明天，不累加。

### 目标记忆率

滑杆范围 80%–95%，步长 1%，默认 90%。

- 数值越高，FSRS 给出的间隔越短
- 修改后只影响之后的评分排期
- 不回溯修改已经排好的 `nextReviewAt`
- 设置页显示提示：“调整后从下一次复习开始生效，不会改动已安排的日期。”

## 7. 页面与交互

### 7.1 复习入口

到期条目点击“复习”后显示：

```text
数学 · 第 3 次复习
线性代数 特征值
上次复习：10.21

[ 推迟到明天 ]   [ 完成复习 ]
```

- 关闭：关闭弹层，不改变数据
- 推迟到明天：按第 6 节处理，关闭弹层并 Toast “已推迟到明天”
- 完成复习：切换到评分页，不关闭弹层

只有到期条目显示复习入口。未到期条目在记录页只保留查看/编辑。

### 7.2 评分页

标题：`这次记得怎么样？`

四张评分卡：

```text
忘记          困难
完全没想起来   想得很吃力
明天          3 天后

良好          简单
正常想起来     几乎秒答
7 天后        14 天后
```

- 手机：2×2
- 平板：一行四张或 2×2
- 每张卡显示名称、含义、实时预计间隔
- 左上角返回复习入口
- 选择后更新 FSRS、写日志、同步日历、关闭弹层
- Toast：`下次复习：10 月 24 日`

### 7.3 设置页

删除：

- 遗忘曲线天数卡片
- 曲线天数滑杆弹层
- `CurvePanel` 固定节点图

新增“复习目标”卡片：

```text
复习目标

记忆保持率          90%

[ 80% ——●———— 95% ]

目标越高，复习越频繁。调整后从下一次复习开始生效。
```

## 8. 迁移

加载旧数据时执行一次 v1 → v2 迁移。

### 记录

- `reviewCount = 0`：`fsrsState = new`，S=0（new 状态的哨兵值），D=5；第一次评分时忽略哨兵 S/D，改用 FSRS 初始状态
- `reviewCount > 0`：`fsrsState = review`，`S = max(1, currentIntervalDays)`，`D = 5`
- `lapses` 根据旧日志中 `forgot` 数量估算
- 保留原 `nextReviewAt`
- `scheduleMode` 改为 `fsrs`

### 日志

- `forgot → grade 1`
- `fuzzy → grade 2`
- `got → grade 3`
- 旧日志的 S/D 填 0
- `elapsedDays` 用上一条日志或 `previousIntervalDays` 推导
- `scheduledDays` 用 `nextIntervalDays` 推导

### 设置

- `targetRetention = 0.90`
- 忽略旧 `curveDays`
- 保存新结构时自然丢弃旧字段

迁移失败时保留原始 JSON，不覆盖数据；按安全默认值继续运行并记录错误。

## 9. 异常处理

- S 限制在 0.1–36500 天
- D 限制在 1–10
- 非法状态回退到 `review`
- 间隔小于 1 天时排到明天
- 设备时间调早：elapsedDays 按 0 处理
- 重复点评分：`reviewBusy` 防抖
- 连续推迟：只设明天，不写日志
- 目标记忆率越界：夹到 0.80–0.95
- 日历权限被拒：本地排期仍保存，只提示同步失败
- 迁移失败：不覆盖原始数据

## 10. 测试

### 算法单测

- 四档评分分别更新 S/D
- new / learning / review / relearning 状态
- 目标记忆率 80/90/95 的间隔单调性
- 按天取整、最小 1 天
- 官方 FSRS-6 测试向量对照

### 迁移测试

- 未复习旧记录
- 已复习旧记录
- 固定间隔旧记录
- 旧日志映射
- 缺字段/坏字段

### 交互测试

- 到期 → 推迟：日期变、次数不变、日志不增加
- 到期 → 完成 → 四档评分：日期、S/D、日志、日历更新
- 评分页返回、关闭、重复点击
- 设置滑杆保存、重启保持
- 手机 2×2、平板一行四个布局

### 手动验收

- 用现有测试记录走迁移
- 新建记录连续复习 4 次，观察间隔变化
- 修改目标记忆率后确认只影响下一次评分

## 11. 发布

当前 1.0.0 正在华为审核中，不能修改已提交的包。

FSRS 作为下一个版本发布：

- `versionName` 升到 1.1.0
- `versionCode` 递增
- 重新打 release `.app`
- 更新应用市场版本信息、隐私政策权限说明
- 提交新版本审核

## 12. 验收标准

- 原有记录迁移后不丢失，数量、标题、科目、下次日期保持
- 到期条目走完“推迟/完成 → 四档评分”流程
- 四档评分显示实时预计间隔
- 推迟不改 S/D、不增加复习次数、不写日志
- 目标记忆率范围 80–95，默认 90，重启保持
- 设置页不再出现曲线天数
- 手机和平板布局都可用
- 算法、迁移、交互测试全部通过
