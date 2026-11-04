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
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jiesheng.folio.domain.StudyItem
import com.jiesheng.folio.theme.Motion
import com.jiesheng.folio.theme.Tokens

/**
 * 今日页。入场是「标题左 / 列表下 / 已记右」的三段接力，
 * 位移与透明度都由 state 里的 Anim 驱动。
 */
@Composable
fun TodayPane(state: FolioState) {
    val titleIn = state.todayTitleIn.v("todayTitle")
    val progress = state.todayProgress.v("todayProgress")
    val loggedIn = state.todayLoggedIn.v("todayLogged")
    val listOpacity = state.listOpacity.v("listOpacity")
    val listShift = state.listShift.v("listShift")
    val countPop = state.countPop.v("countPop")
    val pageOpacity = state.pageOpacity.v("pageOpacity")
    val pageShift = state.pageShift.v("pageShift")

    val due = state.dueItems()
    val overdue = state.overdueItems()
    val created = state.todayCreatedItems()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .graphicsLayer {
                alpha = pageOpacity
                translationX = pageShift * density
            }
            .padding(
                start = if (state.isWide) 44.dp else 20.dp,
                end = if (state.isWide) 24.dp else 20.dp,
                top = if (state.isWide) 10.dp else 8.dp,
                bottom = if (state.isWide) 24.dp else 12.dp
            ),
        horizontalAlignment = Alignment.Start
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(
                    top = if (state.isWide) 10.dp else 8.dp,
                    bottom = if (overdue.isNotEmpty()) 10.dp else 16.dp
                )
                .graphicsLayer {
                    translationX = (1f - titleIn) * -state.mv(72f) * density
                    alpha = 0.3f + 0.7f * minOf(1f, titleIn * 1.8f)
                },
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = state.t("todayTitle"),
                fontSize = if (state.isWide) 48.sp else 34.sp,
                fontWeight = FontWeight.Bold,
                color = Tokens.ink,
                letterSpacing = (-1).sp
            )
            Row(
                modifier = Modifier
                    .padding(start = 12.dp)
                    .height(30.dp)
                    .graphicsLayer { scaleX = countPop; scaleY = countPop }
                    .clip(RoundedCornerShape(15.dp))
                    .background(Tokens.surfaceSoft)
                    .border(1.dp, hexColor("#A6FFC531"), RoundedCornerShape(15.dp))
                    .padding(horizontal = 11.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(5.dp)
                        .clip(CircleShape)
                        .background(Tokens.orange)
                )
                Text(
                    text = state.t("items", due.size.toString()),
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Medium,
                    color = hexColor("#9B5C00"),
                    modifier = Modifier.padding(start = 6.dp)
                )
            }
        }

        // 欠账要摆在明面上：漏了几天、最早欠到哪天
        if (overdue.isNotEmpty()) {
            Text(
                text = state.t("overdueHint", overdue.size.toString(), state.oldestOverdueLabel()),
                fontSize = 11.5.sp,
                color = Tokens.coral,
                modifier = Modifier
                    .padding(bottom = 16.dp)
                    .graphicsLayer {
                        translationX = (1f - titleIn) * -state.mv(72f) * density
                        alpha = 0.3f + 0.7f * minOf(1f, titleIn * 1.8f)
                    }
            )
        }

        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .graphicsLayer {
                    alpha = listOpacity
                    translationY = listShift * density
                },
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            if (due.isEmpty()) {
                item { EmptyToday(state) }
            } else {
                items(items = due, key = { it.id }) { item ->
                    val index = due.indexOf(item)
                    Box(
                        modifier = Modifier.graphicsLayer {
                            translationY = (1f - progress) *
                                (state.mv(36f) + index * state.mv(8f)) * density
                            alpha = 0.3f + 0.7f * minOf(1f, progress * 1.8f)
                        }
                    ) {
                        ReviewRow(state, item)
                    }
                }
            }
            if (due.isEmpty() && created.isNotEmpty() && !state.isWide) {
                item { Spacer(Modifier.fillMaxWidth().height(90.dp)) }
            }
            if (created.isNotEmpty()) {
                item {
                    Box(
                        modifier = Modifier.graphicsLayer {
                            translationX = (1f - loggedIn) * state.mv(72f) * density
                            alpha = 0.3f + 0.7f * minOf(1f, loggedIn * 1.8f)
                        }
                    ) {
                        TodayLogged(state, created, progress)
                    }
                }
            }
            item { Spacer(Modifier.height(24.dp)) }
        }
    }
}

@Composable
private fun EmptyToday(state: FolioState) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .height(230.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = state.t("todayEmptyTitle"),
            fontSize = 16.sp,
            fontWeight = FontWeight.Medium,
            color = Tokens.inkSoft
        )
        Text(
            text = state.t("todayEmptyBody"),
            fontSize = 11.sp,
            color = Tokens.muted,
            modifier = Modifier.padding(top = 8.dp)
        )
        PillButton(
            text = state.t("newEntry"),
            height = 38.dp,
            fontSize = 12.sp,
            background = hexColor(state.themeButton()),
            foreground = hexColor(state.themeInk()),
            borderRadius = 19.dp,
            paddingHorizontal = 18.dp,
            modifier = Modifier.padding(top = 18.dp),
            onClick = {
                if (state.isWide) {
                    state.toast(state.t("newEntry"))
                } else {
                    state.openComposer()
                }
            }
        )
    }
}

@Composable
private fun TodayLogged(state: FolioState, created: List<StudyItem>, progress: Float) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 8.dp, bottom = 2.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = state.t("todayLogged"),
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                color = Tokens.inkSoft
            )
            Text(
                text = state.t("items", created.size.toString()),
                fontSize = 9.sp,
                color = Tokens.mutedSoft,
                modifier = Modifier.padding(start = 7.dp)
            )
            Spacer(Modifier.weight(1f))
            Text(
                text = state.t("seeAll"),
                fontSize = 9.sp,
                color = hexColor("#B16A0A"),
                modifier = Modifier.pressable(0.9f) { state.switchTab(1) }
            )
        }

        created.forEachIndexed { index, item ->
            val subject = state.findSubject(item.subjectId)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .graphicsLayer {
                        translationY = (1f - progress) * (state.mv(20f) + index * state.mv(5f)) * density
                        alpha = minOf(1f, progress)
                    }
                    .clip(RoundedCornerShape(16.dp))
                    .background(Tokens.surface)
                    .border(1.dp, hexColor("#B3FFFFFF"), RoundedCornerShape(16.dp))
                    .pressable(0.97f, onLongPress = { state.openItemActions(item) }) { state.openItemActions(item) }
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(7.dp)
                        .clip(CircleShape)
                        .background(hexColor(subject.color))
                )
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .padding(start = 10.dp),
                    horizontalAlignment = Alignment.Start
                ) {
                    Text(
                        text = item.title,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = Tokens.ink,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Text(
                        text = subject.name + "  ·  " + state.t("next") + " " + state.shortDate(item.nextReviewAt),
                        fontSize = 9.sp,
                        color = Tokens.muted,
                        modifier = Modifier.padding(top = 3.dp)
                    )
                }
            }
        }
    }
}

/**
 * 待复习的一行：左边是科目色的圆环 + 实心点，中间标题，右边「复习」。
 * 按下时轻微缩小（90ms 进入 / 160ms 回位，和原版一致）。
 */
@Composable
private fun ReviewRow(state: FolioState, item: StudyItem) {
    val subject = state.findSubject(item.subjectId)
    var pressed by remember(item.id) { mutableStateOf(false) }
    val pressedId = state.pressedItemId
    val scale = if (pressedId == item.id) 0.985f else 1f

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .clip(RoundedCornerShape(22.dp))
            .shadowSoft(24.dp, 22.dp)
            .background(Tokens.surfaceSoft)
            .border(1.dp, hexColor("#B3FFFFFF"), RoundedCornerShape(22.dp))
            .pointerInput(item.id) {
                detectTapGestures(
                    onPress = {
                        pressed = true
                        state.pressedItemId = item.id
                        tryAwaitRelease()
                        pressed = false
                        state.pressedItemId = ""
                    }
                )
            }
            .padding(18.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(modifier = Modifier.size(30.dp), contentAlignment = Alignment.Center) {
            Canvas(modifier = Modifier.size(28.dp)) {
                drawCircle(
                    color = hexColor(subject.color),
                    radius = size.minDimension / 2f - 1f,
                    style = Stroke(width = 2.dp.toPx())
                )
            }
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(hexColor(subject.color))
            )
        }
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(start = 14.dp, end = 12.dp),
            horizontalAlignment = Alignment.Start
        ) {
            Text(text = subject.name, fontSize = 10.sp, fontWeight = FontWeight.Medium, color = Tokens.muted)
            Text(
                text = item.title,
                fontSize = 21.sp,
                fontWeight = FontWeight.Bold,
                color = Tokens.ink,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 4.dp)
            )
            Text(
                text = state.itemSubtitle(item),
                fontSize = 11.5.sp,
                color = hexColor(state.itemSubtitleColor(item)),
                modifier = Modifier.padding(top = 4.dp)
            )
        }
        PillButton(
            text = state.t("review"),
            height = 32.dp,
            fontSize = 10.5.sp,
            background = Tokens.surface,
            foreground = Tokens.inkSoft,
            borderRadius = 16.dp,
            borderColor = Tokens.line,
            paddingHorizontal = 12.dp,
            onClick = { state.openReview(item) }
        )
    }
}

