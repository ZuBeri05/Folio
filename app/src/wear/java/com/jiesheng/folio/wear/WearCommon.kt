package com.jiesheng.folio.wear

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.material3.Text
import com.jiesheng.folio.theme.Motion

/**
 * 手表上的胶囊按钮：和手机版是同一套长相（定高、定字号、圆角、可选描边），
 * 只是尺寸按手腕收小。按压反馈仍然走 `Motion.snap()`。
 */
@Composable
fun WearPill(
    text: String,
    height: Dp,
    fontSize: TextUnit,
    background: Color,
    foreground: Color,
    modifier: Modifier = Modifier,
    borderRadius: Dp = height / 2,
    borderColor: Color? = null,
    paddingHorizontal: Dp = 0.dp,
    fontWeight: FontWeight = FontWeight.Normal,
    maxLines: Int = 1,
    pressScale: Float = 0.94f,
    onClick: () -> Unit
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed) pressScale else 1f,
        animationSpec = Motion.snap(),
        label = "wearPress"
    )
    Box(
        modifier = modifier
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .height(height)
            .background(background, RoundedCornerShape(borderRadius))
            .then(
                if (borderColor != null) {
                    Modifier.border(1.dp, borderColor, RoundedCornerShape(borderRadius))
                } else {
                    Modifier
                }
            )
            .clickable(interactionSource = interaction, indication = null, onClick = onClick)
            .padding(PaddingValues(horizontal = paddingHorizontal)),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = text,
            fontSize = fontSize,
            fontWeight = fontWeight,
            color = foreground,
            maxLines = maxLines,
            textAlign = TextAlign.Center
        )
    }
}

/** 表盘上一块卡片：和手机同色同圆角，只是内边距更紧 */
@Composable
fun WearCard(
    modifier: Modifier = Modifier,
    background: Color = com.jiesheng.folio.theme.Tokens.surface,
    borderRadius: Dp = 20.dp,
    content: @Composable () -> Unit
) {
    Box(
        modifier = modifier
            .background(background, RoundedCornerShape(borderRadius))
            .border(1.dp, Color(0xB3FFFFFF), RoundedCornerShape(borderRadius))
    ) {
        content()
    }
}

/** 圆形屏边缘留白：内容别贴边被表壳切掉 */
val WatchInset = 10.dp

val WatchTitle = 15.sp
val WatchBody = 11.sp
val WatchMicro = 9.sp
