package com.jiesheng.folio.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jiesheng.folio.services.I18n
import com.jiesheng.folio.theme.Motion
import com.jiesheng.folio.theme.Tokens

/**
 * 设置页：5 张卡轮流左 / 下 / 右 / 左 / 下 入场，逐张错开 80ms。
 */
@Composable
fun SettingsPage(state: FolioState) {
    val pageOpacity = state.pageOpacity.v("settingsPageOpacity")
    val pageShift = state.pageShift.v("settingsPageShift")

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
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(
                    start = if (state.isWide) 52.dp else 20.dp,
                    end = if (state.isWide) 52.dp else 20.dp
                ),
            horizontalAlignment = Alignment.Start
        ) {
            Text(
                text = state.t("settingsTitle"),
                fontSize = if (state.isWide) 44.sp else 32.sp,
                fontWeight = FontWeight.Bold,
                color = Tokens.ink,
                modifier = Modifier.padding(top = 24.dp, bottom = 18.dp)
            )
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = if (state.isWide) 52.dp else 20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            ReminderCard(state, state.setIn[0])
            RetentionCard(state, state.setIn[1])
            SubjectCard(state, state.setIn[2])
            PaletteCard(state, state.setIn[3])
            LanguageCard(state, state.setIn[4])
            Spacer(Modifier.height(24.dp))
        }
    }
}

/** 卡片入场：左 / 下 / 右 三种方向，和原版 translate + opacity 公式一致 */
@Composable
private fun EntryCard(
    progress: Float,
    direction: Int, // -1 左，0 下，1 右
    state: FolioState,
    content: @Composable () -> Unit
) {
    val shift = when (direction) {
        -1 -> state.mv(72f)
        1 -> state.mv(72f)
        else -> state.mv(44f)
    }
    Box(
        modifier = Modifier.graphicsLayer {
            if (direction == 0) {
                translationY = (1f - progress) * shift * density
            } else {
                translationX = (1f - progress) * shift * (if (direction < 0) -1f else 1f) * density
            }
            alpha = 0.3f + 0.7f * minOf(1f, progress * 1.8f)
        }
    ) {
        content()
    }
}

@Composable
private fun SettingsCard(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .background(Tokens.surfaceSoft)
            .border(1.dp, hexColor("#B3FFFFFF"), RoundedCornerShape(22.dp))
            .padding(18.dp),
        horizontalAlignment = Alignment.Start
    ) {
        content()
    }
}

@Composable
private fun ReminderCard(state: FolioState, anim: Anim) {
    val progress = anim.v("setIn0")
    EntryCard(progress, -1, state) {
        SettingsCard {
            Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Column(horizontalAlignment = Alignment.Start) {
                    Text(
                        text = state.t("remindMe"),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = Tokens.ink
                    )
                    Text(
                        text = state.t("reminderSub"),
                        fontSize = 9.5.sp,
                        color = Tokens.muted,
                        modifier = Modifier.padding(top = 3.dp)
                    )
                }
                Spacer(Modifier.weight(1f))
                Switch(
                    checked = state.settings.reminderEnabled,
                    onCheckedChange = { state.updateReminderEnabled(it) },
                    colors = SwitchDefaults.colors(
                        checkedThumbColor = Color.White,
                        checkedTrackColor = hexColor(state.themeButton())
                    )
                )
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(text = state.t("reminderTime"), fontSize = 11.sp, color = Tokens.muted)
                Spacer(Modifier.weight(1f))
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(10.dp))
                        .background(Tokens.surface)
                        .pressable(0.94f) { state.openTimePicker() }
                        .padding(start = 14.dp, end = 12.dp, top = 8.dp, bottom = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(5.dp)
                ) {
                    Text(
                        text = state.settings.reminderTime,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Medium,
                        color = if (state.settings.reminderEnabled) Tokens.inkSoft else Tokens.mutedSoft
                    )
                    Text(text = "▾", fontSize = 9.sp, color = Tokens.mutedSoft)
                }
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(text = state.t("reminderMethod"), fontSize = 10.sp, color = Tokens.muted)
                Spacer(Modifier.weight(1f))
                Text(
                    text = when (state.reminderMode) {
                        "calendar" -> state.t("systemCalendar")
                        "off" -> state.t("off")
                        else -> state.t("unscheduled")
                    },
                    fontSize = 10.sp,
                    color = if (state.reminderMode == "calendar") hexColor("#6E8C4D") else Tokens.mutedSoft
                )
                Text(
                    text = "  ·  " + state.t("schedules", maxOf(0, state.reminderCount).toString()),
                    fontSize = 9.sp,
                    color = Tokens.mutedSoft
                )
            }

            if (state.reminderError.isNotEmpty()) {
                Text(
                    text = state.reminderError,
                    fontSize = 8.5.sp,
                    color = hexColor("#C7422C"),
                    maxLines = 3,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 6.dp)
                )
            }
        }
    }
}

@Composable
private fun RetentionCard(state: FolioState, anim: Anim) {
    val progress = anim.v("setIn1")
    EntryCard(progress, 0, state) {
        SettingsCard {
            Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Column(modifier = Modifier.weight(1f), horizontalAlignment = Alignment.Start) {
                    Text(
                        text = state.t("retentionTitle"),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = Tokens.ink
                    )
                    Text(
                        text = state.t("retentionHint"),
                        fontSize = 9.5.sp,
                        color = Tokens.muted,
                        modifier = Modifier.padding(top = 3.dp)
                    )
                }
                Text(
                    text = Math.round(state.settings.targetRetention * 100).toString() + "%",
                    fontSize = 24.sp,
                    fontWeight = FontWeight.Bold,
                    color = hexColor(state.themeAccent(state.settings.themeIndex)),
                    modifier = Modifier.padding(start = 12.dp)
                )
                PillButton(
                    text = if (state.retentionUnlocked) state.t("retentionDone") else state.t("retentionAdjust"),
                    height = 26.dp,
                    fontSize = 9.sp,
                    background = hexColor(state.themeButton()),
                    foreground = hexColor(state.themeInk()),
                    borderRadius = 13.dp,
                    paddingHorizontal = 10.dp,
                    modifier = Modifier.padding(start = 8.dp),
                    onClick = { state.retentionUnlocked = !state.retentionUnlocked }
                )
            }

            // 自己画滑杆：Material 的 Slider 拇指和轨道跟原版差太远
            RetentionSlider(state)

            Row(modifier = Modifier.fillMaxWidth()) {
                Text(text = "80%", fontSize = 9.sp, color = Tokens.mutedSoft)
                Spacer(Modifier.weight(1f))
                Text(text = "95%", fontSize = 9.sp, color = Tokens.mutedSoft)
            }

            Text(
                text = state.t("retentionExplain"),
                fontSize = if (state.isWide) 10.5.sp else 10.sp,
                lineHeight = if (state.isWide) 16.sp else 15.sp,
                color = Tokens.inkSoft,
                modifier = Modifier.padding(top = 10.dp)
            )

            Divider()
            Text(
                text = state.t("maxIntervalTitle"),
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                color = Tokens.ink
            )
            WrapRow(modifier = Modifier.padding(top = 10.dp)) {
                listOf(90, 180, 365, 0).forEach { value ->
                    ChoicePill(
                        text = if (value == 0) state.t("unlimited") else state.t("daysShort", value.toString()),
                        selected = state.settings.maxIntervalDays == value,
                        onClick = { state.updateMaxInterval(value) }
                    )
                }
            }

            Divider()
            Text(
                text = state.t("focusSettingTitle"),
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                color = Tokens.ink
            )
            WrapRow(modifier = Modifier.padding(top = 10.dp)) {
                listOf(15, 20, 25, 30, 45, 60).forEach { value ->
                    ChoicePill(
                        text = state.t("minutesShort", value.toString()),
                        selected = state.settings.focusMinutes == value,
                        onClick = { state.updateFocusMinutes(value) }
                    )
                }
            }
        }
    }
}

@Composable
private fun RetentionSlider(state: FolioState) {
    val value = Math.round(state.settings.targetRetention * 100).toFloat()
    val fraction = ((value - 80f) / 15f).coerceIn(0f, 1f)
    val enabled = state.retentionUnlocked
    var widthPx by remember { mutableStateOf(1f) }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 12.dp)
            .graphicsLayer { alpha = if (enabled) 1f else 0.35f }
            .onSizeChanged { widthPx = it.width.toFloat().coerceAtLeast(1f) }
            .pointerInput(enabled) {
                if (!enabled) return@pointerInput
                detectDragGestures(
                    onDragStart = { offset -> applySlider(state, offset.x, widthPx) },
                    onDrag = { change, _ -> applySlider(state, change.position.x, widthPx) },
                    onDragEnd = { state.persist() },
                    onDragCancel = { state.persist() }
                )
            }
            .pointerInput(enabled) {
                if (!enabled) return@pointerInput
                detectTapGestures(
                    onTap = { offset ->
                        applySlider(state, offset.x, widthPx)
                        state.persist()
                    }
                )
            }
            .height(34.dp),
        contentAlignment = Alignment.CenterStart
    ) {
        Canvas(modifier = Modifier.fillMaxWidth().height(34.dp)) {
            val trackHeight = 6.dp.toPx()
            val radius = trackHeight / 2f
            val centerY = size.height / 2f
            val usable = size.width - trackHeight
            val fillWidth = usable * fraction
            drawRoundRect(
                color = hexColor("#E6DCC8"),
                topLeft = Offset(radius, centerY - radius),
                size = Size(size.width - trackHeight, trackHeight),
                cornerRadius = CornerRadius(radius)
            )
            drawRoundRect(
                color = hexColor(state.themeButton()),
                topLeft = Offset(radius, centerY - radius),
                size = Size(fillWidth, trackHeight),
                cornerRadius = CornerRadius(radius)
            )
            drawCircle(
                color = hexColor(state.themeButton()),
                radius = 9.dp.toPx(),
                center = Offset(radius + fillWidth, centerY)
            )
        }
    }
}

private fun applySlider(state: FolioState, x: Float, widthPx: Float) {
    val thumb = 9f
    val fraction = ((x - thumb) / (widthPx - thumb * 2f)).coerceIn(0f, 1f)
    val percent = Math.round(80f + fraction * 15f)
    state.updateRetention(percent.toInt())
}

@Composable
private fun Divider() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 16.dp, bottom = 14.dp)
            .height(1.dp)
            .background(Tokens.line)
    )
}

@Composable
private fun ChoicePill(text: String, selected: Boolean, onClick: () -> Unit) {
    val background by androidx.compose.animation.animateColorAsState(
        targetValue = if (selected) Tokens.yellowSoft else Tokens.surface,
        animationSpec = easeColor(Motion.quick, Motion.standard),
        label = "choice"
    )
    Text(
        text = text,
        fontSize = 10.sp,
        fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
        color = hexColor(if (selected) "#6C4B00" else "#8D7F6C"),
        modifier = Modifier
            .padding(end = 6.dp, bottom = 6.dp)
            .clip(RoundedCornerShape(11.dp))
            .background(background)
            .padding(horizontal = 10.dp, vertical = 5.dp)
            .pressable(0.92f, onClick = onClick)
    )
}

@Composable
private fun SubjectCard(state: FolioState, anim: Anim) {
    val progress = anim.v("setIn2")
    EntryCard(progress, 1, state) {
        SettingsCard {
            Text(
                text = state.t("subject"),
                fontSize = 11.sp,
                fontWeight = FontWeight.Medium,
                color = Tokens.muted,
                modifier = Modifier.padding(bottom = 10.dp)
            )

            WrapRow(modifier = Modifier.fillMaxWidth()) {
                state.subjects.forEach { subject ->
                    Row(
                        modifier = Modifier
                            .padding(end = 6.dp, bottom = 6.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(Tokens.surface)
                            .border(1.dp, hexColor("#B3FFFFFF"), RoundedCornerShape(12.dp))
                            .padding(horizontal = 10.dp, vertical = 7.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(7.dp)
                                .clip(CircleShape)
                                .background(hexColor(subject.color))
                        )
                        Text(
                            text = subject.name,
                            fontSize = 10.sp,
                            color = Tokens.inkSoft,
                            modifier = Modifier.padding(start = 6.dp)
                        )
                        Text(
                            text = "×",
                            fontSize = 11.sp,
                            color = Tokens.mutedSoft,
                            modifier = Modifier
                                .padding(start = 6.dp)
                                .pressable(0.85f) { state.confirmDeleteSubject(subject) }
                        )
                    }
                }
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(36.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(Tokens.surface)
                        .border(1.dp, hexColor("#E6DCC8"), RoundedCornerShape(10.dp))
                        .padding(horizontal = 12.dp),
                    contentAlignment = Alignment.CenterStart
                ) {
                    BasicTextField(
                        value = state.newSubjectName,
                        onValueChange = { state.newSubjectName = it },
                        singleLine = true,
                        textStyle = TextStyle(fontSize = 12.sp, color = Tokens.ink),
                        modifier = Modifier.fillMaxWidth()
                    )
                }
                PillButton(
                    text = state.t("addSubject"),
                    height = 36.dp,
                    fontSize = 11.sp,
                    background = hexColor(state.themeButton()),
                    foreground = hexColor(state.themeInk()),
                    fontWeight = FontWeight.Medium,
                    borderRadius = 10.dp,
                    paddingHorizontal = 16.dp,
                    modifier = Modifier.padding(start = 8.dp),
                    onClick = { state.addSubject() }
                )
            }
        }
    }
}

@Composable
private fun PaletteCard(state: FolioState, anim: Anim) {
    val progress = anim.v("setIn3")
    EntryCard(progress, -1, state) {
        SettingsCard {
            Text(
                text = state.t("palette"),
                fontSize = 11.sp,
                fontWeight = FontWeight.Medium,
                color = Tokens.muted
            )
            WrapRow(modifier = Modifier.padding(top = 10.dp)) {
                listOf("奶油", "雾蓝", "暖砂", "鼠尾草").forEachIndexed { index, name ->
                    val selected = state.settings.themeIndex == index
                    val scale = animateFloatAsState(
                        targetValue = if (selected) 1.02f else 1f,
                        animationSpec = ease(240, Motion.decel),
                        label = "palette$index"
                    )
                    Row(
                        modifier = Modifier
                            .padding(end = 8.dp, bottom = 8.dp)
                            .graphicsLayer {
                                scaleX = scale.value
                                scaleY = scale.value
                            }
                            .clip(RoundedCornerShape(12.dp))
                            .background(Tokens.surface)
                            .border(
                                if (selected) 2.dp else 1.dp,
                                hexColor(if (selected) state.themeAccent(index) else "#E6DCC8"),
                                RoundedCornerShape(12.dp)
                            )
                            .pressable(0.96f) { state.updateTheme(index) }
                            .padding(horizontal = 10.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(26.dp)
                                .clip(RoundedCornerShape(8.dp))
                                .background(hexColor(state.themeAccent(index)))
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                            state.pageColors(index).forEach { color ->
                                Box(
                                    modifier = Modifier
                                        .size(13.dp)
                                        .clip(CircleShape)
                                        .background(hexColor(color))
                                        .border(1.dp, hexColor("#44000000"), CircleShape)
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun LanguageCard(state: FolioState, anim: Anim) {
    val progress = anim.v("setIn4")
    EntryCard(progress, 0, state) {
        SettingsCard {
            Text(
                text = state.t("language"),
                fontSize = 11.sp,
                fontWeight = FontWeight.Medium,
                color = Tokens.muted,
                modifier = Modifier.padding(bottom = 10.dp)
            )
            WrapRow(modifier = Modifier.fillMaxWidth()) {
                I18n.languages.forEach { option ->
                    val selected = state.settings.language == option.code
                    val scale = animateFloatAsState(
                        targetValue = if (selected) 1.04f else 1f,
                        animationSpec = ease(180, Motion.decel),
                        label = "lang${option.code}"
                    )
                    PillButton(
                        text = option.name,
                        height = 30.dp,
                        fontSize = 10.sp,
                        background = hexColor(if (selected) state.themeButton() else "#D9FFFDF8"),
                        foreground = hexColor(if (selected) state.themeInk() else "#4B4032"),
                        borderRadius = 15.dp,
                        borderColor = hexColor(if (selected) state.themeButton() else "#E6DCC8"),
                        paddingHorizontal = 12.dp,
                        modifier = Modifier
                            .padding(end = 6.dp, bottom = 6.dp)
                            .graphicsLayer {
                                scaleX = scale.value
                                scaleY = scale.value
                            },
                        onClick = { state.setLanguage(option.code) }
                    )
                }
            }
        }
    }
}
