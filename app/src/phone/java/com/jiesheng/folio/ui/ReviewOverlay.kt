package com.jiesheng.folio.ui

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
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
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jiesheng.folio.theme.Motion
import com.jiesheng.folio.theme.Tokens

/**
 * 复习浮层：整层从 0.90 放大到 1、透明度 0 → 1（settle 弹簧），
 * 关闭时 260ms accel 缩到 0.94 再撤掉。
 */
@Composable
fun ReviewOverlay(state: FolioState) {
    val opacity = state.reviewOpacity.v("reviewOpacity")
    val scale = state.reviewScale.v("reviewScale")

    Box(modifier = Modifier.fillMaxSize()) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Tokens.dim)
                .pressable(1f) { state.closeReview() }
        )
        Box(
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer {
                    alpha = opacity
                    scaleX = scale
                    scaleY = scale
                }
                .padding(
                    start = if (state.isWide) 40.dp else 16.dp,
                    end = if (state.isWide) 40.dp else 16.dp,
                    top = 10.dp,
                    bottom = 20.dp
                )
        ) {
            if (state.isWide) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    if (state.reviewStage == "rating") RatingCard(state) else EntryCard(state)
                }
            } else {
                // 窄屏：整页可以滚，但里面那张圆角底只到内容高度（对应原版 Scroll 里那个 Column）
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(28.dp))
                            .background(hexColor(state.pageBg()))
                            .padding(start = 12.dp, end = 12.dp, top = 10.dp, bottom = 12.dp)
                    ) {
                        if (state.reviewStage == "rating") RatingCard(state) else EntryCard(state)
                    }
                }
            }
        }
    }
}

@Composable
private fun ReviewCardFrame(state: FolioState, content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .then(if (state.isWide) Modifier.width(680.dp) else Modifier.fillMaxWidth())
            .clip(RoundedCornerShape(28.dp))
            .shadowSoft(40.dp, 28.dp)
            .background(Tokens.surfaceSolid)
            .border(1.dp, hexColor("#CCFFFFFF"), RoundedCornerShape(28.dp))
            .padding(if (state.isWide) 32.dp else 22.dp)
    ) {
        content()
    }
}

@Composable
private fun ReviewHeader(state: FolioState) {
    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = state.findSubject(state.reviewItem.subjectId).name,
            fontSize = 10.sp,
            fontWeight = FontWeight.Medium,
            color = Tokens.muted
        )
        Text(
            text = state.t("reviewN", (state.reviewItem.reviewCount + 1).toString()),
            fontSize = 9.sp,
            color = Tokens.mutedSoft,
            modifier = Modifier.padding(start = 8.dp)
        )
        Spacer(Modifier.weight(1f))
        PillButton(
            text = state.t("close"),
            height = 26.dp,
            fontSize = 9.sp,
            background = Tokens.yellowSoft,
            foreground = hexColor("#6C4B00"),
            borderRadius = 13.dp,
            paddingHorizontal = 10.dp,
            onClick = { state.closeReview() }
        )
    }
}

@Composable
private fun EntryCard(state: FolioState) {
    ReviewCardFrame(state) {
        ReviewHeader(state)
        Text(
            text = state.reviewItem.title,
            fontSize = if (state.isWide) 38.sp else 30.sp,
            fontWeight = FontWeight.Bold,
            color = Tokens.ink,
            letterSpacing = (-1).sp,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 14.dp)
        )
        Text(
            text = state.t(
                "lastReview",
                state.shortDate(
                    if (state.reviewItem.lastReviewedAt > 0) state.reviewItem.lastReviewedAt
                    else state.reviewItem.createdAt
                )
            ),
            fontSize = 10.5.sp,
            color = Tokens.muted,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 8.dp)
        )
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 22.dp, bottom = 18.dp)
                .height(1.dp)
                .background(Tokens.line)
        )
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            PillButton(
                text = state.t("postponeTomorrow"),
                height = 48.dp,
                fontSize = 12.sp,
                background = Tokens.surfaceSoft,
                foreground = Tokens.inkSoft,
                borderRadius = 14.dp,
                borderColor = Tokens.line,
                modifier = Modifier.weight(1f),
                onClick = { state.postponeReview() }
            )
            PillButton(
                text = state.t("completeReview"),
                height = 48.dp,
                fontSize = 12.sp,
                background = hexColor(state.themeButton()),
                foreground = hexColor(state.themeInk()),
                borderRadius = 14.dp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.weight(1f),
                onClick = { state.startRating() }
            )
        }
    }
}

@Composable
private fun RatingCard(state: FolioState) {
    ReviewCardFrame(state) {
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            PillButton(
                text = "←",
                height = 30.dp,
                fontSize = 14.sp,
                background = Tokens.yellowSoft,
                foreground = hexColor("#6C4B00"),
                borderRadius = 15.dp,
                modifier = Modifier.width(30.dp),
                onClick = { state.backToEntry() }
            )
            Text(
                text = state.findSubject(state.reviewItem.subjectId).name,
                fontSize = 10.sp,
                fontWeight = FontWeight.Medium,
                color = Tokens.muted,
                modifier = Modifier.padding(start = 10.dp)
            )
            Text(
                text = state.t("reviewN", (state.reviewItem.reviewCount + 1).toString()),
                fontSize = 9.sp,
                color = Tokens.mutedSoft,
                modifier = Modifier.padding(start = 8.dp)
            )
            Spacer(Modifier.weight(1f))
            PillButton(
                text = state.t("close"),
                height = 26.dp,
                fontSize = 9.sp,
                background = Tokens.yellowSoft,
                foreground = hexColor("#6C4B00"),
                borderRadius = 13.dp,
                paddingHorizontal = 10.dp,
                onClick = { state.closeReview() }
            )
        }

        Text(
            text = state.reviewItem.title,
            fontSize = if (state.isWide) 38.sp else 30.sp,
            fontWeight = FontWeight.Bold,
            color = Tokens.ink,
            letterSpacing = (-1).sp,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 14.dp)
        )
        Text(
            text = state.t(
                "lastReview",
                state.shortDate(
                    if (state.reviewItem.lastReviewedAt > 0) state.reviewItem.lastReviewedAt
                    else state.reviewItem.createdAt
                )
            ),
            fontSize = 10.5.sp,
            color = Tokens.muted,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 8.dp)
        )
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 22.dp, bottom = 18.dp)
                .height(1.dp)
                .background(Tokens.line)
        )
        Text(
            text = state.t("rateTitle"),
            fontSize = if (state.isWide) 24.sp else 20.sp,
            fontWeight = FontWeight.Bold,
            color = Tokens.ink,
            modifier = Modifier.fillMaxWidth()
        )
        Text(
            text = state.t("retentionTitle") + " " +
                Math.round(state.settings.targetRetention * 100) + "%",
            fontSize = 11.sp,
            color = Tokens.muted,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 8.dp)
        )
        Text(
            text = state.t("retentionHint"),
            fontSize = 10.sp,
            color = Tokens.mutedSoft,
            lineHeight = 16.sp,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 4.dp)
        )

        GradeCards(state)
    }
}

@Composable
private fun GradeCards(state: FolioState) {
    Column(modifier = Modifier
        .fillMaxWidth()
        .padding(top = 18.dp)) {
        if (state.isWide) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                for (grade in 1..4) {
                    Box(modifier = Modifier.weight(1f)) {
                        GradeCard(state, grade)
                    }
                }
            }
        } else {
            // 2×2：两列严格等宽。用 weight 而不是 fillMaxWidth(0.48f)——
            // 后者是按「剩余空间」算的，第二张只会拿到 48%×52%，右边会明显比左边窄。
            Column {
                for (row in 0..1) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(bottom = 10.dp),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        for (col in 0..1) {
                            Box(modifier = Modifier.weight(1f)) {
                                GradeCard(state, row * 2 + col + 1)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun GradeCard(state: FolioState, grade: Int) {
    val pressed = state.pressedGrade == grade
    val scale by animateFloatAsState(
        targetValue = if (pressed) 0.96f else 1f,
        animationSpec = ease(160, Motion.decel),
        label = "gradeScale$grade"
    )
    val color = hexColor(state.gradeColor(grade))
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .clip(RoundedCornerShape(16.dp))
            .background(hexColor(state.gradeTint(grade, "14")))
            .border(1.dp, hexColor(state.gradeTint(grade, "3D")), RoundedCornerShape(16.dp))
            .padding(if (state.isWide) 14.dp else 12.dp)
            .pressable(1f) { state.finishReview(grade) }
    ) {
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(7.dp)
                    .clip(CircleShape)
                    .background(color)
            )
            Text(
                text = state.gradeLabel(grade),
                fontSize = if (state.isWide) 14.sp else 13.sp,
                fontWeight = FontWeight.Bold,
                color = color,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(start = 7.dp)
            )
        }
        Text(
            text = state.gradeMeaning(grade),
            fontSize = if (state.isWide) 9.5.sp else 9.sp,
            color = Tokens.muted,
            lineHeight = if (state.isWide) 13.sp else 12.sp,
            maxLines = 2,
            modifier = Modifier
                .fillMaxWidth()
                .height(if (state.isWide) 26.dp else 24.dp)
                .padding(top = 6.dp)
        )
        Text(
            text = state.gradeIntervalText(grade),
            fontSize = if (state.isWide) 16.sp else 15.sp,
            fontWeight = FontWeight.Bold,
            color = Tokens.ink,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 8.dp)
        )
    }
}

