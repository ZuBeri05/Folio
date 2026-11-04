package com.jiesheng.folio.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jiesheng.folio.theme.Tokens

/**
 * 记录详情 / 修改浮层：整层 0.90 → 1 弹入，关闭时 260ms accel 缩到 0.94 再撤。
 */
@Composable
fun ItemActionsOverlay(state: FolioState) {
    val overlay = state.actionOverlayOpacity.v("actionOverlay")
    val scale = state.actionScale.v("actionScale")
    val content = state.actionContentOpacity.v("actionContent")

    Box(
        modifier = Modifier
            .fillMaxSize()
            .graphicsLayer { alpha = overlay },
        contentAlignment = Alignment.Center
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Tokens.dim)
                .pressable(1f) { state.closeItemActions() }
        )
        Column(
            modifier = Modifier
                .then(if (state.isWide) Modifier.width(560.dp) else Modifier.fillMaxWidth(0.92f))
                .graphicsLayer {
                    scaleX = scale
                    scaleY = scale
                    alpha = content
                }
                .clip(RoundedCornerShape(26.dp))
                .shadowSoft(40.dp, 26.dp)
                .background(Tokens.surfaceSolid)
                .border(1.dp, hexColor("#CCFFFFFF"), RoundedCornerShape(26.dp))
                .padding(24.dp)
        ) {
            Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = if (state.actionMode == "view") state.t("detailRecord") else state.t("editRecord"),
                    fontSize = 11.sp,
                    color = Tokens.muted
                )
                Spacer(Modifier.weight(1f))
                PillButton(
                    text = state.t("close"),
                    height = 30.dp,
                    fontSize = 9.sp,
                    background = Tokens.yellowSoft,
                    foreground = hexColor("#6C4B00"),
                    borderRadius = 14.dp,
                    paddingHorizontal = 11.dp,
                    onClick = { state.closeItemActions() }
                )
            }

            if (state.actionMode == "view") {
                Text(
                    text = state.actionItem.title,
                    fontSize = 26.sp,
                    fontWeight = FontWeight.Bold,
                    color = Tokens.ink,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 16.dp)
                )
                Text(
                    text = state.findSubject(state.actionItem.subjectId).name + "  ·  " +
                        state.t("next") + " " + state.shortDate(state.actionItem.nextReviewAt),
                    fontSize = 10.sp,
                    color = Tokens.muted,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 7.dp)
                )
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 14.dp)
                        .clip(RoundedCornerShape(14.dp))
                        .background(Tokens.surfaceSoft)
                        .padding(12.dp)
                ) {
                    StatCell(state.t("created"), state.shortDate(state.actionItem.createdAt), Modifier.weight(1f), state)
                    StatCell(state.t("reviewed"), state.t("times", state.actionItem.reviewCount.toString()), Modifier.weight(1f), state)
                    StatCell(state.t("currentInterval"), state.t("days", state.actionItem.currentIntervalDays.toString()), Modifier.weight(1f), state)
                }
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 18.dp, bottom = 16.dp)
                        .height(1.dp)
                        .background(Tokens.line)
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    PillButton(
                        text = state.t("modify"),
                        height = 44.dp,
                        fontSize = 12.sp,
                        background = hexColor(state.themeButton()),
                        foreground = hexColor(state.themeInk()),
                        borderRadius = 13.dp,
                        fontWeight = FontWeight.Medium,
                        modifier = Modifier.weight(1f),
                        onClick = { state.startEditItem() }
                    )
                    PillButton(
                        text = state.t("deleteAction"),
                        height = 44.dp,
                        fontSize = 12.sp,
                        background = hexColor("#FFE9E4"),
                        foreground = hexColor("#C7422C"),
                        borderRadius = 13.dp,
                        fontWeight = FontWeight.Medium,
                        modifier = Modifier.weight(1f),
                        onClick = { state.deleteFromAction() }
                    )
                }
            } else {
                Text(text = state.t("titleLabel"), fontSize = 9.sp, color = Tokens.muted)
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 7.dp)
                        .height(44.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(Tokens.surfaceSolid)
                        .border(1.dp, hexColor("#B3FFFFFF"), RoundedCornerShape(12.dp))
                        .padding(horizontal = 12.dp),
                    contentAlignment = Alignment.CenterStart
                ) {
                    BasicTextField(
                        value = state.editTitle,
                        onValueChange = { state.editTitle = it },
                        singleLine = true,
                        textStyle = TextStyle(fontSize = 15.sp, color = Tokens.ink),
                        modifier = Modifier.fillMaxWidth()
                    )
                }
                Text(
                    text = state.t("subject"),
                    fontSize = 9.sp,
                    color = Tokens.muted,
                    modifier = Modifier.padding(top = 14.dp)
                )
                WrapRow(modifier = Modifier.padding(top = 5.dp)) {
                    state.subjects.forEach { subject ->
                        val selected = state.editSubjectId == subject.id
                        PillButton(
                            text = subject.name,
                            height = 30.dp,
                            fontSize = 10.sp,
                            background = hexColor(if (selected) state.themeButton() else "#D9FFFDF8"),
                            foreground = hexColor(if (selected) state.themeInk() else "#4B4032"),
                            borderRadius = 15.dp,
                            borderColor = hexColor(if (selected) state.themeButton() else "#1A5E4B30"),
                            paddingHorizontal = 11.dp,
                            modifier = Modifier.padding(end = 6.dp, bottom = 6.dp),
                            onClick = { state.editSubjectId = subject.id }
                        )
                    }
                }
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 10.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    PillButton(
                        text = state.t("cancel"),
                        height = 42.dp,
                        fontSize = 12.sp,
                        background = Tokens.surfaceSoft,
                        foreground = Tokens.inkSoft,
                        borderRadius = 12.dp,
                        modifier = Modifier.weight(1f),
                        onClick = { state.changeActionMode("view") }
                    )
                    PillButton(
                        text = state.t("save"),
                        height = 42.dp,
                        fontSize = 12.sp,
                        background = hexColor(state.themeButton()),
                        foreground = hexColor(state.themeInk()),
                        borderRadius = 12.dp,
                        fontWeight = FontWeight.Medium,
                        modifier = Modifier.weight(1f),
                        onClick = { state.saveItemEdit() }
                    )
                }
            }
        }
    }
}

@Composable
private fun StatCell(label: String, value: String, modifier: Modifier, state: FolioState) {
    Column(modifier = modifier, horizontalAlignment = Alignment.Start) {
        Text(text = label, fontSize = 8.sp, color = Tokens.mutedSoft)
        Text(
            text = value,
            fontSize = 11.sp,
            color = Tokens.inkSoft,
            modifier = Modifier.padding(top = 3.dp)
        )
    }
}

/** 删除确认：面板 0.94 → 1（snap 弹簧），关闭时 170ms accel 缩回去 */
@Composable
fun ConfirmOverlay(state: FolioState) {
    val scale = state.confirmScale.v("confirmScale")
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Tokens.dim)
                .pressable(1f) { state.cancelConfirm() }
        )
        Column(
            modifier = Modifier
                .then(if (state.isWide) Modifier.width(440.dp) else Modifier.fillMaxWidth(0.88f))
                .graphicsLayer {
                    scaleX = scale
                    scaleY = scale
                }
                .clip(RoundedCornerShape(24.dp))
                .shadowSoft(40.dp, 24.dp)
                .background(Tokens.surfaceSolid)
                .border(1.dp, hexColor("#CCFFFFFF"), RoundedCornerShape(24.dp))
                .padding(24.dp)
        ) {
            Text(
                text = state.confirmTitle,
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                color = Tokens.ink,
                modifier = Modifier.fillMaxWidth()
            )
            Text(
                text = state.confirmMessage,
                fontSize = 11.sp,
                color = Tokens.muted,
                lineHeight = 18.sp,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 10.dp, bottom = 18.dp)
            )
            PillButton(
                text = if (state.confirmKind == "subject") {
                    state.t("deleteSubjectTitle")
                } else {
                    state.t("deleteRecordTitle")
                },
                height = 46.dp,
                fontSize = 13.sp,
                background = hexColor(state.themeButton()),
                foreground = hexColor(state.themeInk()),
                borderRadius = 14.dp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.fillMaxWidth(),
                onClick = { state.executeConfirm() }
            )
            PillButton(
                text = state.t("cancel"),
                height = 38.dp,
                fontSize = 12.sp,
                background = androidx.compose.ui.graphics.Color.Transparent,
                foreground = Tokens.muted,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 4.dp),
                onClick = { state.cancelConfirm() }
            )
        }
    }
}

/**
 * 时间选择器：两个滑轮（小时 / 分钟），行高 34dp、共 150dp，
 * 上下逐级变小变淡，中间那格是 21sp 深色，和原版 TextPicker 的
 * textStyle / selectedTextStyle / disappearTextStyle 对齐。
 */
@Composable
fun TimePickerOverlay(state: FolioState) {
    val scale = state.timePickerScale.v("timePickerScale")
    val hourList = rememberLazyListState(initialFirstVisibleItemIndex = state.pickerHour)
    val minuteList = rememberLazyListState(initialFirstVisibleItemIndex = state.pickerMinute)

    // 滑轮滚动时同步回 state，确认时直接用这两个值
    androidx.compose.runtime.LaunchedEffect(hourList.firstVisibleItemIndex, hourList.isScrollInProgress) {
        if (!hourList.isScrollInProgress) {
            state.pickerHour = hourList.firstVisibleItemIndex.coerceIn(0, 23)
        }
    }
    androidx.compose.runtime.LaunchedEffect(minuteList.firstVisibleItemIndex, minuteList.isScrollInProgress) {
        if (!minuteList.isScrollInProgress) {
            state.pickerMinute = minuteList.firstVisibleItemIndex.coerceIn(0, 59)
        }
    }

    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Tokens.dim)
                .pressable(1f) { state.cancelTimePicker() }
        )
        Column(
            modifier = Modifier
                .width(198.dp)
                .graphicsLayer {
                    scaleX = scale
                    scaleY = scale
                }
                .clip(RoundedCornerShape(22.dp))
                .shadowSoft(36.dp, 22.dp)
                .background(Tokens.surfaceSolid)
                .border(1.dp, hexColor("#CCFFFFFF"), RoundedCornerShape(22.dp))
                .padding(start = 10.dp, end = 10.dp, top = 8.dp, bottom = 4.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center
            ) {
                Wheel(hourList, 58.dp, 24)
                Text(
                    text = ":",
                    fontSize = 19.sp,
                    fontWeight = FontWeight.Medium,
                    color = Tokens.ink,
                    modifier = Modifier.padding(horizontal = 3.dp)
                )
                Wheel(minuteList, 58.dp, 60)
            }
            Row(modifier = Modifier
                .fillMaxWidth()
                .padding(top = 2.dp)) {
                Text(
                    text = state.t("cancel"),
                    fontSize = 12.5.sp,
                    color = Tokens.muted,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .weight(1f)
                        .height(42.dp)
                        .pressable(0.94f) { state.cancelTimePicker() }
                )
                Text(
                    text = state.t("confirm"),
                    fontSize = 12.5.sp,
                    fontWeight = FontWeight.Medium,
                    color = hexColor(state.themeButton()),
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .weight(1f)
                        .height(42.dp)
                        .pressable(0.94f) { state.confirmTimePicker() }
                )
            }
        }
    }
}

@Composable
private fun Wheel(listState: LazyListState, width: androidx.compose.ui.unit.Dp, count: Int) {
    val fling = androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior(lazyListState = listState)
    Box(
        modifier = Modifier
            .width(width)
            .height(150.dp)
    ) {
        LazyColumn(
            state = listState,
            flingBehavior = fling,
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = 58.dp)
        ) {
            items(count = count) { index ->
                // 距离中心多少格 → 字号与颜色，模拟滚轮的透视
                val center = listState.firstVisibleItemIndex +
                    listState.firstVisibleItemScrollOffset / 58f
                val distance = minOf(2f, kotlin.math.abs(index - center))
                val selected = distance < 0.5f
                Box(
                    modifier = Modifier
                        .height(34.dp)
                        .fillMaxWidth(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = if (index < 10) "0$index" else "$index",
                        fontSize = (21f - distance * 3f).sp,
                        fontWeight = if (selected) FontWeight.Medium else FontWeight.Normal,
                        color = if (selected) Tokens.ink else if (distance < 1.6f) Tokens.mutedSoft else hexColor("#D8CEBA")
                    )
                }
            }
        }
    }
}
