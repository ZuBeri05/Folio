package com.jiesheng.folio.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jiesheng.folio.R
import com.jiesheng.folio.theme.Motion
import com.jiesheng.folio.theme.Tokens

internal val navIconsOn = listOf(
    R.drawable.ic_banana_on,
    R.drawable.ic_lemon_on,
    R.drawable.ic_carrot_on,
    R.drawable.ic_watermelon_on
)

internal val navIconsOff = listOf(
    R.drawable.ic_banana_off,
    R.drawable.ic_lemon_off,
    R.drawable.ic_carrot_off,
    R.drawable.ic_watermelon_off
)

/**
 * 根页面：一片底色 + 全部浮层，和鸿蒙版 Index.ets 的 build() 结构一致。
 */
@Composable
fun FolioApp(state: FolioState) {
    LaunchedEffect(Unit) {
        state.load()
    }

    // 对应鸿蒙版 onAreaChange：拿真实画布尺寸算分栏，而不是读配置（配置在窗口变化那一帧还是旧的）
    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .background(hexColor(state.pageBg()))
    ) {
        val widthDp = maxWidth.value
        val heightDp = maxHeight.value
        LaunchedEffect(widthDp, heightDp) {
            state.vpWidth = widthDp
            state.vpHeight = heightDp
            // 左右分栏只在「够宽且确实是横向」时启用
            state.isWide = widthDp >= 840f && widthDp > heightDp * 1.05f
            state.isTablet = widthDp >= 700f
        }
        if (state.isWide) {
            TabletLayout(state)
        } else {
            PhoneLayout(state)
        }
        if (state.showReview) ReviewOverlay(state)
        if (state.showComposer && !state.isWide) ComposerOverlay(state)
        if (state.showItemActions) ItemActionsOverlay(state)
        if (state.showConfirm) ConfirmOverlay(state)
        if (state.showTimePicker) TimePickerOverlay(state)
        if (state.showFocusClock) FocusClockOverlay(state)
        if (state.showFocusSummary) FocusSummaryOverlay(state)
        ToastLayer(state)
    }
}

@Composable
private fun PhoneLayout(state: FolioState) {
    val insets = WindowInsets.systemBars.asPaddingValues()
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(top = insets.calculateTopPadding(), bottom = insets.calculateBottomPadding())
    ) {
        TopBar(state, showAdd = true)
        Box(modifier = Modifier.weight(1f).fillMaxWidth()) {
            if (state.tab == 0) {
                TodayPane(state)
            } else {
                OtherPage(state)
            }
        }
        if (state.focusRunning && state.tab != 0) {
            FocusMiniBar(state)
        }
        Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            BottomNav(state)
        }
    }
}

@Composable
private fun TabletLayout(state: FolioState) {
    val insets = WindowInsets.systemBars.asPaddingValues()
    Row(
        modifier = Modifier
            .fillMaxSize()
            .padding(top = insets.calculateTopPadding(), bottom = insets.calculateBottomPadding())
    ) {
        Rail(state)
        Column(modifier = Modifier.weight(1f).fillMaxHeight()) {
            TopBar(state, showAdd = false)
            Box(modifier = Modifier.weight(1f).fillMaxWidth()) {
                if (state.tab == 0) {
                    Row(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(start = 44.dp, end = 44.dp, top = 12.dp, bottom = 32.dp),
                        verticalAlignment = Alignment.Top
                    ) {
                        // 左栏吃掉剩余宽度，右栏固定 400：和原版 layoutWeight(1) + width(400) 一致
                        Box(modifier = Modifier.weight(1f).fillMaxHeight()) {
                            TodayPane(state)
                        }
                        ComposerPane(state, showClose = false)
                    }
                } else {
                    OtherPage(state)
                }
            }
            if (state.focusRunning && state.tab != 0) {
                FocusMiniBar(state)
            }
        }
    }
}

@Composable
private fun Rail(state: FolioState) {
    Column(
        modifier = Modifier
            .width(124.dp)
            .fillMaxHeight()
            .background(hexColor(state.pageBg())),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Column(
            modifier = Modifier
                .width(112.dp)
                .padding(top = 56.dp),
            verticalArrangement = Arrangement.spacedBy(34.dp)
        ) {
            for (index in 0..3) {
                RailNavItem(state, index)
            }
        }
        Spacer(Modifier.weight(1f))
        Text(
            text = "v1.1.2",
            fontSize = 7.sp,
            color = Tokens.mutedSoft,
            modifier = Modifier.padding(bottom = 20.dp)
        )
    }
}

@Composable
private fun RailNavItem(state: FolioState, index: Int) {
    val active = state.tab == index
    Column(
        modifier = Modifier
            .width(112.dp)
            .height(88.dp)
            .pressable(0.94f) { state.switchTab(index) },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Image(
            painter = painterResource(if (active) navIconsOn[index] else navIconsOff[index]),
            contentDescription = null,
            modifier = Modifier.size(30.dp),
            contentScale = ContentScale.Fit
        )
        Text(
            text = state.navLabel(index),
            fontSize = 11.5.sp,
            fontWeight = if (active) FontWeight.Bold else FontWeight.Medium,
            color = if (active) hexColor("#6C4B00") else Tokens.mutedSoft,
            modifier = Modifier.padding(top = 4.dp)
        )
    }
}

@Composable
private fun TopBar(state: FolioState, showAdd: Boolean) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(72.dp)
            .background(hexColor(state.pageBg()))
            .padding(horizontal = if (state.isWide) 44.dp else 20.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(text = state.todayLabel, fontSize = 12.sp, color = Tokens.muted)
        Spacer(Modifier.weight(1f))
        Box(
            modifier = Modifier
                .padding(end = if (showAdd) 8.dp else 0.dp)
                .size(34.dp)
                .clip(CircleShape)
                .background(hexColor(if (state.focusRunning) "#FFE3D8" else "#FFEDE6"))
                .border(
                    width = 1.dp,
                    color = hexColor(if (state.focusRunning) "#FF6542" else "#40FF6542"),
                    shape = CircleShape
                )
                .pressable(0.9f) { state.openFocusClock() },
            contentAlignment = Alignment.Center
        ) {
            Image(
                painter = painterResource(R.drawable.tomato),
                contentDescription = null,
                modifier = Modifier.size(20.dp)
            )
        }
        if (showAdd) {
            PillButton(
                text = state.t("newEntry"),
                height = 34.dp,
                fontSize = 12.sp,
                background = hexColor(state.themeButton()),
                foreground = hexColor(state.themeInk()),
                fontWeight = FontWeight.Medium,
                paddingHorizontal = 14.dp,
                modifier = Modifier.padding(start = 8.dp),
                onClick = { state.openComposer() }
            )
        }
    }
}

@Composable
private fun BottomNav(state: FolioState) {
    Row(
        modifier = Modifier
            .fillMaxWidth(0.92f)
            .padding(bottom = 18.dp)
            .height(60.dp)
            .clip(RoundedCornerShape(30.dp))
            .background(Tokens.surface)
            .border(1.dp, hexColor("#CCFFFFFF"), RoundedCornerShape(30.dp)),
        verticalAlignment = Alignment.CenterVertically
    ) {
        for (index in 0..3) {
            val active = state.tab == index
            val iconScale = animateFloatAsState(
                targetValue = if (active) 1.08f else 1f,
                animationSpec = Motion.snap(),
                label = "navIcon$index"
            )
            Column(
                modifier = Modifier
                    .weight(1f)
                    .height(62.dp)
                    .pressable(0.92f) { state.switchTab(index) },
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                Image(
                    painter = painterResource(if (active) navIconsOn[index] else navIconsOff[index]),
                    contentDescription = null,
                    modifier = Modifier
                        .size(22.dp)
                        .graphicsLayer {
                            scaleX = iconScale.value
                            scaleY = iconScale.value
                        },
                    contentScale = ContentScale.Fit
                )
                Text(
                    text = state.navLabel(index),
                    fontSize = 8.sp,
                    color = if (active) hexColor("#6C4B00") else Tokens.mutedSoft,
                    modifier = Modifier.padding(top = 3.dp)
                )
            }
        }
    }
}

@Composable
private fun OtherPage(state: FolioState) {
    when (state.tab) {
        1 -> RecordsPage(state)
        2 -> CalendarPage(state)
        else -> SettingsPage(state)
    }
}

@Composable
private fun ToastLayer(state: FolioState) {
    val text = state.toastText
    if (text != null) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(bottom = 120.dp),
            contentAlignment = Alignment.BottomCenter
        ) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(14.dp))
                    .background(Color(0xE62C251D))
                    .padding(horizontal = 18.dp, vertical = 12.dp)
            ) {
                Text(text = text, fontSize = 12.sp, color = Color.White)
            }
        }
    }
}
