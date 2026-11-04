package com.jiesheng.folio.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jiesheng.folio.theme.Motion
import com.jiesheng.folio.theme.Tokens

/**
 * 「记一条」表单。宽屏时作为今日页右侧的常驻面板，窄屏时是浮层里的内容，
 * 结构和尺寸与鸿蒙版 ComposerPane 一致。
 */
@Composable
fun ComposerPane(state: FolioState, showClose: Boolean, solidBacking: Boolean = false) {
    val formProgress = state.formProgress.v("formProgress")
    val dotVisible = state.dotVisible

    // 宽屏时右侧固定 400 宽、卡片自身高度自适应，放不下就在这一栏里滚
    Column(
        modifier = Modifier
            .then(if (state.isWide) Modifier.width(400.dp).fillMaxHeight() else Modifier.fillMaxWidth())
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.Start
    ) {
    Column(
        modifier = Modifier
            .then(if (state.isWide) Modifier else Modifier.fillMaxWidth())
            .graphicsLayer {
                alpha = formProgress
                translationY = (1f - formProgress) * state.mv(18f) * density
            }
            .clip(RoundedCornerShape(26.dp))
            .shadowSoft(32.dp, 26.dp)
            // 浮层里背后是整页内容，原版用 backdropBlur(22) 把它糊掉；这里换成足够实的底
            .background(if (solidBacking) Tokens.surfaceSolid else Tokens.surfaceSoft)
            .border(1.dp, hexColor("#CCFFFFFF"), RoundedCornerShape(26.dp))
            .padding(24.dp),
        horizontalAlignment = Alignment.Start
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 16.dp),
            verticalAlignment = Alignment.Top
        ) {
            Text(
                text = state.t("newEntry"),
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = Tokens.ink,
                letterSpacing = (-0.6).sp
            )
            Spacer(Modifier.weight(1f))
            Column(horizontalAlignment = Alignment.End) {
                Text(text = state.shortDate(System.currentTimeMillis()), fontSize = 7.5.sp, color = Tokens.mutedSoft)
                Text(
                    text = state.weekday(System.currentTimeMillis()),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium,
                    color = Tokens.inkSoft,
                    modifier = Modifier.padding(top = 3.dp)
                )
            }
            if (showClose) {
                PillButton(
                    text = state.t("close"),
                    height = 26.dp,
                    fontSize = 9.sp,
                    background = Tokens.yellowSoft,
                    foreground = hexColor("#6C4B00"),
                    borderRadius = 13.dp,
                    paddingHorizontal = 10.dp,
                    modifier = Modifier.padding(start = 10.dp),
                    onClick = { state.closeComposer() }
                )
            }
        }

        Text(
            text = state.t("subject"),
            fontSize = 9.sp,
            color = Tokens.muted,
            modifier = Modifier.padding(bottom = 8.dp)
        )

        WrapRow(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 18.dp)
        ) {
            state.subjects.forEach { subject ->
                val selected = state.draftSubjectId == subject.id
                val scale = animateFloatAsState(
                    targetValue = if (selected) 1.06f else 1f,
                    animationSpec = ease(220, Motion.decel),
                    label = "subjectScale"
                )
                PillButton(
                    text = subject.name,
                    height = 31.dp,
                    fontSize = 11.sp,
                    background = hexColor(if (selected) subject.color else "#D9FFFDF8"),
                    foreground = hexColor(if (selected) state.subjectInk(subject.color) else "#4B4032"),
                    borderRadius = 16.dp,
                    borderColor = hexColor(if (selected) subject.color else "#1A5E4B30"),
                    paddingHorizontal = 12.dp,
                    modifier = Modifier
                        .padding(end = 6.dp, bottom = 6.dp)
                        .graphicsLayer {
                            scaleX = scale.value
                            scaleY = scale.value
                        },
                    onClick = { state.draftSubjectId = subject.id }
                )
            }
        }

        Text(
            text = state.t("chapter"),
            fontSize = 9.sp,
            color = Tokens.muted,
            modifier = Modifier.padding(bottom = 8.dp)
        )

        TitleField(state)

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(text = state.t("reviewMode"), fontSize = 9.sp, color = Tokens.muted)
            Spacer(Modifier.weight(1f))
            ModePill(state, "fsrs", state.t("fsrsMode"))
            Box(modifier = Modifier.width(6.dp))
            ModePill(state, "fixed", state.t("fixedMode"))
        }

        // FSRS 曲线预览 / 固定天数：两块内容叠在同一格，高度随模式过渡
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(if (state.draftMode == "fixed") 52.dp else 40.dp)
                .graphicsLayer {
                    alpha = state.modeFade
                    scaleX = 0.96f + 0.04f * state.modeFade
                    scaleY = 0.96f + 0.04f * state.modeFade
                }
                .clip(RoundedCornerShape(0.dp))
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp)
                    .graphicsLayer { alpha = if (state.draftMode == "fsrs") 1f else 0f }
            ) {
                state.curveDotLabels().forEachIndexed { index, label ->
                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .graphicsLayer {
                                val visible = dotVisible > index
                                alpha = if (visible) 1f else 0f
                                translationY = if (visible) 0f else state.mv(10f) * density
                                scaleX = if (visible) 1f else 0.5f
                                scaleY = if (visible) 1f else 0.5f
                            },
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .clip(CircleShape)
                                .background(if (index == 0) Tokens.orange else Tokens.surface)
                                .border(
                                    1.5.dp,
                                    hexColor(if (index == 0) "#FF8A2A" else "#80FF9C2C"),
                                    CircleShape
                                )
                        )
                        Text(
                            text = label,
                            fontSize = 7.5.sp,
                            color = hexColor(if (index == 0) "#B16A0A" else "#B2A48F"),
                            modifier = Modifier.padding(top = 5.dp)
                        )
                    }
                }
            }
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 10.dp)
                    .graphicsLayer { alpha = if (state.draftMode == "fixed") 1f else 0f },
                verticalAlignment = Alignment.CenterVertically
            ) {
                StepButton("-") {
                    state.draftFixedDays = maxOf(1, state.draftFixedDays - 1)
                }
                Text(
                    text = state.t("fixedDaysHint", state.draftFixedDays.toString()),
                    fontSize = 10.sp,
                    color = Tokens.muted,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.weight(1f)
                )
                StepButton("+") {
                    state.draftFixedDays = minOf(90, state.draftFixedDays + 1)
                }
            }
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .height(if (state.draftMode == "fsrs") 18.dp else 0.dp)
                .graphicsLayer { alpha = if (state.draftMode == "fsrs") 1f else 0f }
        ) {
            Text(
                text = state.t("curveForecastHint"),
                fontSize = 8.5.sp,
                color = Tokens.muted,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().padding(top = 3.dp)
            )
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 14.dp)
                .clip(RoundedCornerShape(15.dp))
                .background(Tokens.yellowSoft)
                .border(1.dp, hexColor("#4DFFD687"), RoundedCornerShape(15.dp))
                .padding(13.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(horizontalAlignment = Alignment.Start) {
                Text(
                    text = state.t("remindMe"),
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Medium,
                    color = Tokens.inkSoft
                )
                Text(
                    text = state.settings.reminderTime,
                    fontSize = 12.sp,
                    color = Tokens.muted,
                    modifier = Modifier.padding(top = 3.dp)
                )
            }
            Spacer(Modifier.weight(1f))
            Switch(
                checked = state.settings.reminderEnabled,
                onCheckedChange = { state.updateReminderEnabled(it) },
                colors = SwitchDefaults.colors(
                    checkedThumbColor = androidx.compose.ui.graphics.Color.White,
                    checkedTrackColor = hexColor(state.themeButton())
                )
            )
        }

        PillButton(
            text = state.t("save"),
            height = 50.dp,
            fontSize = 13.sp,
            background = hexColor(state.themeButton()),
            foreground = hexColor(state.themeInk()),
            borderRadius = 15.dp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 14.dp),
            onClick = { state.addItem() }
        )

        Text(
            text = state.t("localOnly"),
            fontSize = 8.5.sp,
            color = Tokens.mutedSoft,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 10.dp)
        )
    }
}
}

@Composable
private fun ModePill(state: FolioState, mode: String, label: String) {
    val selected = state.draftMode == mode
    PillButton(
        text = label,
        height = 28.dp,
        fontSize = 9.5.sp,
        background = hexColor(if (selected) state.themeButton() else "#D9FFFDF8"),
        foreground = hexColor(if (selected) state.themeInk() else "#4B4032"),
        borderRadius = 14.dp,
        borderColor = hexColor(if (selected) state.themeButton() else "#1A5E4B30"),
        paddingHorizontal = 12.dp,
        onClick = { state.switchMode(mode) }
    )
}

@Composable
private fun StepButton(label: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(width = 34.dp, height = 30.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(Tokens.surface)
            .border(1.dp, Tokens.line, RoundedCornerShape(10.dp))
            .pressable(0.9f, onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Text(text = label, fontSize = 18.sp, fontWeight = FontWeight.Medium, color = Tokens.inkSoft)
    }
}

@Composable
private fun TitleField(state: FolioState) {
    var focused by remember { mutableStateOf(false) }
    val borderColor by androidx.compose.animation.animateColorAsState(
        targetValue = if (focused) hexColor("#C9A24A") else hexColor("#B3FFFFFF"),
        animationSpec = easeColor(180, Motion.decel),
        label = "titleBorder"
    )

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(50.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(Tokens.surface)
            .border(1.dp, borderColor, RoundedCornerShape(14.dp))
            .padding(horizontal = 14.dp),
        contentAlignment = Alignment.CenterStart
    ) {
        if (state.draftTitle.isEmpty()) {
            Text(text = state.t("titlePlaceholder"), fontSize = 20.sp, color = Tokens.mutedSoft)
        }
        BasicTextField(
            value = state.draftTitle,
            onValueChange = { state.draftTitle = it },
            singleLine = true,
            textStyle = TextStyle(fontSize = 20.sp, color = Tokens.ink),
            cursorBrush = SolidColor(Tokens.orange),
            modifier = Modifier
                .fillMaxWidth()
                .onFocusChanged {
                    focused = it.isFocused
                    state.titleFocused = it.isFocused
                }
        )
    }
}

/** 自动换行的横排（ArkUI 的 Flex wrap） */
@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
fun WrapRow(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    androidx.compose.foundation.layout.FlowRow(
        modifier = modifier,
        horizontalArrangement = Arrangement.Start,
        verticalArrangement = Arrangement.Top
    ) {
        content()
    }
}

@Composable
fun ComposerOverlay(state: FolioState) {
    val dim = state.composerDim.v("composerDim")
    val scale = state.composerScale.v("composerScale")
    val shift = state.composerShift.v("composerShift")
    val opacity = state.composerOpacity.v("composerOpacity")

    Box(modifier = Modifier.fillMaxSize()) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer { alpha = dim }
                .background(Tokens.dim)
        )
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(0.92f)
                    .graphicsLayer {
                        scaleX = scale
                        scaleY = scale
                        translationY = shift * density
                        alpha = opacity
                    }
                    .verticalScroll(rememberScrollState())
            ) {
                ComposerPane(state, showClose = true, solidBacking = true)
            }
        }
    }
}
