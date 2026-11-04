package com.jiesheng.folio.ui

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.jiesheng.folio.data.Store
import com.jiesheng.folio.domain.AppData
import com.jiesheng.folio.domain.SUBJECT_COLORS
import com.jiesheng.folio.domain.Settings
import com.jiesheng.folio.domain.StudyItem
import com.jiesheng.folio.domain.FocusSession
import com.jiesheng.folio.domain.ReviewLog
import com.jiesheng.folio.domain.Subject
import com.jiesheng.folio.domain.createDefaultData
import com.jiesheng.folio.domain.emptyItem
import com.jiesheng.folio.domain.fsrs.fsrsStateFromItem
import com.jiesheng.folio.domain.fsrs.postponeToTomorrow
import com.jiesheng.folio.domain.fsrs.previewForGrades
import com.jiesheng.folio.domain.fsrs.scheduleFsrs
import com.jiesheng.folio.domain.addDaysTs
import com.jiesheng.folio.domain.daysBetween
import com.jiesheng.folio.domain.focus.breakMinutesFor
import com.jiesheng.folio.domain.focus.cycleSummary
import com.jiesheng.folio.domain.focus.formatClock
import com.jiesheng.folio.domain.focus.remainingMs
import com.jiesheng.folio.domain.focus.summarize
import com.jiesheng.folio.domain.focus.todayCount
import com.jiesheng.folio.domain.focus.todayMinutes
import com.jiesheng.folio.domain.focus.weekBuckets
import com.jiesheng.folio.domain.hourMinuteLabel
import com.jiesheng.folio.domain.newId
import com.jiesheng.folio.domain.startOfDayTs
import com.jiesheng.folio.services.I18n
import com.jiesheng.folio.services.ReminderService
import com.jiesheng.folio.theme.Motion
import com.jiesheng.folio.theme.Tokens
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * 页面的全部状态与交互逻辑，从鸿蒙版 Index.ets 逐段搬过来。
 *
 * 每个会做动画的数值都包成 [Anim]，写入时带上曲线，和 ArkUI 的
 * `animateTo({ curve }) { ... }` 一一对应；时序（delay、分几段、每段多久）
 * 与原来完全相同。
 */
class FolioState(
    private val context: Context,
    private val scope: CoroutineScope
) {
    private val store = Store(context)

    // ---------------- 数据 ----------------
    var items by mutableStateOf(listOf<StudyItem>())
    var logs by mutableStateOf(listOf<ReviewLog>())
    var subjects by mutableStateOf(listOf<Subject>())
    var settings by mutableStateOf(Settings())
    var focusSessions by mutableStateOf(listOf<FocusSession>())
    var tab by mutableStateOf(0)
    var todayLabel by mutableStateOf("")

    // ---------------- 布局 ----------------
    var isWide by mutableStateOf(false)
    var isTablet by mutableStateOf(false)
    var vpWidth by mutableStateOf(1000f)
    var vpHeight by mutableStateOf(800f)
    var keyboardHeight by mutableStateOf(0f)

    // ---------------- 弹层开关 ----------------
    var showReview by mutableStateOf(false)
    var reviewItem by mutableStateOf(emptyItem())
    var reviewStage by mutableStateOf("entry")
    var showComposer by mutableStateOf(false)
    var draftSubjectId by mutableStateOf("math")
    var draftTitle by mutableStateOf("")
    var draftMode by mutableStateOf("fsrs")
    var draftFixedDays by mutableStateOf(3)
    var newSubjectName by mutableStateOf("")
    var calendarDays by mutableStateOf(14)
    var retentionUnlocked by mutableStateOf(false)
    var titleFocused by mutableStateOf(false)
    var pressedGrade by mutableStateOf(0)
    var pressedItemId by mutableStateOf("")
    var showItemActions by mutableStateOf(false)
    var actionItem by mutableStateOf(emptyItem())
    var actionMode by mutableStateOf("view")
    var editTitle by mutableStateOf("")
    var editSubjectId by mutableStateOf("")
    var showConfirm by mutableStateOf(false)
    var confirmTitle by mutableStateOf("")
    var confirmMessage by mutableStateOf("")
    var confirmKind by mutableStateOf("")
    var confirmSubjectId by mutableStateOf("")
    var confirmItemId by mutableStateOf("")
    var showTimePicker by mutableStateOf(false)
    var pickerHour by mutableStateOf(20)
    var pickerMinute by mutableStateOf(0)
    var notificationEnabled by mutableStateOf(false)
    var reminderCount by mutableStateOf(-1)
    var reminderError by mutableStateOf("")
    var reminderMode by mutableStateOf("")
    var toastText by mutableStateOf<String?>(null)
    private var toastJob: Job? = null

    // ---------------- 今日 ----------------
    var dotVisible by mutableStateOf(6)
    var gradePreviewDays by mutableStateOf(listOf(1, 1, 1, 1))
    var recRowH by mutableStateOf(86f)

    /** 记录页 12 张卡 / 12 段竖线各自的入场进度 */
    val recIn: MutableList<Anim> = MutableList(12) { Anim(1f) }

    /** 今日页：标题（左）、列表（下）、今天已记（右） */
    val todayTitleIn = Anim(1f)
    val todayProgress = Anim(1f)
    val todayLoggedIn = Anim(1f)
    val listOpacity = Anim(1f)
    val listShift = Anim(0f)
    val countPop = Anim(1f)
    val clockPop = Anim(1f)
    val formProgress = Anim(1f)

    /** 设置页 5 张分组卡各自入场进度 */
    val setIn: MutableList<Anim> = MutableList(5) { Anim(1f) }

    /** 页面切换 */
    val pageOpacity = Anim(1f)
    val pageShift = Anim(0f)

    /** 复习浮层 */
    val reviewOpacity = Anim(0f)
    val reviewScale = Anim(1f)

    /** 记一条 */
    var modeFade by mutableStateOf(1f)
    val composerScale = Anim(1f)
    val composerShift = Anim(0f)
    val composerOpacity = Anim(1f)
    val composerDim = Anim(0f)

    /** 记录详情 / 确认框 / 时间选择器 */
    val actionScale = Anim(1f)
    val actionContentOpacity = Anim(1f)
    val actionOverlayOpacity = Anim(1f)
    val confirmScale = Anim(1f)
    val timePickerScale = Anim(1f)

    // ---------------- 专注 ----------------
    var focusRunning by mutableStateOf(false)
    var focusPaused by mutableStateOf(false)
    var focusIsBreak by mutableStateOf(false)
    var focusEndAt by mutableStateOf(0L)
    var focusStartedAt by mutableStateOf(0L)
    var focusRemainingMs by mutableStateOf(0L)
    var focusPlannedMinutes by mutableStateOf(25)
    var focusRound by mutableStateOf(1)
    var focusCycleStart by mutableStateOf(0L)
    var showFocusClock by mutableStateOf(false)
    val clockScale = Anim(1f)
    var showFocusSummary by mutableStateOf(false)
    val summaryScale = Anim(1f)
    var summaryMinutes by mutableStateOf(0)
    var summarySegments by mutableStateOf(0)
    var summaryItems by mutableStateOf(0)
    var summaryRemembered by mutableStateOf(0)
    var summaryStart by mutableStateOf(0L)
    var summaryEnd by mutableStateOf(0L)
    private var focusPausedRemaining by mutableStateOf(0L)
    private var focusTickJob: Job? = null

    // ---------------- 复习提交的竞态保护 ----------------
    private var reviewBusy = false
    private var reviewToken = 0
    private var reviewJob: Job? = null
    private var reviewCloseJob: Job? = null

    // ==================================================================
    // 动效辅助
    // ==================================================================

    /** 位移幅度（dp），随屏宽缩放：手机与平板拿到不同数值 */
    fun mv(base: Float): Float = Motion.travel(base, vpWidth)

    /** 动效时长（ms），随幅度收敛 */
    fun md(base: Int): Int = Motion.time(base, vpWidth)

    private fun settleF(): androidx.compose.animation.core.AnimationSpec<Float> = Motion.settle()
    private fun snapF(): androidx.compose.animation.core.AnimationSpec<Float> = Motion.snap()
    private fun bounceF(): androidx.compose.animation.core.AnimationSpec<Float> = Motion.bounce()
    private fun decelF(ms: Int) = ease(ms, Motion.decel)
    private fun accelF(ms: Int) = ease(ms, Motion.accel)
    private fun standardF(ms: Int) = ease(ms, Motion.standard)
    private fun settleC() = Motion.settle<androidx.compose.ui.graphics.Color>()
    private fun snapC() = Motion.snap<androidx.compose.ui.graphics.Color>()
    private fun decelC(ms: Int) = easeColor(ms, Motion.decel)
    private fun accelC(ms: Int) = easeColor(ms, Motion.accel)

    private fun after(delayMs: Long, block: () -> Unit): Job = scope.launch {
        if (delayMs > 0) delay(delayMs)
        block()
    }

    // ==================================================================
    // 初始化
    // ==================================================================

    fun load() {
        val data = store.load()
        subjects = data.subjects
        items = data.items
        logs = data.logs
        settings = data.settings
        focusSessions = data.focusSessions
        focusPlannedMinutes = data.settings.focusMinutes
        todayLabel = localizedToday()
        restoreFocus(data.activeFocus)
        if (subjects.isNotEmpty()) {
            draftSubjectId = subjects[0].id
        }
        playEntry()
        playToday()
        playForm()
        playDots()
        refreshNotificationState()
        if (settings.reminderEnabled && items.isNotEmpty()) {
            syncReminder()
        }
    }

    fun localizedToday(): String = I18n.localizedToday(settings.language, System.currentTimeMillis())

    fun t(key: String, a: String? = null, b: String? = null): String =
        I18n.t(settings.language, key, a, b)

    // ==================================================================
    // 今日页入场：标题左 / 列表下 / 已记右 的三段接力
    // ==================================================================

    fun playEntry() {
        listOpacity.snapTo(0f)
        listShift.snapTo(mv(30f))
        todayTitleIn.snapTo(0f)
        todayProgress.snapTo(0f)
        todayLoggedIn.snapTo(0f)
        after(40) {
            listOpacity.set(1f, settleF())
            listShift.set(0f, settleF())
            playToday()
        }
    }

    fun playToday() {
        todayTitleIn.snapTo(0f)
        todayProgress.snapTo(0f)
        todayLoggedIn.snapTo(0f)
        todayTitleIn.set(1f, settleF())
        after(90) { todayProgress.set(1f, settleF()) }
        after(180) { todayLoggedIn.set(1f, settleF()) }
    }

    /** 一段结束、下一段接上：中间的数字先轻轻胀一下 */
    fun popClock() {
        clockPop.set(1.05f, snapF())
        after(130) { clockPop.set(1f, settleF()) }
    }

    /** 条数变了：胶囊先胀一下再落回，别让数字硬跳 */
    fun popCount() {
        countPop.set(1.12f, snapF())
        after(120) { countPop.set(1f, settleF()) }
    }

    fun playForm() {
        formProgress.snapTo(0f)
        formProgress.set(1f, Motion.settle())
    }

    fun playDots() {
        dotVisible = 0
        for (i in 0 until 6) {
            after((i * 90).toLong()) { dotVisible = i + 1 }
        }
    }

    /** 记录页：卡片从下方叠上来，逐张落位 */
    fun playRecords() {
        val shown = minOf(items.size, 12)
        for (i in 0 until 12) {
            recIn[i].snapTo(if (i < shown) 0f else 1f)
        }
        for (i in 0 until shown) {
            after((minOf(i, 8) * 55).toLong()) {
                recIn[i].set(1f, snapF())
            }
        }
    }

    /** 设置页：和今日页同一套模板，三方向轮流进 */
    fun playSettings() {
        for (i in 0 until 5) {
            setIn[i].snapTo(0f)
        }
        for (i in 0 until 5) {
            after((i * 80).toLong()) {
                setIn[i].set(1f, settleF())
            }
        }
    }

    /** 日历：单行从右撞入、逐行错峰 */
    val calendarX: MutableList<Anim> = mutableListOf()
    val calendarAlpha: MutableList<Anim> = mutableListOf()

    fun playCalendarRows() {
        val total = calendarDays
        calendarX.clear()
        calendarAlpha.clear()
        for (i in 0 until total) {
            calendarX.add(Anim(mv(48f)))
            calendarAlpha.add(Anim(0f))
        }
        // 每一行都入场，滑到哪儿切换天数看到的都一样；行多时压缩间隔，整体仍收在 0.8s 内
        val step = minOf(55, Math.round(780.0 / total).toInt())
        after(16) {
            for (i in 0 until total) {
                after((i * step).toLong()) {
                    calendarX[i].set(0f, bounceF())
                    calendarAlpha[i].set(1f, bounceF())
                }
            }
        }
    }

    // ==================================================================
    // 页面切换
    // ==================================================================

    fun switchTab(next: Int) {
        if (next == tab) return
        val forward = next > tab
        val isCalendar = next == 2
        val outMs = if (isCalendar) 200 else 300
        val inMs = md(if (isCalendar) Motion.slow else Motion.page)
        val shift = if (isCalendar) mv(24f) else mv(52f)
        pageOpacity.set(0f, accelF(outMs))
        pageShift.set(0f, accelF(outMs))
        after(outMs.toLong()) {
            tab = next
            pageOpacity.snapTo(0.25f)
            pageShift.snapTo(if (forward) shift else -shift)
            pageOpacity.set(1f, decelF(inMs))
            pageShift.set(0f, decelF(inMs))
            when (next) {
                0 -> {
                    playEntry()
                    playForm()
                    playDots()
                }
                1 -> playRecords()
                2 -> playCalendarRows()
                3 -> playSettings()
            }
        }
    }

    // ==================================================================
    // 数据视图
    // ==================================================================

    fun dueItems(): List<StudyItem> {
        val today = startOfDayTs()
        return items
            .filter { it.status == "active" && startOfDayTs(it.nextReviewAt) <= today }
            .sortedBy { it.nextReviewAt }
    }

    fun sortedItems(): List<StudyItem> = items.sortedByDescending { it.createdAt }

    fun todayCreatedItems(): List<StudyItem> {
        val today = startOfDayTs()
        return items
            .filter { startOfDayTs(it.createdAt) == today }
            .sortedByDescending { it.createdAt }
    }

    /** 到期日早于今天且还没做的条目 */
    fun overdueItems(): List<StudyItem> {
        val today = startOfDayTs()
        return items.filter { it.status == "active" && startOfDayTs(it.nextReviewAt) < today }
    }

    /** 逾期天数，当天到期算 0 */
    fun overdueDaysOf(item: StudyItem): Int {
        val due = startOfDayTs(item.nextReviewAt)
        val today = startOfDayTs()
        if (due >= today) return 0
        return maxOf(1, daysBetween(due, System.currentTimeMillis()))
    }

    fun oldestOverdueLabel(): String {
        val list = overdueItems()
        if (list.isEmpty()) return ""
        var oldest = list[0].nextReviewAt
        for (i in 1 until list.size) {
            if (list[i].nextReviewAt < oldest) oldest = list[i].nextReviewAt
        }
        return shortDate(oldest)
    }

    fun upcoming(): List<com.jiesheng.folio.domain.DayCount> {
        val result = mutableListOf<com.jiesheng.folio.domain.DayCount>()
        val base = startOfDayTs()
        for (i in 0 until calendarDays) {
            val day = addDaysTs(base, i)
            var count = 0
            for (item in items) {
                if (item.status != "active") continue
                val at = startOfDayTs(item.nextReviewAt)
                // 第一天算上逾期：今天要复习的条目（含拖过期的）和首页「今日复习」保持一致
                if (if (i == 0) at <= day else at == day) {
                    count += 1
                }
            }
            result.add(com.jiesheng.folio.domain.DayCount(day, count))
        }
        return result
    }

    /** 某一天要复习的条目；today 为真时把逾期未做的也算进来，最久没做的排最前 */
    fun dayItems(day: Long, today: Boolean): List<StudyItem> =
        items.filter {
            it.status == "active" &&
                (if (today) startOfDayTs(it.nextReviewAt) <= day else startOfDayTs(it.nextReviewAt) == day)
        }.sortedBy { it.nextReviewAt }

    fun findSubject(id: String): Subject {
        for (subject in subjects) {
            if (subject.id == id) return subject
        }
        return Subject("", "其他", "#8D7F6C")
    }

    fun subjectInk(color: String): String {
        val raw = if (color.startsWith("#")) color.substring(1) else color
        if (raw.length < 6) return "#FFFFFF"
        val r = raw.substring(0, 2).toInt(16)
        val g = raw.substring(2, 4).toInt(16)
        val b = raw.substring(4, 6).toInt(16)
        return if ((r * 299 + g * 587 + b * 114) / 1000 >= 160) "#3D2A00" else "#FFFFFF"
    }

    private fun previewCacheFor(item: StudyItem) {
        gradePreviewDays = previewForGrades(
            item,
            System.currentTimeMillis(),
            settings.targetRetention,
            settings.maxIntervalDays
        )
    }

    fun gradeColor(grade: Int): String = when (grade) {
        1 -> "#D95F3F"
        2 -> "#B17A12"
        3 -> "#8F5600"
        else -> "#5AA469"
    }

    fun gradeTint(grade: Int, alpha: String): String = "#" + alpha + gradeColor(grade).substring(1)

    fun gradeLabel(grade: Int): String = when (grade) {
        1 -> t("gradeAgain")
        2 -> t("gradeHard")
        3 -> t("gradeGood")
        else -> t("gradeEasy")
    }

    fun gradeMeaning(grade: Int): String = when (grade) {
        1 -> t("gradeAgainHint")
        2 -> t("gradeHardHint")
        3 -> t("gradeGoodHint")
        else -> t("gradeEasyHint")
    }

    fun intervalText(days: Int): String =
        if (days == 1) t("tomorrow") else t("daysAfter", days.toString())

    fun gradeIntervalText(grade: Int): String {
        val index = grade - 1
        val days = if (index >= 0 && index < gradePreviewDays.size) gradePreviewDays[index] else 1
        return intervalText(days)
    }

    fun itemSubtitle(item: StudyItem): String {
        val late = overdueDaysOf(item)
        if (late > 0) {
            return t("times", item.reviewCount.toString()) + "  ·  " + t("overdueDays", late.toString())
        }
        return t("times", item.reviewCount.toString()) + "  ·  " + t("next") + " " + shortDate(item.nextReviewAt)
    }

    fun itemSubtitleColor(item: StudyItem): String =
        if (overdueDaysOf(item) > 0) "#FF6542" else "#8D7F6C"

    fun shortDate(ts: Long): String = I18n.dateShort(settings.language, ts)

    fun longDate(ts: Long): String = I18n.dateLong(settings.language, ts)

    fun weekday(ts: Long): String = I18n.weekday(settings.language, ts)

    fun navLabel(index: Int): String =
        t(listOf("navToday", "navRecords", "navCalendar", "navSettings")[index])

    // ==================================================================
    // 持久化
    // ==================================================================

    fun persist() {
        val data = AppData(
            schemaVersion = 2,
            subjects = subjects.toMutableList(),
            items = items.toMutableList(),
            logs = logs.toMutableList(),
            settings = settings,
            focusSessions = focusSessions.toMutableList(),
            activeFocus = currentFocusRecord()
        )
        try {
            store.save(data)
        } catch (error: Exception) {
            toast(t("toastSaveFail"))
        }
    }

    // ==================================================================
    // 提醒
    // ==================================================================

    fun refreshNotificationState() {
        notificationEnabled = ReminderService.isEnabled(context)
        reminderCount = ReminderService.count(context)
    }

    fun syncReminder() {
        try {
            reminderError = ""
            reminderMode = ReminderService.sync(context, settings, items.isNotEmpty())
            after(600) { refreshNotificationState() }
        } catch (error: Exception) {
            reminderError = error.message ?: t("toastReminderOff")
            toast(t("toastReminderFail"))
            refreshNotificationState()
        }
    }

    fun toast(message: String) {
        toastJob?.cancel()
        toastText = message
        toastJob = after(1800) { toastText = null }
    }

    // ==================================================================
    // 复习
    // ==================================================================

    private fun clearReviewTimers() {
        reviewJob?.cancel()
        reviewJob = null
    }

    private fun discardPendingReview() {
        clearReviewTimers()
        reviewToken += 1
        reviewBusy = false
        pressedGrade = 0
    }

    private fun isReviewCommitActive(itemId: String, token: Int): Boolean =
        showReview && reviewStage == "rating" && reviewItem.id == itemId && reviewToken == token

    fun openReview(item: StudyItem) {
        discardPendingReview()
        reviewCloseJob?.cancel()
        reviewItem = item
        reviewStage = "entry"
        reviewOpacity.snapTo(0f)
        reviewScale.snapTo(0.90f)
        previewCacheFor(item)
        showReview = true
        reviewOpacity.set(1f, settleF())
        reviewScale.set(1f, settleF())
    }

    fun closeReview() {
        if (!showReview) return
        discardPendingReview()
        reviewCloseJob?.cancel()
        reviewOpacity.set(0f, accelF(Motion.base))
        reviewScale.set(0.94f, accelF(Motion.base))
        reviewCloseJob = after(Motion.base.toLong()) {
            showReview = false
            reviewStage = "entry"
            reviewScale.snapTo(1f)
            reviewOpacity.snapTo(0f)
        }
    }

    fun backToEntry() {
        discardPendingReview()
        // 和进入评分页同一套节奏，退回来也别硬切
        reviewScale.snapTo(0.96f)
        reviewScale.set(1f, snapF())
        reviewStage = "entry"
    }

    fun startRating() {
        previewCacheFor(reviewItem)
        reviewScale.snapTo(0.96f)
        reviewScale.set(1f, snapF())
        reviewStage = "rating"
    }

    fun postponeReview() {
        discardPendingReview()
        val next = postponeToTomorrow(reviewItem, System.currentTimeMillis())
        items = items.map { if (it.id == next.id) next else it }
        popCount()
        closeReview()
        persist()
        syncReminder()
        toast(t("postponedTomorrow"))
    }

    fun finishReview(grade: Int) {
        if (reviewBusy || !showReview || reviewStage != "rating") return
        val itemId = reviewItem.id
        val token = reviewToken
        reviewBusy = true
        clearReviewTimers()
        pressedGrade = grade
        reviewJob = after(130) {
            if (!isReviewCommitActive(itemId, token)) return@after
            reviewScale.set(0.95f, accelF(Motion.quick))
            after(170) { commitReview(grade, itemId, token) }
        }
    }

    private fun commitReview(grade: Int, itemId: String, token: Int) {
        if (!isReviewCommitActive(itemId, token)) return
        val item = reviewItem
        val now = System.currentTimeMillis()
        val result = scheduleFsrs(
            item,
            grade,
            now,
            settings.targetRetention,
            settings.maxIntervalDays
        )
        val before = fsrsStateFromItem(item)
        val updated = item.copy(
            curveStage = result.curveStage,
            currentIntervalDays = result.nextIntervalDays,
            nextReviewAt = result.nextAt,
            lastReviewedAt = now,
            reviewCount = item.reviewCount + 1,
            fsrsStability = result.stability,
            fsrsDifficulty = result.difficulty,
            fsrsState = result.state,
            fsrsScheduledDays = result.scheduledDays.toDouble(),
            fsrsLapses = result.lapses,
            fsrsVersion = 6
        )
        items = items.map { if (it.id == updated.id) updated else it }
        popCount()
        val log = ReviewLog(
            id = newId(),
            itemId = item.id,
            reviewedAt = now,
            rating = legacyRating(grade),
            previousIntervalDays = item.currentIntervalDays,
            nextIntervalDays = result.nextIntervalDays,
            nextReviewAt = result.nextAt,
            grade = grade,
            stabilityBefore = before.stability,
            stabilityAfter = result.stability,
            difficultyBefore = before.difficulty,
            difficultyAfter = result.difficulty,
            elapsedDays = reviewElapsedDays(item, now),
            scheduledDays = result.scheduledDays
        )
        logs = listOf(log) + logs
        closeReview()
        persist()
        syncReminder()
        toast(t("nextReviewToast", longDate(result.nextAt)))
    }

    private fun legacyRating(grade: Int): String = when (grade) {
        1 -> "forgot"
        2 -> "fuzzy"
        else -> "got"
    }

    private fun reviewElapsedDays(item: StudyItem, now: Long): Int {
        if (item.lastReviewedAt <= 0) return 0
        return daysBetween(item.lastReviewedAt, now)
    }

    // ==================================================================
    // 记一条
    // ==================================================================

    fun switchMode(next: String) {
        if (draftMode == next) return
        // 先把当前这套淡出，换掉内容再淡入，两套排版永远不会叠在一起
        modeFade = 0f
        after(100) {
            draftMode = next
            modeFade = 1f
            if (next == "fsrs") {
                playDots()
            }
        }
    }

    fun openComposer() {
        showComposer = true
        playForm()
        playDots()
        composerScale.snapTo(0.88f)
        composerShift.snapTo(mv(32f))
        composerOpacity.snapTo(0f)
        composerDim.snapTo(0f)
        composerScale.set(1f, settleF())
        composerShift.set(0f, settleF())
        composerOpacity.set(1f, settleF())
        composerDim.set(1f, settleF())
    }

    fun closeComposer() {
        composerScale.set(0.94f, accelF(Motion.base))
        composerShift.set(mv(16f), accelF(Motion.base))
        composerOpacity.set(0f, accelF(Motion.base))
        composerDim.set(0f, accelF(Motion.base))
        after(Motion.base.toLong()) {
            showComposer = false
            composerScale.snapTo(1f)
            composerShift.snapTo(0f)
            composerOpacity.snapTo(1f)
            composerDim.snapTo(0f)
        }
    }

    fun addItem() {
        val title = draftTitle.trim()
        if (title.isEmpty()) {
            toast(t("toastWriteToday"))
            return
        }
        val now = System.currentTimeMillis()
        val useFixed = draftMode == "fixed"
        val fixedDays = maxOf(1, minOf(90, Math.round(draftFixedDays.toDouble()).toInt()))
        val nextAt = if (useFixed) {
            addDaysTs(startOfDayTs(now), fixedDays)
        } else {
            addDaysTs(startOfDayTs(now), 1)
        }
        val item = StudyItem(
            id = newId(),
            subjectId = draftSubjectId,
            title = title,
            createdAt = now,
            scheduleMode = if (useFixed) "fixed" else "fsrs",
            curveStage = 0,
            fixedIntervalDays = if (useFixed) fixedDays else 3,
            currentIntervalDays = if (useFixed) fixedDays else 1,
            nextReviewAt = nextAt,
            lastReviewedAt = 0,
            reviewCount = 0,
            status = "active",
            fsrsStability = 0.0,
            fsrsDifficulty = 5.0,
            fsrsState = "new",
            fsrsScheduledDays = 0.0,
            fsrsLapses = 0,
            fsrsVersion = 6
        )
        items = listOf(item) + items
        popCount()
        draftTitle = ""
        showComposer = false
        switchTab(0)
        persist()
        syncReminder()
        toast(t("toastSaved", longDate(item.nextReviewAt)))
    }

    /** 曲线预览点：今天 → 5 次「良好」的间隔 */
    fun curveDotLabels(): List<String> {
        val labels = mutableListOf(t("todayNode"))
        var cursor = emptyItem()
        cursor = cursor.copy(scheduleMode = "fsrs")
        var at = System.currentTimeMillis()
        for (i in 0 until 5) {
            val result = scheduleFsrs(cursor, 3, at, settings.targetRetention, settings.maxIntervalDays)
            labels.add(t("days", result.nextIntervalDays.toString()))
            cursor = cursor.copy(
                scheduleMode = "fsrs",
                curveStage = 0,
                fixedIntervalDays = 3,
                currentIntervalDays = result.nextIntervalDays,
                nextReviewAt = result.nextAt,
                lastReviewedAt = at,
                reviewCount = cursor.reviewCount + 1,
                status = "active",
                fsrsStability = result.stability,
                fsrsDifficulty = result.difficulty,
                fsrsState = result.state,
                fsrsScheduledDays = result.scheduledDays.toDouble(),
                fsrsLapses = result.lapses,
                fsrsVersion = 6
            )
            at = result.nextAt
        }
        return labels
    }

    // ==================================================================
    // 设置项
    // ==================================================================

    fun updateReminderEnabled(value: Boolean) {
        settings = settings.copy(reminderEnabled = value)
        persist()
        syncReminder()
    }

    fun openTimePicker() {
        val parts = settings.reminderTime.split(":")
        var hour = 20
        var minute = 0
        if (parts.size == 2) {
            val h = parts[0].toIntOrNull()
            val m = parts[1].toIntOrNull()
            if (h != null && h in 0..23) hour = h
            if (m != null && m in 0..59) minute = m
        }
        pickerHour = hour
        pickerMinute = minute
        showTimePicker = true
        timePickerScale.snapTo(0.94f)
        timePickerScale.set(1f, snapF())
    }

    /** 时间选择器收起：缩回去再撤，和别的浮层一个节奏 */
    fun closeTimePickerAnimated() {
        if (!showTimePicker) return
        timePickerScale.set(0.94f, accelF(Motion.quick))
        after(Motion.quick.toLong()) {
            showTimePicker = false
            timePickerScale.snapTo(1f)
        }
    }

    fun cancelTimePicker() = closeTimePickerAnimated()

    fun confirmTimePicker() {
        applyReminderTime(pickerHour, pickerMinute)
        closeTimePickerAnimated()
    }

    fun applyReminderTime(hour: Int, minute: Int) {
        val h = if (hour < 10) "0$hour" else "$hour"
        val m = if (minute < 10) "0$minute" else "$minute"
        val value = "$h:$m"
        if (value == settings.reminderTime) return
        settings = settings.copy(reminderTime = value)
        persist()
        syncReminder()
    }

    fun updateRetention(value: Int) {
        if (!retentionUnlocked) return
        val retention = minOf(0.95, maxOf(0.80, value / 100.0))
        settings = settings.copy(targetRetention = retention)
    }

    fun updateMaxInterval(days: Int) {
        if (days == settings.maxIntervalDays) return
        settings = settings.copy(maxIntervalDays = days)
        persist()
    }

    fun updateFocusMinutes(minutes: Int) {
        if (minutes == settings.focusMinutes) return
        settings = settings.copy(focusMinutes = minutes)
        persist()
    }

    fun updateTheme(index: Int) {
        settings = settings.copy(themeIndex = index)
        persist()
    }

    fun setLanguage(code: String) {
        settings = settings.copy(language = code)
        todayLabel = localizedToday()
        persist()
    }

    fun addSubject() {
        val name = newSubjectName.trim()
        if (name.isEmpty()) {
            toast(t("toastSubjectEmpty"))
            return
        }
        for (subject in subjects) {
            if (subject.name == name) {
                toast(t("toastSubjectExists"))
                return
            }
        }
        val subject = Subject(newId(), name, nextSubjectColor())
        subjects = subjects + subject
        draftSubjectId = subject.id
        newSubjectName = ""
        persist()
        toast(t("toastSubjectAdded", name))
    }

    private fun nextSubjectColor(): String {
        for (candidate in SUBJECT_COLORS) {
            var used = false
            for (subject in subjects) {
                if (subject.color == candidate) {
                    used = true
                    break
                }
            }
            if (!used) return candidate
        }
        return SUBJECT_COLORS[subjects.size % SUBJECT_COLORS.size]
    }

    fun confirmDeleteSubject(subject: Subject) {
        if (subjects.size <= 1) {
            toast(t("toastAtLeastOne"))
            return
        }
        val used = items.count { it.subjectId == subject.id }
        if (used > 0) {
            toast(t("toastSubjectUsed", used.toString()))
            return
        }
        confirmTitle = t("deleteSubjectTitle")
        confirmMessage = t("deleteSubjectMsg", subject.name)
        confirmKind = "subject"
        confirmSubjectId = subject.id
        confirmItemId = ""
        showConfirm = true
        confirmScale.snapTo(0.94f)
        confirmScale.set(1f, snapF())
    }

    fun askDeleteRecord(item: StudyItem) {
        confirmTitle = t("deleteRecordTitle")
        confirmMessage = t("deleteRecordMsg", item.title)
        confirmKind = "record"
        confirmItemId = item.id
        confirmSubjectId = ""
        showItemActions = false
        showConfirm = true
        confirmScale.snapTo(0.94f)
        confirmScale.set(1f, snapF())
    }

    /** 确认框收起：缩回去再撤 */
    fun closeConfirmAnimated() {
        if (!showConfirm) return
        confirmScale.set(0.94f, accelF(Motion.quick))
        after(Motion.quick.toLong()) {
            showConfirm = false
            confirmScale.snapTo(1f)
        }
    }

    fun cancelConfirm() = closeConfirmAnimated()

    fun executeConfirm() {
        val kind = confirmKind
        val subjectId = confirmSubjectId
        val itemId = confirmItemId
        closeConfirmAnimated()
        if (kind == "subject") {
            subjects = subjects.filter { it.id != subjectId }
            if (draftSubjectId == subjectId && subjects.isNotEmpty()) {
                draftSubjectId = subjects[0].id
            }
            persist()
            toast(t("toastDeleted"))
        } else if (kind == "record") {
            deleteItem(itemId)
        }
    }

    fun deleteFromAction() = askDeleteRecord(actionItem)

    fun deleteItem(id: String) {
        if (reviewItem.id == id) {
            closeReview()
        }
        items = items.filter { it.id != id }
        logs = logs.filter { it.itemId != id }
        persist()
        syncReminder()
        toast(t("toastDeleted"))
    }

    // ==================================================================
    // 记录详情 / 修改
    // ==================================================================

    fun openItemActions(item: StudyItem) {
        actionItem = item
        editTitle = item.title
        editSubjectId = item.subjectId
        actionMode = "view"
        showItemActions = true
        actionContentOpacity.snapTo(1f)
        actionOverlayOpacity.snapTo(1f)
        actionScale.snapTo(0.9f)
        actionScale.set(1f, settleF())
    }

    fun closeItemActions() {
        if (!showItemActions) return
        actionOverlayOpacity.set(0f, accelF(Motion.base))
        actionScale.set(0.94f, accelF(Motion.base))
        after(Motion.base.toLong()) {
            showItemActions = false
            actionOverlayOpacity.snapTo(1f)
            actionScale.snapTo(1f)
            actionContentOpacity.snapTo(1f)
        }
    }

    fun startEditItem() {
        editTitle = actionItem.title
        editSubjectId = actionItem.subjectId
        changeActionMode("edit")
    }

    fun changeActionMode(mode: String) {
        actionContentOpacity.set(0f, accelF(Motion.instant))
        actionScale.set(0.98f, accelF(Motion.instant))
        after(160) {
            actionMode = mode
            actionContentOpacity.snapTo(0f)
            actionScale.snapTo(0.98f)
            actionContentOpacity.set(1f, settleF())
            actionScale.set(1f, settleF())
        }
    }

    fun saveItemEdit() {
        val title = editTitle.trim()
        if (title.isEmpty()) {
            toast(t("toastTitleEmpty"))
            return
        }
        val updated = actionItem.copy(title = title, subjectId = editSubjectId)
        items = items.map { if (it.id == updated.id) updated else it }
        showItemActions = false
        persist()
        toast(t("toastModified"))
    }

    // ==================================================================
    // 专注计时
    // ==================================================================

    fun openFocusClock() {
        clockScale.snapTo(0.94f)
        showFocusClock = true
        clockScale.set(1f, settleF())
    }

    fun closeFocusClock() {
        if (!showFocusClock) return
        clockScale.set(0.94f, accelF(Motion.base))
        after(Motion.base.toLong()) {
            showFocusClock = false
            clockScale.snapTo(1f)
        }
    }

    /** 从大圆盘点开始：起一轮新的番茄循环 */
    fun startCycle() {
        focusCycleStart = System.currentTimeMillis()
        focusRound = 1
        startSegment(settings.focusMinutes, false)
    }

    fun startSegment(minutes: Int, isBreak: Boolean) {
        val safe = minOf(90, maxOf(1, Math.round(minutes.toDouble()).toInt()))
        val startedAt = System.currentTimeMillis()
        val wasRunning = focusRunning
        // 待机色换专注色、时长换倒计时，都走一段过渡，别硬切
        focusIsBreak = isBreak
        focusPaused = false
        focusRunning = true
        focusPlannedMinutes = safe
        focusRemainingMs = safe * 60000L
        focusStartedAt = startedAt
        focusEndAt = startedAt + safe * 60000L
        focusPausedRemaining = 0
        if (wasRunning) {
            // 专注接休息、休息接专注：数字换掉时给一下反馈
            popClock()
        }
        beginFocusTick()
        persist()
        scheduleFocusAlarm(safe)
        ReminderService.prepare(context)
    }

    private fun beginFocusTick() {
        stopFocusTick()
        focusTickJob = scope.launch {
            while (true) {
                delay(250)
                tickFocus()
                if (!focusRunning) break
            }
        }
    }

    private fun stopFocusTick() {
        focusTickJob?.cancel()
        focusTickJob = null
    }

    fun tickFocus() {
        if (!focusRunning || focusPaused) return
        val left = focusEndAt - System.currentTimeMillis()
        focusRemainingMs = if (left > 0) left else 0
        if (left <= 0) {
            finishSegment(true)
        }
    }

    fun pauseFocus() {
        if (!focusRunning || focusPaused) return
        focusPausedRemaining = maxOf(0, focusEndAt - System.currentTimeMillis())
        focusRemainingMs = focusPausedRemaining
        focusPaused = true
        persist()
        clearFocusAlarm()
    }

    fun resumeFocus() {
        if (!focusRunning || !focusPaused) return
        focusEndAt = System.currentTimeMillis() + focusPausedRemaining
        focusPaused = false
        persist()
        scheduleFocusAlarm(maxOf(1, Math.round(focusPausedRemaining / 60000.0).toInt()))
    }

    fun stopFocusEarly() {
        if (!focusRunning) return
        finishSegment(false)
    }

    /**
     * 收一段：专注走完自动进休息，休息走完自动进下一轮专注，一直转到手动结束。
     * autoContinue 为 false 时只结算、不续上（冷启动发现已经过点了）。
     */
    fun finishSegment(completed: Boolean, endOverride: Long? = null, autoContinue: Boolean = true) {
        if (!focusRunning) return
        val startedAt = focusStartedAt
        val nowMs = System.currentTimeMillis()
        var endedAt = nowMs
        if (endOverride != null) {
            endedAt = endOverride
        } else if (completed && focusEndAt > 0 && focusEndAt <= nowMs) {
            endedAt = focusEndAt
        }
        val wasBreak = focusIsBreak
        val planned = focusPlannedMinutes
        val round = focusRound
        stopFocusTick()
        focusRunning = false
        focusPaused = false
        focusIsBreak = false
        focusRemainingMs = 0
        clearFocusAlarm()

        if (wasBreak) {
            if (completed && autoContinue) {
                ringFocusEnd(true, 0, round + 1)
                focusRound = round + 1
                startSegment(settings.focusMinutes, false)
                return
            }
            endCycle(endedAt)
            return
        }

        val summary = summarize(startedAt, endedAt, logs)
        if (summary.minutes >= 1) {
            val session = FocusSession(
                id = newId(),
                startedAt = startedAt,
                endedAt = endedAt,
                plannedMinutes = planned,
                minutes = summary.minutes,
                itemCount = summary.itemCount,
                remembered = summary.remembered,
                completed = completed
            )
            focusSessions = focusSessions + session
        }
        persist()

        if (completed && autoContinue) {
            val breakMinutes = breakMinutesFor(round)
            ringFocusEnd(false, breakMinutes, round)
            startSegment(breakMinutes, true)
            return
        }
        endCycle(endedAt)
    }

    /** 结束整轮循环，弹一张累计小结 */
    private fun endCycle(endedAt: Long) {
        val cycleStart = focusCycleStart
        val cycle = cycleSummary(focusSessions, cycleStart)
        focusCycleStart = 0
        focusRound = 1
        persist()
        closeFocusClock()
        if (cycle.segments == 0) {
            toast(t("focusTooShort"))
            return
        }
        summaryMinutes = cycle.minutes
        summarySegments = cycle.segments
        summaryItems = cycle.itemCount
        summaryRemembered = cycle.remembered
        summaryStart = cycleStart
        summaryEnd = endedAt
        showSummary()
    }

    private fun showSummary() {
        summaryScale.snapTo(0.94f)
        showFocusSummary = true
        summaryScale.set(1f, snapF())
    }

    fun closeSummary() {
        if (!showFocusSummary) return
        summaryScale.set(0.94f, accelF(Motion.base))
        after(Motion.base.toLong()) {
            showFocusSummary = false
            summaryScale.snapTo(1f)
        }
    }

    private fun ringFocusEnd(wasBreak: Boolean, minutes: Int, round: Int) {
        val title = if (wasBreak) t("focusBreakOver") else t("focusSummary")
        val text = if (wasBreak) {
            t("focusNotifyNext", round.toString())
        } else {
            t("focusNotifyRest", minutes.toString())
        }
        ReminderService.ring(context, title, text)
    }

    /** 冷启动时把没跑完的那一段接回来 */
    fun restoreFocus(active: FocusSession?) {
        if (active == null) return
        focusStartedAt = active.startedAt
        focusPlannedMinutes = active.plannedMinutes
        focusEndAt = active.endedAt
        focusIsBreak = active.isBreak == true
        focusRound = if ((active.round ?: 0) > 0) active.round!! else 1
        focusCycleStart = active.cycleStart ?: active.startedAt
        focusPaused = false
        focusRunning = true
        if (active.endedAt > System.currentTimeMillis()) {
            focusRemainingMs = active.endedAt - System.currentTimeMillis()
            beginFocusTick()
            return
        }
        // 关掉 App 期间已经过点了：结算这一段，但不再自动续上
        finishSegment(true, active.endedAt, false)
    }

    private fun currentFocusRecord(): FocusSession? {
        if (!focusRunning) return null
        return FocusSession(
            id = "active",
            startedAt = focusStartedAt,
            endedAt = if (focusPaused) System.currentTimeMillis() + focusPausedRemaining else focusEndAt,
            plannedMinutes = focusPlannedMinutes,
            minutes = 0,
            itemCount = 0,
            remembered = 0,
            completed = false,
            isBreak = focusIsBreak,
            round = focusRound,
            cycleStart = focusCycleStart
        )
    }

    private fun scheduleFocusAlarm(minutes: Int) {
        ReminderService.scheduleFocusEnd(context, focusEndAt, minutes)
    }

    private fun clearFocusAlarm() {
        ReminderService.clearFocusEnd(context)
    }

    /** 环上还剩多少（0–100）：整圈开始，随时间往回缩 */
    fun focusRemainingPercent(): Float {
        val total = focusPlannedMinutes * 60000f
        if (total <= 0f) return 100f
        val left = maxOf(0f, minOf(total, focusRemainingMs.toFloat()))
        return left / total * 100f
    }

    /** 这一轮多少分钟就画多少个刻度 */
    fun tickCount(): Int {
        val minutes = if (focusRunning) focusPlannedMinutes else settings.focusMinutes
        return maxOf(1, minOf(90, Math.round(minutes.toDouble()).toInt()))
    }

    /** 已经走完的分钟数 */
    fun elapsedMinutes(): Int {
        if (!focusRunning) return 0
        val total = focusPlannedMinutes * 60000L
        val passed = ((total - maxOf(0L, focusRemainingMs)) / 60000L).toInt()
        return maxOf(0, minOf(tickCount(), passed))
    }

    fun tickOpacity(index: Int): Float = if (index < elapsedMinutes()) 0.14f else 0.55f

    fun focusClock(): String = formatClock(focusRemainingMs)

    /** 大圆盘：放在桌边抬头就能看见，所以尺寸按短边走，平板上封顶 */
    fun clockSize(): Float {
        val w = if (vpWidth > 0) vpWidth else 360f
        val h = if (vpHeight > 0) vpHeight else 720f
        val short = minOf(w, h)
        // 上下还要留给关闭按钮、已过时间和操作按钮，横屏手机高度不够时按高度收
        val room = h - 170f
        return maxOf(150f, minOf(430f, minOf(short * 0.66f, room)))
    }

    fun elapsedClock(): String {
        val total = focusPlannedMinutes * 60000L
        return formatClock(maxOf(0L, total - focusRemainingMs))
    }

    /** 专注珊瑚、休息蓝、暂停灰；还没开始时浅一点，整圈就是整段时长 */
    fun clockAccent(): String {
        if (!focusRunning) return "#FFC4B2"
        if (focusPaused) return "#B2A48F"
        return if (focusIsBreak) "#7E9FB5" else "#FF6542"
    }

    /** 第 2 轮 · 专注中 */
    fun roundLabel(): String {
        val phase = if (focusIsBreak) t("focusBreaking") else t("focusRunning")
        return t("focusRound", focusRound.toString()) + " · " + phase
    }

    /** 25 分钟 / 1 小时 15 分 */
    fun minutesLabel(minutes: Int): String {
        val parts = com.jiesheng.folio.domain.focus.durationParts(minutes)
        if (parts[0] <= 0) return t("minutesShort", parts[1].toString())
        if (parts[1] == 0) return t("hoursShort", parts[0].toString())
        return t("hoursShort", parts[0].toString()) + " " + t("minutesShort", parts[1].toString())
    }

    fun todayFocusMinutes(): Int = todayMinutes(focusSessions, System.currentTimeMillis())

    fun todayFocusCount(): Int = todayCount(focusSessions, System.currentTimeMillis())

    fun weekFocus(): IntArray = weekBuckets(focusSessions, System.currentTimeMillis())

    fun weekFocusMax(): Int {
        val buckets = weekFocus()
        var max = 0
        for (b in buckets) if (b > max) max = b
        return maxOf(30, max)
    }

    fun weekBarHeight(minutes: Int): Float {
        if (minutes <= 0) return 3f
        return maxOf(6f, Math.round(minutes.toFloat() / weekFocusMax() * 38f).toFloat())
    }

    /** 本周第 index 天（0 = 周一）的日期戳 */
    fun weekDayTs(index: Int): Long {
        val now = System.currentTimeMillis()
        val weekday = com.jiesheng.folio.domain.mondayIndex(now)
        return startOfDayTs(now) + (index - weekday) * 86400000L
    }

    fun todayWeekIndex(): Int = com.jiesheng.folio.domain.mondayIndex(System.currentTimeMillis())

    fun clockLabel(ts: Long): String = hourMinuteLabel(ts)

    // ==================================================================
    // 配色
    // ==================================================================

    fun pageColors(index: Int): List<String> {
        val palettes = listOf(
            listOf("#F7F2E4", "#F7F2E4", "#F7F2E4", "#F7F2E4"),
            listOf("#F7F2E4", "#F1F5F8", "#F2F5EE", "#F5F1F7"),
            listOf("#FBF3E9", "#F8F2EA", "#F4F4EA", "#F7F0F2"),
            listOf("#F4F5EC", "#EFF5F1", "#F1F6ED", "#F4F2EC")
        )
        val safe = if (index in palettes.indices) index else 0
        return palettes[safe]
    }

    fun themeAccent(index: Int): String {
        val accents = listOf("#E8A21A", "#6E9BC5", "#D9826B", "#7FA88B")
        val safe = if (index in accents.indices) index else 0
        return accents[safe]
    }

    fun themeButton(): String =
        if (settings.themeIndex == 0) "#FFC531" else themeAccent(settings.themeIndex)

    fun themeInk(): String = subjectInk(themeButton())

    fun pageBg(): String {
        val colors = pageColors(settings.themeIndex)
        val index = if (tab in colors.indices) tab else 0
        return colors[index]
    }

    fun inkColor(color: String) = Tokens.ink
}
