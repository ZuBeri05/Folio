package com.jiesheng.folio.wear

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.pager.VerticalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.border
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jiesheng.folio.R
import com.jiesheng.folio.theme.Motion
import com.jiesheng.folio.theme.Tokens
import com.jiesheng.folio.ui.FolioState
import com.jiesheng.folio.ui.hexColor

/**
 * 手表版根界面。
 *
 * 结构重排成圆屏上的三段式：
 * - 待复习队列做成竖向翻页，一屏一条，标题大、评分靠滑动；
 * - 底部是番茄钟的圆盘入口，点开就是全屏圆盘；
 * - 记录 / 日历 / 设置收进一个「滑到底」的列表页。
 *
 * **动画全部来自共享的 FolioState**：入场接力、条数胶囊弹跳、
 * 页面切换的位移与时长、番茄钟刻度淡出、浮层 scale+opacity，
 * 用的都是手机版那套 Motion 曲线和时序，这里一行都没重写。
 */
@Composable
fun WearApp(state: FolioState) {
    LaunchedEffect(Unit) {
        state.load()
    }

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .background(hexColor(state.pageBg()))
    ) {
        state.vpWidth = maxWidth.value
        state.vpHeight = maxHeight.value
        // 手表永远是单列
        state.isWide = false
        state.isTablet = false

        WearHome(state)

        if (state.showComposer) WearComposer(state)
        if (state.showReview) WearReview(state)
        if (state.showItemActions) WearItemActions(state)
        if (state.showConfirm) WearConfirm(state)
        if (state.showFocusClock) WearFocusClock(state)
        if (state.showFocusSummary) WearSummary(state)
        WearToast(state)
    }
}

/**
 * 「记一条」：手表上没有键盘可用，所以只做两件事 ——
 * 选科目、按下保存。标题可以后面在手机上补，或者用系统语音输入。
 *
 * 入场沿用手机版的 composerScale 0.88→1、composerShift、composerDim 0→1。
 */
@Composable
private fun WearComposer(state: FolioState) {
    val dim = state.composerDim.v("wearComposerDim")
    val scale = state.composerScale.v("wearComposerScale")
    val shift = state.composerShift.v("wearComposerShift")

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(hexColor(state.pageBg()))
            .graphicsLayer { alpha = dim },
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 18.dp)
                .graphicsLayer {
                    scaleX = scale
                    scaleY = scale
                    translationY = shift * density
                },
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = state.t("newEntry"),
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                color = Tokens.ink
            )
            Text(
                text = state.t("subject"),
                fontSize = 8.5.sp,
                color = Tokens.muted,
                modifier = Modifier.padding(top = 8.dp)
            )
            // 科目：一屏只放三个，多了上下滑
            Row(
                modifier = Modifier.padding(top = 5.dp),
                horizontalArrangement = Arrangement.spacedBy(5.dp)
            ) {
                state.subjects.take(3).forEach { subject ->
                    val selected = state.draftSubjectId == subject.id
                    WearPill(
                        text = subject.name,
                        height = 26.dp,
                        fontSize = 9.sp,
                        background = hexColor(if (selected) subject.color else "#D9FFFDF8"),
                        foreground = hexColor(
                            if (selected) state.subjectInk(subject.color) else "#4B4032"
                        ),
                        borderColor = hexColor(if (selected) subject.color else "#1A5E4B30"),
                        borderRadius = 13.dp,
                        paddingHorizontal = 9.dp,
                        onClick = { state.draftSubjectId = subject.id }
                    )
                }
            }
            Text(
                text = state.t("chapter"),
                fontSize = 8.5.sp,
                color = Tokens.muted,
                modifier = Modifier.padding(top = 8.dp)
            )
            // Wear OS 自带键盘和语音输入，用真正的输入框，别让用户打不了字
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 5.dp)
                    .height(30.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(Tokens.surface)
                    .border(1.dp, hexColor("#B3FFFFFF"), RoundedCornerShape(12.dp))
                    .padding(horizontal = 9.dp),
                contentAlignment = Alignment.CenterStart
            ) {
                if (state.draftTitle.isEmpty()) {
                    Text(
                        text = state.t("titlePlaceholder"),
                        fontSize = 9.sp,
                        color = Tokens.mutedSoft,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
                BasicTextField(
                    value = state.draftTitle,
                    onValueChange = { state.draftTitle = it },
                    singleLine = true,
                    textStyle = TextStyle(fontSize = 10.sp, color = Tokens.ink),
                    cursorBrush = SolidColor(Tokens.orange),
                    modifier = Modifier.fillMaxWidth()
                )
            }
            Row(
                modifier = Modifier.padding(top = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(7.dp)
            ) {
                WearPill(
                    text = state.t("cancel"),
                    height = 30.dp,
                    fontSize = 9.5.sp,
                    background = Tokens.surfaceSoft,
                    foreground = Tokens.inkSoft,
                    paddingHorizontal = 11.dp,
                    onClick = { state.closeComposer() }
                )
                WearPill(
                    text = state.t("save"),
                    height = 30.dp,
                    fontSize = 9.5.sp,
                    background = hexColor(state.themeButton()),
                    foreground = hexColor(state.themeInk()),
                    fontWeight = FontWeight.Medium,
                    paddingHorizontal = 11.dp,
                    onClick = { state.addItem() }
                )
            }
        }
    }
}

/** 主页：上方是今日队列，下方是番茄钟入口；左右滑动切换「今日 / 记录 / 设置」 */
@Composable
private fun WearHome(state: FolioState) {
    val pagerState = rememberPagerState(pageCount = { 3 })
    val pageOpacity = state.pageOpacity.v("wearPageOpacity")
    val pageShift = state.pageShift.v("wearPageShift")

    // 翻到哪一页就触发那一页的入场，和手机版 switchTab 的时序一致
    LaunchedEffect(pagerState.currentPage) {
        val target = when (pagerState.currentPage) {
            0 -> 0
            1 -> 1
            else -> 3
        }
        if (state.tab != target) {
            state.switchTab(target)
        }
    }

    VerticalPager(
        state = pagerState,
        modifier = Modifier
            .fillMaxSize()
            .graphicsLayer {
                alpha = pageOpacity
                translationY = pageShift * density
            }
    ) { page ->
        when (page) {
            0 -> WearToday(state)
            1 -> WearRecords(state)
            else -> WearSettings(state)
        }
    }
}

/** 今日：一屏一条待复习，左右滑动翻条目 */
@Composable
private fun WearToday(state: FolioState) {
    val due = state.dueItems()
    val titleIn = state.todayTitleIn.v("wearTitleIn")
    val progress = state.todayProgress.v("wearProgress")

    if (due.isEmpty()) {
        WearEmptyToday(state, titleIn, progress)
        return
    }

    // 当前看的是第几条：左右滑动换条目（手表上左右滑是最自然的手势）
    var cursor by rememberSaveable { mutableStateOf(0) }
    val safeCursor = cursor.coerceIn(0, due.lastIndex)
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 18.dp),
        // 整屏内容作为一个整体垂直居中，圆屏上下弧线都不会压到东西
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // 标题单独一行居中。
        // 条数不再放在这里 —— 下面已经有「1 / 2」这个进度，同一个数字出现两次是多余的。
        Text(
            text = state.t("todayTitle"),
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            color = Tokens.ink,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .graphicsLayer {
                    translationX = (1f - titleIn) * -state.mv(48f) * density
                    alpha = 0.3f + 0.7f * minOf(1f, titleIn * 1.8f)
                }
        )

        Spacer(Modifier.height(8.dp))

        // 一屏一条：内容按自身高度排，不塞进 pager ——
        // pager 的高度是均分的，条目一多行就把下面那段裁掉了。
        val current = due[safeCursor]
        val subject = state.findSubject(current.subjectId)
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .pointerInput(due.size, safeCursor) {
                    // 点按和左右滑动共用一套手势：分开挂两个 detector 会抢事件，
                    // 结果两个都不触发（手机版上的「记一条」闪退是这个坑的另一个变种）。
                    var dragX = 0f
                    detectDragGestures(
                        onDragStart = { dragX = 0f },
                        onDrag = { change, delta ->
                            change.consume()
                            dragX += delta.x
                        },
                        onDragEnd = {
                            if (dragX < -40f && safeCursor < due.lastIndex) cursor = safeCursor + 1
                            if (dragX > 40f && safeCursor > 0) cursor = safeCursor - 1
                        }
                    )
                }
                .pointerInput(current.id) {
                    detectTapGestures(onTap = { state.openReview(current) })
                },
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Top
        ) {
            Box(
                modifier = Modifier
                    .size(9.dp)
                    .clip(CircleShape)
                    .background(hexColor(subject.color))
            )
            Text(
                text = subject.name,
                fontSize = 8.5.sp,
                color = Tokens.muted,
                modifier = Modifier.padding(top = 4.dp)
            )
            Text(
                text = current.title,
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
                color = Tokens.ink,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .padding(top = 5.dp)
                    .graphicsLayer {
                        translationY = (1f - progress) * state.mv(20f) * density
                        alpha = 0.3f + 0.7f * minOf(1f, progress * 1.8f)
                    }
            )
            Text(
                text = state.itemSubtitle(current),
                fontSize = 8.5.sp,
                color = hexColor(state.itemSubtitleColor(current)),
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 4.dp)
            )
            if (due.size > 1) {
                Text(
                    text = "${safeCursor + 1} / ${due.size}",
                    fontSize = 8.sp,
                    color = Tokens.mutedSoft,
                    modifier = Modifier.padding(top = 6.dp)
                )
            }
        }

        WearPill(
            text = state.t("review"),
            height = 34.dp,
            fontSize = 11.sp,
            background = hexColor(state.themeButton()),
            foreground = hexColor(state.themeInk()),
            fontWeight = FontWeight.Medium,
            paddingHorizontal = 22.dp,
            modifier = Modifier.padding(top = 10.dp),
            onClick = { state.openReview(due[safeCursor]) }
        )

        // 番茄钟入口：跑着的时候是倒计时小条，没跑的时候是那枚番茄
        if (state.focusRunning) {
            WearMiniFocus(state)
        } else {
            WearFocusEntry(state)
        }
    }
}

/** 未计时时的番茄钟入口：一枚小番茄，点开就是全屏圆盘 */
@Composable
private fun WearFocusEntry(state: FolioState) {
    androidx.compose.foundation.Image(
        painter = painterResource(R.drawable.tomato),
        contentDescription = null,
        modifier = Modifier
            .padding(top = 8.dp)
            .size(24.dp)
            .pointerInput(Unit) { detectTapGestures(onTap = { state.openFocusClock() }) }
    )
}

@Composable
private fun WearEmptyToday(state: FolioState, titleIn: Float, progress: Float) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 22.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = state.t("todayEmptyTitle"),
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            color = Tokens.inkSoft,
            textAlign = TextAlign.Center,
            modifier = Modifier.graphicsLayer {
                translationX = (1f - titleIn) * 0f * density /* DEBUG */
                alpha = 0.3f + 0.7f * minOf(1f, titleIn * 1.8f)
            }
        )
        Text(
            text = state.t("todayEmptyBody"),
            fontSize = 9.sp,
            color = Tokens.muted,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 6.dp)
        )
        WearPill(
            text = state.t("newEntry"),
            height = 34.dp,
            fontSize = 11.sp,
            background = hexColor(state.themeButton()),
            foreground = hexColor(state.themeInk()),
            paddingHorizontal = 20.dp,
            modifier = Modifier
                .padding(top = 14.dp)
                .graphicsLayer {
                    translationY = (1f - progress) * state.mv(16f) * density
                    alpha = minOf(1f, progress)
                },
            onClick = { state.openComposer() }
        )
    }
}

/** 记录：时间轴改成一条竖列，入场仍然逐条从左侧牵出 */
@Composable
private fun WearRecords(state: FolioState) {
    val items = state.sortedItems()
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalAlignment = Alignment.Start
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = state.t("recordsTitle"),
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                color = Tokens.ink
            )
            Spacer(Modifier.weight(1f))
            Text(
                text = state.t("items", state.items.size.toString()),
                fontSize = 9.sp,
                color = Tokens.muted
            )
        }

        if (state.focusSessions.isNotEmpty()) {
            WearWeekBars(state)
        }

        if (items.isEmpty()) {
            Text(
                text = state.t("noRecords"),
                fontSize = 10.sp,
                color = Tokens.muted,
                modifier = Modifier.padding(top = 24.dp)
            )
            return
        }

        val pager = rememberPagerState(pageCount = { items.size })
        VerticalPager(
            state = pager,
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
        ) { index ->
            val item = items[index]
            val progress = state.recIn[minOf(index, 11)].v("wearRec$index")
            val subject = state.findSubject(item.subjectId)
            Box(modifier = Modifier.padding(vertical = 3.dp)) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .graphicsLayer {
                        translationX = (1f - progress) * -state.mv(22f) * density
                        alpha = progress
                    }
                    .clip(RoundedCornerShape(14.dp))
                    .background(Tokens.surface)
                    .pointerInput(item.id) {
                        detectTapGestures(onTap = { state.openItemActions(item) })
                    }
                    .padding(horizontal = 10.dp, vertical = 9.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(6.dp)
                        .clip(CircleShape)
                        .background(hexColor(subject.color))
                )
                Column(modifier = Modifier
                    .weight(1f)
                    .padding(start = 7.dp)) {
                    Text(text = subject.name, fontSize = 8.sp, color = hexColor(subject.color))
                    Text(
                        text = item.title,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                        color = Tokens.ink,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.padding(top = 2.dp)
                    )
                }
                Text(
                    text = state.shortDate(item.nextReviewAt),
                    fontSize = 8.sp,
                    color = Tokens.muted
                )
            }
            }
        }
    }
}

/** 本周专注柱：柱高仍由 state 的同一个函数算，动画仍是 settle */
@Composable
private fun WearWeekBars(state: FolioState) {
    val buckets = state.weekFocus()
    val todayIndex = state.todayWeekIndex()
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp)
            .height(34.dp),
        verticalAlignment = Alignment.Bottom
    ) {
        for (index in 0..6) {
            val h by animateFloatAsState(
                targetValue = state.weekBarHeight(buckets[index]),
                animationSpec = Motion.settle(),
                label = "wearWeek$index"
            )
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Box(
                    modifier = Modifier
                        .width(6.dp)
                        .height((h * 0.6f).dp)
                        .clip(RoundedCornerShape(3.dp))
                        .background(if (index == todayIndex) Tokens.coral else hexColor("#E8DCC4"))
                )
            }
        }
    }
}

/** 设置：只留手表用得到的三项 */
@Composable
private fun WearSettings(state: FolioState) {
    val pager = rememberPagerState(pageCount = { 3 })
    VerticalPager(
        state = pager,
        modifier = Modifier.fillMaxSize()
    ) { page ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 18.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            when (page) {
                0 -> {
                    Text(
                        text = state.t("focusSettingTitle"),
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Medium,
                        color = Tokens.muted
                    )
                    Row(
                        modifier = Modifier.padding(top = 8.dp),
                        horizontalArrangement = Arrangement.spacedBy(5.dp)
                    ) {
                        listOf(15, 25, 45).forEach { value ->
                            val selected = state.settings.focusMinutes == value
                            WearPill(
                                text = value.toString(),
                                height = 26.dp,
                                fontSize = 10.sp,
                                background = if (selected) Tokens.yellowSoft else Tokens.surface,
                                foreground = hexColor(if (selected) "#6C4B00" else "#8D7F6C"),
                                fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
                                paddingHorizontal = 10.dp,
                                onClick = { state.updateFocusMinutes(value) }
                            )
                        }
                    }
                }
                1 -> {
                    Text(
                        text = state.t("retentionTitle"),
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Medium,
                        color = Tokens.muted
                    )
                    Text(
                        text = Math.round(state.settings.targetRetention * 100).toString() + "%",
                        fontSize = 22.sp,
                        fontWeight = FontWeight.Bold,
                        color = hexColor(state.themeAccent(state.settings.themeIndex))
                    )
                    Row(
                        modifier = Modifier.padding(top = 6.dp),
                        horizontalArrangement = Arrangement.spacedBy(5.dp)
                    ) {
                        listOf(80, 85, 90, 95).forEach { value ->
                            val selected = Math.round(state.settings.targetRetention * 100).toInt() == value
                            WearPill(
                                text = value.toString(),
                                height = 24.dp,
                                fontSize = 9.sp,
                                background = if (selected) Tokens.yellowSoft else Tokens.surface,
                                foreground = hexColor(if (selected) "#6C4B00" else "#8D7F6C"),
                                paddingHorizontal = 8.dp,
                                onClick = {
                                    state.retentionUnlocked = true
                                    state.updateRetention(value)
                                    state.persist()
                                }
                            )
                        }
                    }
                }
                else -> {
                    Text(
                        text = state.t("palette"),
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Medium,
                        color = Tokens.muted
                    )
                    Row(
                        modifier = Modifier.padding(top = 8.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        listOf(0, 1, 2, 3).forEach { index ->
                            val selected = state.settings.themeIndex == index
                            Box(
                                modifier = Modifier
                                    .size(26.dp)
                                    .clip(CircleShape)
                                    .background(hexColor(state.themeAccent(index)))
                                    .then(
                                        if (selected) {
                                            Modifier.padding(3.dp)
                                        } else {
                                            Modifier
                                        }
                                    )
                                    .pointerInput(index) {
                                        detectTapGestures(onTap = { state.updateTheme(index) })
                                    }
                            )
                        }
                    }
                }
            }
        }
    }
}

/** 复习弹层：沿用手机版的 scale 0.90→1 与 opacity 0→1 */
@Composable
private fun WearReview(state: FolioState) {
    val opacity = state.reviewOpacity.v("wearReviewOpacity")
    val scale = state.reviewScale.v("wearReviewScale")
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(hexColor(state.pageBg()))
            .graphicsLayer {
                alpha = opacity
                scaleX = scale
                scaleY = scale
            }
    ) {
        if (state.reviewStage == "rating") WearRating(state) else WearReviewEntry(state)
    }
}

@Composable
private fun WearReviewEntry(state: FolioState) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = state.t("reviewN", (state.reviewItem.reviewCount + 1).toString()),
            fontSize = 8.5.sp,
            color = Tokens.mutedSoft
        )
        Text(
            text = state.reviewItem.title,
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold,
            color = Tokens.ink,
            maxLines = 4,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 6.dp)
        )
        Text(
            text = state.t(
                "lastReview",
                state.shortDate(
                    if (state.reviewItem.lastReviewedAt > 0) state.reviewItem.lastReviewedAt
                    else state.reviewItem.createdAt
                )
            ),
            fontSize = 8.5.sp,
            color = Tokens.muted,
            modifier = Modifier.padding(top = 5.dp)
        )
        Row(
            modifier = Modifier.padding(top = 14.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            WearPill(
                text = state.t("postponeTomorrow"),
                height = 32.dp,
                fontSize = 10.sp,
                background = Tokens.surfaceSoft,
                foreground = Tokens.inkSoft,
                paddingHorizontal = 12.dp,
                onClick = { state.postponeReview() }
            )
            WearPill(
                text = state.t("completeReview"),
                height = 32.dp,
                fontSize = 10.sp,
                background = hexColor(state.themeButton()),
                foreground = hexColor(state.themeInk()),
                fontWeight = FontWeight.Medium,
                paddingHorizontal = 12.dp,
                onClick = { state.startRating() }
            )
        }
        WearMicroAction(state.t("close")) { state.closeReview() }
    }
}

/** 评分：四档做成 2×2，仍是同一套 gradePreviewDays 与四色 */
@Composable
private fun WearRating(state: FolioState) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = state.t("rateTitle"),
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            color = Tokens.ink,
            textAlign = TextAlign.Center
        )
        Column(
            modifier = Modifier.padding(top = 8.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            for (row in 0..1) {
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    for (col in 0..1) {
                        val grade = row * 2 + col + 1
                        WearGrade(state, grade)
                    }
                }
            }
        }
        WearMicroAction(state.t("close")) { state.closeReview() }
    }
}

@Composable
private fun WearGrade(state: FolioState, grade: Int) {
    val pressed = state.pressedGrade == grade
    val scale by animateFloatAsState(
        targetValue = if (pressed) 0.94f else 1f,
        animationSpec = androidx.compose.animation.core.tween(160, easing = Motion.decel),
        label = "wearGrade$grade"
    )
    Column(
        modifier = Modifier
            .width(88.dp)
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .clip(RoundedCornerShape(13.dp))
            .background(hexColor(state.gradeTint(grade, "14")))
            .pointerInput(grade) {
                detectTapGestures(onTap = { state.finishReview(grade) })
            }
            .padding(horizontal = 8.dp, vertical = 7.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = state.gradeLabel(grade),
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
            color = hexColor(state.gradeColor(grade))
        )
        Text(
            text = state.gradeIntervalText(grade),
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            color = Tokens.ink,
            modifier = Modifier.padding(top = 2.dp)
        )
    }
}

/** 详情 / 删除确认：沿用手机版的 scale + opacity 进出 */
@Composable
private fun WearItemActions(state: FolioState) {
    val overlay = state.actionOverlayOpacity.v("wearActionOverlay")
    val scale = state.actionScale.v("wearActionScale")
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(hexColor(state.pageBg()))
            .graphicsLayer { alpha = overlay },
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier
                .padding(horizontal = 18.dp)
                .graphicsLayer {
                    scaleX = scale
                    scaleY = scale
                },
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = state.actionItem.title,
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                color = Tokens.ink,
                maxLines = 3,
                textAlign = TextAlign.Center,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = state.findSubject(state.actionItem.subjectId).name + " · " +
                    state.shortDate(state.actionItem.nextReviewAt),
                fontSize = 8.5.sp,
                color = Tokens.muted,
                modifier = Modifier.padding(top = 4.dp)
            )
            Text(
                text = state.t("times", state.actionItem.reviewCount.toString()) + " · " +
                    state.t("days", state.actionItem.currentIntervalDays.toString()),
                fontSize = 8.5.sp,
                color = Tokens.mutedSoft,
                modifier = Modifier.padding(top = 3.dp)
            )
            Row(
                modifier = Modifier.padding(top = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(7.dp)
            ) {
                WearPill(
                    text = state.t("deleteAction"),
                    height = 30.dp,
                    fontSize = 9.5.sp,
                    background = hexColor("#FFE9E4"),
                    foreground = hexColor("#C7422C"),
                    paddingHorizontal = 11.dp,
                    onClick = { state.askDeleteRecord(state.actionItem) }
                )
                WearPill(
                    text = state.t("close"),
                    height = 30.dp,
                    fontSize = 9.5.sp,
                    background = Tokens.surfaceSoft,
                    foreground = Tokens.inkSoft,
                    paddingHorizontal = 11.dp,
                    onClick = { state.closeItemActions() }
                )
            }
        }
    }
}

@Composable
private fun WearConfirm(state: FolioState) {
    val scale = state.confirmScale.v("wearConfirmScale")
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(hexColor(state.pageBg())),
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier
                .padding(horizontal = 20.dp)
                .graphicsLayer {
                    scaleX = scale
                    scaleY = scale
                },
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = state.confirmTitle,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                color = Tokens.ink
            )
            Text(
                text = state.confirmMessage,
                fontSize = 9.sp,
                color = Tokens.muted,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 6.dp)
            )
            Row(
                modifier = Modifier.padding(top = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(7.dp)
            ) {
                WearPill(
                    text = state.t("cancel"),
                    height = 30.dp,
                    fontSize = 9.5.sp,
                    background = Tokens.surfaceSoft,
                    foreground = Tokens.inkSoft,
                    paddingHorizontal = 12.dp,
                    onClick = { state.cancelConfirm() }
                )
                WearPill(
                    text = state.t("delete"),
                    height = 30.dp,
                    fontSize = 9.5.sp,
                    background = hexColor(state.themeButton()),
                    foreground = hexColor(state.themeInk()),
                    paddingHorizontal = 12.dp,
                    onClick = { state.executeConfirm() }
                )
            }
        }
    }
}

/** 番茄钟：复用手机版的全屏圆盘，只是尺寸按表盘收 */
@Composable
private fun WearFocusClock(state: FolioState) {
    val scale = state.clockScale.v("wearClockScale")
    val clockPop = state.clockPop.v("wearClockPop")
    val accent = hexColor(state.clockAccent())
    val percent = if (state.focusRunning) state.focusRemainingPercent() else 100f
    val ringPercent by animateFloatAsState(
        targetValue = percent,
        animationSpec = androidx.compose.animation.core.tween(
            durationMillis = 300,
            easing = androidx.compose.animation.core.LinearEasing
        ),
        label = "wearRing"
    )
    val diameter = 158.dp

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(hexColor(state.pageBg()))
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            },
        contentAlignment = Alignment.Center
    ) {
        Box(
            modifier = Modifier.size(diameter),
            contentAlignment = Alignment.Center
        ) {
            Canvas(modifier = Modifier.fillMaxSize()) {
                val stroke = 6.dp.toPx()
                val inset = stroke / 2f
                val arcSize = Size(size.width - stroke, size.height - stroke)
                drawArc(
                    color = hexColor("#2E5E4B30"),
                    startAngle = 0f,
                    sweepAngle = 360f,
                    useCenter = false,
                    topLeft = Offset(inset, inset),
                    size = arcSize,
                    style = Stroke(width = stroke, cap = StrokeCap.Round)
                )
                drawArc(
                    color = accent,
                    startAngle = -90f,
                    sweepAngle = 360f * (ringPercent / 100f),
                    useCenter = false,
                    topLeft = Offset(inset, inset),
                    size = arcSize,
                    style = Stroke(width = stroke, cap = StrokeCap.Round)
                )
            }

            // 刻度：仍然是一分钟一格，走过的淡下去（380ms standard），和手机一致
            val tickCount = state.tickCount()
            for (index in 0 until tickCount) {
                Box(
                    modifier = Modifier
                        .size(diameter * 0.9f)
                        .graphicsLayer { rotationZ = index * 360f / tickCount },
                    contentAlignment = Alignment.TopCenter
                ) {
                    val tickAlpha by animateFloatAsState(
                        targetValue = state.tickOpacity(index),
                        animationSpec = androidx.compose.animation.core.tween(
                            durationMillis = Motion.slow,
                            easing = Motion.standard
                        ),
                        label = "wearTick$index"
                    )
                    Box(
                        modifier = Modifier
                            .size(width = 1.5.dp, height = 3.dp)
                            .clip(RoundedCornerShape(2.dp))
                            .background(accent.copy(alpha = tickAlpha))
                    )
                }
            }

            Column(
                modifier = Modifier.graphicsLayer {
                    scaleX = clockPop
                    scaleY = clockPop
                },
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                androidx.compose.foundation.Image(
                    painter = painterResource(R.drawable.tomato),
                    contentDescription = null,
                    modifier = Modifier.size(16.dp)
                )
                if (state.focusRunning) {
                    Text(
                        text = state.focusClock(),
                        fontSize = 26.sp,
                        fontWeight = FontWeight.Bold,
                        color = if (state.focusPaused) Tokens.muted else Tokens.ink,
                        modifier = Modifier.padding(top = 2.dp)
                    )
                    Text(
                        text = state.roundLabel(),
                        fontSize = 8.sp,
                        color = Tokens.muted,
                        modifier = Modifier.padding(top = 2.dp)
                    )
                } else {
                    Text(
                        text = state.minutesLabel(state.settings.focusMinutes),
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold,
                        color = Tokens.ink,
                        modifier = Modifier.padding(top = 4.dp)
                    )
                    Text(
                        text = state.t("focusTitle"),
                        fontSize = 8.sp,
                        color = Tokens.mutedSoft,
                        modifier = Modifier.padding(top = 2.dp)
                    )
                }
            }
        }

        // 操作：待机时是「开始专注」，跑起来是「暂停 / 结束」
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.BottomCenter) {
            if (state.focusRunning) {
                Row(
                    modifier = Modifier.padding(bottom = 14.dp),
                    horizontalArrangement = Arrangement.spacedBy(7.dp)
                ) {
                    WearPill(
                        text = if (state.focusPaused) state.t("focusResume") else state.t("focusPause"),
                        height = 30.dp,
                        fontSize = 9.5.sp,
                        background = Tokens.surfaceSoft,
                        foreground = Tokens.inkSoft,
                        paddingHorizontal = 11.dp,
                        onClick = {
                            if (state.focusPaused) state.resumeFocus() else state.pauseFocus()
                        }
                    )
                    WearPill(
                        text = state.t("focusEnd"),
                        height = 30.dp,
                        fontSize = 9.5.sp,
                        background = Tokens.surfaceSoft,
                        foreground = Tokens.coral,
                        paddingHorizontal = 11.dp,
                        onClick = { state.stopFocusEarly() }
                    )
                }
            } else {
                WearPill(
                    text = state.t("focusStartCycle"),
                    height = 34.dp,
                    fontSize = 10.sp,
                    background = hexColor(state.themeButton()),
                    foreground = hexColor(state.themeInk()),
                    fontWeight = FontWeight.Medium,
                    paddingHorizontal = 18.dp,
                    modifier = Modifier.padding(bottom = 14.dp),
                    onClick = { state.startCycle() }
                )
            }
        }

        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.TopEnd
        ) {
            Text(
                text = "×",
                fontSize = 15.sp,
                color = Tokens.mutedSoft,
                modifier = Modifier
                    .padding(top = 6.dp, end = 14.dp)
                    .pointerInput(Unit) {
                        detectTapGestures(onTap = { state.closeFocusClock() })
                    }
            )
        }
    }
}

@Composable
private fun WearMiniFocus(state: FolioState) {
    Row(
        modifier = Modifier
            .padding(top = 8.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(Tokens.surfaceSoft)
            .pointerInput(Unit) { detectTapGestures(onTap = { state.openFocusClock() }) }
            .padding(horizontal = 9.dp, vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        androidx.compose.foundation.Image(
            painter = painterResource(R.drawable.tomato),
            contentDescription = null,
            modifier = Modifier.size(10.dp)
        )
        Text(
            text = state.focusClock(),
            fontSize = 9.sp,
            fontWeight = FontWeight.Medium,
            color = Tokens.ink,
            modifier = Modifier.padding(start = 5.dp)
        )
    }
}

@Composable
private fun WearSummary(state: FolioState) {
    val scale = state.summaryScale.v("wearSummaryScale")
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(hexColor(state.pageBg())),
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier
                .graphicsLayer {
                    scaleX = scale
                    scaleY = scale
                },
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(text = state.t("focusSummary"), fontSize = 9.sp, color = Tokens.muted)
            Text(
                text = state.minutesLabel(state.summaryMinutes),
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                color = Tokens.ink,
                modifier = Modifier.padding(top = 3.dp)
            )
            Text(
                text = state.t(
                    "focusReviewed",
                    state.summaryItems.toString(),
                    state.summaryRemembered.toString()
                ),
                fontSize = 9.sp,
                color = Tokens.inkSoft,
                modifier = Modifier.padding(top = 5.dp)
            )
            WearMicroAction(state.t("focusDone")) { state.closeSummary() }
        }
    }
}

@Composable
private fun WearMicroAction(text: String, onClick: () -> Unit) {
    Text(
        text = text,
        fontSize = 9.sp,
        color = Tokens.mutedSoft,
        modifier = Modifier
            .padding(top = 10.dp)
            .pointerInput(Unit) { detectTapGestures(onTap = { onClick() }) }
    )
}

@Composable
private fun WearToast(state: FolioState) {
    val text = state.toastText ?: return
    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(bottom = 30.dp),
        contentAlignment = Alignment.BottomCenter
    ) {
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(10.dp))
                .background(Color(0xE62C251D))
                .padding(horizontal = 12.dp, vertical = 8.dp)
        ) {
            Text(text = text, fontSize = 9.sp, color = Color.White, textAlign = TextAlign.Center)
        }
    }
}
