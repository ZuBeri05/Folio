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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jiesheng.folio.domain.DayCount
import com.jiesheng.folio.theme.Motion
import com.jiesheng.folio.theme.Tokens

/**
 * 日历页：每行从右撞入（bounce 弹簧），逐行错峰，
 * 切换 7 / 14 / 30 天时整体重放一遍入场，和原版 playCalendarRows() 一致。
 */
@Composable
fun CalendarPage(state: FolioState) {
    val pageOpacity = state.pageOpacity.v("calendarPageOpacity")
    val pageShift = state.pageShift.v("calendarPageShift")
    val days = state.upcoming()
    val overdueCount = state.overdueItems().size

    Column(
        modifier = Modifier
            .fillMaxSize()
            .graphicsLayer {
                alpha = pageOpacity
                translationX = pageShift * density
            }
            .padding(bottom = 24.dp),
        horizontalAlignment = Alignment.Start
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(
                    start = if (state.isWide) 52.dp else 20.dp,
                    end = if (state.isWide) 52.dp else 20.dp,
                    top = 24.dp,
                    bottom = 18.dp
                ),
            verticalAlignment = Alignment.Bottom
        ) {
            Column(horizontalAlignment = Alignment.Start) {
                Text(
                    text = state.t("calendarTitle"),
                    fontSize = if (state.isWide) 44.sp else 32.sp,
                    fontWeight = FontWeight.Bold,
                    color = Tokens.ink
                )
                Text(
                    text = state.t("nextDays", state.calendarDays.toString()),
                    fontSize = 11.sp,
                    color = Tokens.muted,
                    modifier = Modifier.padding(top = 6.dp)
                )
            }
            Spacer(Modifier.weight(1f))
            // 看多远由自己定：7 天够用，30 天看一整月
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                listOf(7, 14, 30).forEach { value ->
                    val selected = state.calendarDays == value
                    val background by androidx.compose.animation.animateColorAsState(
                        targetValue = if (selected) Tokens.yellowSoft else Tokens.surfaceSoft,
                        animationSpec = easeColor(Motion.quick, Motion.standard),
                        label = "calRange$value"
                    )
                    Text(
                        text = state.t("days", value.toString()),
                        fontSize = 10.5.sp,
                        fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
                        color = hexColor(if (selected) "#6C4B00" else "#8D7F6C"),
                        modifier = Modifier
                            .clip(RoundedCornerShape(12.dp))
                            .background(background)
                            .pressable(0.92f) {
                                if (state.calendarDays != value) {
                                    state.calendarDays = value
                                    state.playCalendarRows()
                                }
                            }
                            .padding(horizontal = 12.dp, vertical = 6.dp)
                    )
                }
            }
        }

        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .padding(horizontal = if (state.isWide) 52.dp else 20.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(items = days, key = { it.date }) { day ->
                val index = days.indexOf(day)
                val x = if (index < state.calendarX.size) state.calendarX[index].v() else 0f
                val alpha = if (index < state.calendarAlpha.size) state.calendarAlpha[index].v() else 1f
                CalendarRow(state, day, index, overdueCount, x, alpha)
            }
            item { Spacer(Modifier.height(24.dp)) }
        }
    }
}

@Composable
private fun CalendarRow(
    state: FolioState,
    day: DayCount,
    index: Int,
    overdueCount: Int,
    x: Float,
    alpha: Float
) {
    val entries = state.dayItems(day.date, index == 0)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .graphicsLayer {
                this.alpha = minOf(1f, alpha)
                translationX = x * density
            }
            .clip(RoundedCornerShape(18.dp))
            .background(if (day.count == 0) hexColor("#66FFFDF8") else Tokens.surfaceSoft)
            .then(
                if (day.count == 0) Modifier
                else Modifier.border(1.dp, hexColor("#B3FFFFFF"), RoundedCornerShape(18.dp))
            )
            .padding(
                start = 16.dp,
                end = 16.dp,
                top = if (day.count == 0) 10.dp else 16.dp,
                bottom = if (day.count == 0) 10.dp else 16.dp
            ),
        verticalAlignment = Alignment.Top
    ) {
        Column(modifier = Modifier.width(64.dp), horizontalAlignment = Alignment.Start) {
            Text(
                text = state.shortDate(day.date),
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = Tokens.ink
            )
            Text(
                text = state.weekday(day.date),
                fontSize = 9.sp,
                color = Tokens.muted,
                modifier = Modifier.padding(top = 2.dp)
            )
            if (index == 0 && overdueCount > 0) {
                Text(
                    text = state.t("overdueInDay", overdueCount.toString()),
                    fontSize = 8.5.sp,
                    fontWeight = FontWeight.Medium,
                    color = Tokens.coral,
                    maxLines = 1,
                    modifier = Modifier.padding(top = 3.dp)
                )
            }
        }
        if (day.count == 0) {
            Text(text = state.t("noPlan"), fontSize = 11.sp, color = Tokens.mutedSoft)
        } else {
            WrapRow(modifier = Modifier.weight(1f)) {
                entries.forEach { item ->
                    val subject = state.findSubject(item.subjectId)
                    Row(
                        modifier = Modifier
                            .padding(end = 6.dp, bottom = 6.dp)
                            .clip(RoundedCornerShape(10.dp))
                            .background(Tokens.surface)
                            .padding(horizontal = 9.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(6.dp)
                                .clip(CircleShape)
                                .background(hexColor(subject.color))
                        )
                        Text(
                            text = item.title,
                            fontSize = 11.sp,
                            color = Tokens.inkSoft,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier
                                .padding(start = 7.dp)
                                .widthIn(max = 200.dp)
                        )
                    }
                }
            }
        }
    }
}
