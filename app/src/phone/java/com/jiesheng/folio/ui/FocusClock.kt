package com.jiesheng.folio.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jiesheng.folio.R
import com.jiesheng.folio.theme.Motion
import com.jiesheng.folio.theme.Tokens

/**
 * 整页番茄钟。
 *
 * 环：Progress Ring 的等价物 —— 从正上方开始顺时针，随时间往回缩；
 * 刻度：一圈一格一分钟，走过的那些淡下去（380ms standard），
 * 中心：待机和倒计时两套排版通过 opacity+scale(0.92) 互换（260ms decel）。
 */
@Composable
fun FocusClockOverlay(state: FolioState) {
    val scale = state.clockScale.v("clockScale")
    val clockPop = state.clockPop.v("clockPop")
    val sizeDp = state.clockSize().dp
    val accent = hexColor(state.clockAccent())
    val percent = if (state.focusRunning) state.focusRemainingPercent() else 100f
    val ringPercent by animateFloatAsState(
        targetValue = percent,
        animationSpec = androidx.compose.animation.core.tween(
            durationMillis = 300,
            easing = androidx.compose.animation.core.LinearEasing
        ),
        label = "ringPercent"
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(hexColor(state.pageBg()))
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 16.dp, end = 16.dp, top = 32.dp),
            horizontalArrangement = Arrangement.End
        ) {
            Text(
                text = "×",
                fontSize = 24.sp,
                color = Tokens.muted,
                modifier = Modifier
                    .size(44.dp)
                    .pressable(0.88f) { state.closeFocusClock() }
            )
        }

        Spacer(Modifier.weight(1f))

        Box(
            modifier = Modifier
                .size(sizeDp)
                .align(Alignment.CenterHorizontally),
            contentAlignment = Alignment.Center
        ) {
            // 底环 + 进度环
            Canvas(modifier = Modifier.fillMaxSize()) {
                val stroke = maxOf(9f, sizeDp.value * 0.032f).dp.toPx()
                val inset = stroke / 2f
                val arcSize = Size(this.size.width - stroke, this.size.height - stroke)
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

            // 一圈一格一分钟：走过的那些淡下去，剩下的跟着圆弧一起减少
            val tickCount = state.tickCount()
            for (index in 0 until tickCount) {
                Box(
                    modifier = Modifier
                        .size((sizeDp.value * 0.9f).dp)
                        .graphicsLayer { rotationZ = index * 360f / tickCount },
                    contentAlignment = Alignment.TopCenter
                ) {
                    val tickAlpha by animateFloatAsState(
                        targetValue = state.tickOpacity(index),
                        animationSpec = ease(Motion.slow, Motion.standard),
                        label = "tick$index"
                    )
                    Box(
                        modifier = Modifier
                            .size(
                                width = maxOf(2f, sizeDp.value * 0.008f).dp,
                                height = maxOf(4f, sizeDp.value * 0.02f).dp
                            )
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
                    modifier = Modifier
                        .size((sizeDp.value * 0.11f).dp)
                        .graphicsLayer {
                            alpha = if (state.focusRunning && state.focusPaused) 0.45f else 1f
                        }
                )
                if (state.focusRunning) {
                    // 待机 → 倒计时：两套排版以 opacity + scale(0.92) 互换，260ms decel
                    Text(
                        text = state.focusClock(),
                        fontSize = (sizeDp.value * 0.26f).sp,
                        fontWeight = FontWeight.Bold,
                        color = if (state.focusPaused) Tokens.muted else Tokens.ink,
                        modifier = Modifier.padding(top = 8.dp)
                    )
                    Text(
                        text = state.roundLabel(),
                        fontSize = maxOf(12f, sizeDp.value * 0.055f).sp,
                        color = Tokens.muted,
                        modifier = Modifier.padding(top = 6.dp)
                    )
                } else {
                    Text(
                        text = state.minutesLabel(state.settings.focusMinutes),
                        fontSize = (sizeDp.value * 0.15f).sp,
                        fontWeight = FontWeight.Bold,
                        color = Tokens.ink,
                        modifier = Modifier.padding(top = 12.dp)
                    )
                    Text(
                        text = state.t("focusTitle"),
                        fontSize = maxOf(10f, sizeDp.value * 0.045f).sp,
                        color = Tokens.mutedSoft,
                        modifier = Modifier.padding(top = 4.dp)
                    )
                }
            }
        }

        if (state.focusRunning) {
            Text(
                text = state.t("focusElapsed", state.elapsedClock()) + " · " +
                    state.minutesLabel(state.focusPlannedMinutes),
                fontSize = 13.sp,
                color = Tokens.mutedSoft,
                modifier = Modifier
                    .align(Alignment.CenterHorizontally)
                    .padding(top = 22.dp)
            )
        }

        Spacer(Modifier.weight(1f))

        if (state.focusRunning) {
            Row(
                modifier = Modifier
                    .align(Alignment.CenterHorizontally)
                    .padding(bottom = 28.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = if (state.focusPaused) state.t("focusResume") else state.t("focusPause"),
                    fontSize = 14.sp,
                    color = Tokens.inkSoft,
                    modifier = Modifier
                        .height(44.dp)
                        .pressable(0.94f) {
                            if (state.focusPaused) state.resumeFocus() else state.pauseFocus()
                        }
                        .padding(horizontal = 22.dp)
                )
                Text(
                    text = state.t("focusEnd"),
                    fontSize = 14.sp,
                    color = Tokens.coral,
                    modifier = Modifier
                        .padding(start = 8.dp)
                        .height(44.dp)
                        .padding(horizontal = 22.dp)
                        .pressable(0.94f) { state.stopFocusEarly() }
                )
            }
        } else {
            PillButton(
                text = state.t("focusStartCycle"),
                height = 46.dp,
                fontSize = 14.sp,
                background = hexColor(state.themeButton()),
                foreground = hexColor(state.themeInk()),
                borderRadius = 23.dp,
                fontWeight = FontWeight.Medium,
                paddingHorizontal = 30.dp,
                modifier = Modifier
                    .align(Alignment.CenterHorizontally)
                    .padding(bottom = 36.dp),
                onClick = { state.startCycle() }
            )
        }
    }
}

/** 其它页面顶部的迷你专注条 */
@Composable
fun FocusMiniBar(state: FolioState) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 20.dp, end = 20.dp, bottom = 8.dp)
    ) {
        Row(
            modifier = Modifier
                .then(if (state.isWide) Modifier.fillMaxWidth(0.7f) else Modifier.fillMaxWidth())
                .height(36.dp)
                .clip(RoundedCornerShape(18.dp))
                .background(Tokens.surfaceSoft)
                .border(1.dp, hexColor("#A6FFC531"), RoundedCornerShape(18.dp))
                .pressable(0.97f) { state.switchTab(0) }
                .padding(horizontal = 14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            androidx.compose.foundation.Image(
                painter = painterResource(R.drawable.tomato),
                contentDescription = null,
                modifier = Modifier
                    .size(15.dp)
                    .graphicsLayer { alpha = if (state.focusPaused) 0.4f else 1f }
            )
            Text(
                text = state.focusClock(),
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                color = Tokens.ink,
                modifier = Modifier.padding(start = 8.dp)
            )
            Text(
                text = if (state.focusIsBreak) state.t("focusBreaking") else state.t("focusCardTitle"),
                fontSize = 9.5.sp,
                color = Tokens.muted,
                modifier = Modifier.padding(start = 6.dp)
            )
            Spacer(Modifier.weight(1f))
            Text(text = "›", fontSize = 13.sp, color = Tokens.mutedSoft)
        }
    }
}

/** 一轮循环结束的累计小结 */
@Composable
fun FocusSummaryOverlay(state: FolioState) {
    val scale = state.summaryScale.v("summaryScale")
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Tokens.dim)
                .pressable(1f) { state.closeSummary() }
        )
        Column(
            modifier = Modifier
                .width(244.dp)
                .graphicsLayer {
                    scaleX = scale
                    scaleY = scale
                }
                .clip(RoundedCornerShape(24.dp))
                .shadowSoft(36.dp, 24.dp)
                .background(Tokens.surfaceSolid)
                .border(1.dp, hexColor("#CCFFFFFF"), RoundedCornerShape(24.dp))
                .padding(start = 14.dp, end = 14.dp, top = 20.dp, bottom = 2.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = state.t("focusSummary"),
                fontSize = 11.sp,
                color = Tokens.muted,
                modifier = Modifier.padding(top = 4.dp)
            )
            Text(
                text = state.minutesLabel(state.summaryMinutes),
                fontSize = 34.sp,
                fontWeight = FontWeight.Bold,
                color = Tokens.ink,
                letterSpacing = (-0.5).sp,
                modifier = Modifier.padding(top = 6.dp)
            )
            Text(
                text = state.t("focusReviewed", state.summaryItems.toString(), state.summaryRemembered.toString()),
                fontSize = 11.5.sp,
                color = Tokens.inkSoft,
                modifier = Modifier.padding(top = 10.dp)
            )
            Text(
                text = state.t("focusSegments", state.summarySegments.toString()) + " · " +
                    state.clockLabel(state.summaryStart) + " – " + state.clockLabel(state.summaryEnd),
                fontSize = 10.sp,
                color = Tokens.mutedSoft,
                modifier = Modifier.padding(top = 5.dp)
            )
            Text(
                text = state.t("focusDone"),
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                color = hexColor(state.themeButton()),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(44.dp)
                    .padding(top = 10.dp)
                    .pressable(0.94f) { state.closeSummary() },
                textAlign = androidx.compose.ui.text.style.TextAlign.Center
            )
        }
    }
}
