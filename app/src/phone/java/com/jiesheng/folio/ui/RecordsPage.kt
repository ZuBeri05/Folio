package com.jiesheng.folio.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jiesheng.folio.domain.StudyItem
import com.jiesheng.folio.theme.Motion
import com.jiesheng.folio.theme.Tokens

/**
 * 记录页。入场是时间轴逐段生长、卡片被牵出来：
 * 每张卡的竖线从 scaleY 0 → 1 长到那一行，卡片同时从左侧 -26 滑进来、透明度 0 → 1，
 * 逐张错开 55ms（最多错 8 档），和鸿蒙版 playRecords() 一模一样。
 */
@Composable
fun RecordsPage(state: FolioState) {
    val pageOpacity = state.pageOpacity.v("recordsPageOpacity")
    val pageShift = state.pageShift.v("recordsPageShift")
    val listOpacity = state.listOpacity.v("recordsListOpacity")
    val listShift = state.listShift.v("recordsListShift")
    val items = state.sortedItems()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .graphicsLayer {
                alpha = pageOpacity
                translationX = pageShift * density
            }
            .padding(
                start = if (state.isWide) 52.dp else 20.dp,
                end = if (state.isWide) 52.dp else 20.dp,
                top = 6.dp,
                bottom = 24.dp
            ),
        horizontalAlignment = Alignment.Start
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 24.dp, bottom = 18.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = state.t("recordsTitle"),
                fontSize = if (state.isWide) 44.sp else 32.sp,
                fontWeight = FontWeight.Bold,
                color = Tokens.ink
            )
            Spacer(Modifier.weight(1f))
            Text(text = state.t("items", state.items.size.toString()), fontSize = 11.sp, color = Tokens.muted)
        }

        if (state.focusSessions.isNotEmpty()) {
            FocusWeekCard(state)
        }

        if (items.isEmpty()) {
            Text(
                text = state.t("noRecords"),
                fontSize = 14.sp,
                color = Tokens.muted,
                modifier = Modifier.padding(top = 80.dp)
            )
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .graphicsLayer {
                        alpha = listOpacity
                        translationY = listShift * density
                    }
            ) {
                items(items = items, key = { it.id }) { item ->
                    val index = items.indexOf(item)
                    RecordRow(state, item, index)
                }
                item { Spacer(Modifier.height(24.dp)) }
            }
        }
    }
}

@Composable
private fun RecordRow(state: FolioState, item: StudyItem, index: Int) {
    val progress = state.recIn[minOf(index, 11)].v("recIn$index")
    val subject = state.findSubject(item.subjectId)
    val density = LocalDensity.current

    Row(modifier = Modifier.fillMaxWidth()) {
        // 时间轴：竖线从上往下生长，长到哪行哪行被牵出来
        Box(
            modifier = Modifier
                .width(14.dp)
                .height(with(density) { (state.recRowH + 10f).toDp() }),
            contentAlignment = Alignment.Center
        ) {
            Canvas(
                modifier = Modifier
                    .width(1.5.dp)
                    .fillMaxHeight()
                    .graphicsLayer {
                        scaleY = progress
                        transformOrigin = androidx.compose.ui.graphics.TransformOrigin(0.5f, 0f)
                    }
            ) {
                drawLine(
                    color = Tokens.lineStrong,
                    start = Offset(size.width / 2f, 0f),
                    end = Offset(size.width / 2f, size.height),
                    strokeWidth = 1.5.dp.toPx()
                )
            }
        }

        // 日期：在线的右边、卡片外面
        Column(
            modifier = Modifier
                .width(62.dp)
                .padding(top = 16.dp)
                .graphicsLayer { alpha = progress },
            horizontalAlignment = Alignment.Start
        ) {
            Text(
                text = state.shortDate(item.createdAt),
                fontSize = 11.sp,
                fontWeight = FontWeight.Medium,
                color = Tokens.muted
            )
            Text(
                text = state.weekday(item.createdAt),
                fontSize = 9.sp,
                color = Tokens.mutedSoft,
                modifier = Modifier.padding(top = 2.dp)
            )
        }

        Row(
            modifier = Modifier
                .weight(1f)
                .graphicsLayer {
                    translationX = (1f - progress) * -state.mv(26f) * density.density
                    alpha = progress
                }
                .onSizeChanged { size ->
                    val h = with(density) { size.height.toDp().value }
                    if (h > 1f && Math.abs(h - state.recRowH) > 0.5f) {
                        state.recRowH = h
                    }
                }
                .pressable(0.97f, onLongPress = { state.openItemActions(item) }) {
                    state.openItemActions(item)
                }
                .clip(RoundedCornerShape(18.dp))
                .background(Tokens.surfaceSoft)
                .border(1.dp, hexColor("#B3FFFFFF"), RoundedCornerShape(18.dp))
                .padding(16.dp),
            verticalAlignment = Alignment.Top
        ) {
            Column(modifier = Modifier.weight(1f), horizontalAlignment = Alignment.Start) {
                Text(text = subject.name, fontSize = 9.5.sp, color = hexColor(subject.color))
                Text(
                    text = item.title,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium,
                    color = Tokens.ink,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(top = 3.dp)
                )
            }
            Column(
                modifier = Modifier.padding(end = if (state.isWide) 14.dp else 8.dp),
                horizontalAlignment = Alignment.End
            ) {
                Text(text = state.t("next"), fontSize = 8.sp, color = Tokens.mutedSoft)
                Text(
                    text = state.shortDate(item.nextReviewAt),
                    fontSize = 10.sp,
                    color = Tokens.muted,
                    modifier = Modifier.padding(top = 2.dp)
                )
            }
        }
    }
}

/**
 * 本周专注柱状图。柱子长上来而不是瞬间变高：settle 弹簧 260ms。
 */
@Composable
fun FocusWeekCard(state: FolioState) {
    val buckets = state.weekFocus()
    val todayIndex = state.todayWeekIndex()

    Column(
        modifier = Modifier
            .then(if (state.isWide) Modifier.width(560.dp) else Modifier.fillMaxWidth())
            .padding(bottom = 18.dp)
            .clip(RoundedCornerShape(18.dp))
            .background(Tokens.surfaceSoft)
            .border(1.dp, hexColor("#B3FFFFFF"), RoundedCornerShape(18.dp))
            .padding(start = 16.dp, end = 16.dp, top = 14.dp, bottom = 10.dp)
    ) {
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = state.t("focusCardTitle"),
                fontSize = 10.5.sp,
                fontWeight = FontWeight.Medium,
                color = Tokens.muted
            )
            Spacer(Modifier.weight(1f))
            Text(
                text = state.t(
                    "focusTodayTotal",
                    state.minutesLabel(state.todayFocusMinutes()),
                    state.todayFocusCount().toString()
                ),
                fontSize = 10.sp,
                color = Tokens.mutedSoft
            )
        }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(54.dp)
                .padding(top = 10.dp),
            verticalAlignment = Alignment.Bottom
        ) {
            for (index in 0..6) {
                val height = androidx.compose.animation.core.animateFloatAsState(
                    targetValue = state.weekBarHeight(buckets[index]),
                    animationSpec = Motion.settle(),
                    label = "weekBar$index"
                )
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .height(54.dp)
                        .padding(horizontal = 3.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Bottom
                ) {
                    Box(
                        modifier = Modifier
                            .width(18.dp)
                            .height(height.value.dp)
                            .clip(RoundedCornerShape(3.dp))
                            .background(if (index == todayIndex) Tokens.coral else hexColor("#E8DCC4"))
                    )
                    Text(
                        text = state.weekday(state.weekDayTs(index)),
                        fontSize = 8.sp,
                        color = if (index == todayIndex) Tokens.coral else Tokens.mutedSoft,
                        modifier = Modifier.padding(top = 5.dp)
                    )
                }
            }
        }
    }
}
