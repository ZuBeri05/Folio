package com.jiesheng.folio.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jiesheng.folio.theme.Motion

/**
 * 一枚胶囊按钮。鸿蒙版里所有 Button 都是「定高 + 定字号 + 圆角 + 可选描边」，
 * 这里用 Box 自己画，避免 Material Button 的最小高度和阴影把排版顶歪。
 */
@Composable
fun PillButton(
    text: String,
    height: Dp,
    fontSize: TextUnit,
    background: Color,
    foreground: Color,
    modifier: Modifier = Modifier,
    borderRadius: Dp = height / 2,
    borderColor: Color? = null,
    borderWidth: Dp = 1.dp,
    paddingHorizontal: Dp = 0.dp,
    fontWeight: FontWeight = FontWeight.Normal,
    pressScale: Float = 0.94f,
    onClick: () -> Unit
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed) pressScale else 1f,
        animationSpec = Motion.snap(),
        label = "pressScale"
    )
    Box(
        modifier = modifier
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .height(height)
            .clip(RoundedCornerShape(borderRadius))
            .background(background)
            .then(
                if (borderColor != null) {
                    Modifier.border(BorderStroke(borderWidth, borderColor), RoundedCornerShape(borderRadius))
                } else {
                    Modifier
                }
            )
            .clickable(
                interactionSource = interaction,
                indication = null,
                onClick = onClick
            )
            .padding(PaddingValues(horizontal = paddingHorizontal)),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = text,
            fontSize = fontSize,
            fontWeight = fontWeight,
            color = foreground,
            maxLines = 1
        )
    }
}

/** 卡片：底色 + 圆角 + 1px 描边 + 柔和投影，对应 ArkUI 的 surface / surfaceSoft 卡 */
@Composable
fun FolioCard(
    modifier: Modifier = Modifier,
    background: Color = com.jiesheng.folio.theme.Tokens.surfaceSoft,
    borderRadius: Dp = 22.dp,
    borderColor: Color = Color(0xB3FFFFFF),
    borderWidth: Dp = 1.dp,
    shadowElevation: Dp = 0.dp,
    content: @Composable () -> Unit
) {
    Box(
        modifier = modifier
            .then(
                if (shadowElevation > 0.dp) {
                    Modifier.shadowSoft(shadowElevation, borderRadius)
                } else {
                    Modifier
                }
            )
            .clip(RoundedCornerShape(borderRadius))
            .background(background)
            .then(
                if (borderWidth > 0.dp) {
                    Modifier.border(borderWidth, borderColor, RoundedCornerShape(borderRadius))
                } else {
                    Modifier
                }
            )
    ) {
        content()
    }
}

/** 点击缩放反馈（ArkUI 的 clickEffect({ level: LIGHT, scale })），支持长按 */
@OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
fun Modifier.pressable(
    scale: Float = 0.96f,
    onLongPress: (() -> Unit)? = null,
    onClick: () -> Unit
): Modifier = composed {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val value by animateFloatAsState(
        targetValue = if (pressed) scale else 1f,
        animationSpec = Motion.snap(),
        label = "press"
    )
    this
        .graphicsLayer {
            scaleX = value
            scaleY = value
        }
        .combinedClickable(
            interactionSource = interaction,
            indication = null,
            onClick = onClick,
            onLongClick = onLongPress
        )
}

/**
 * 柔和投影：对应 ArkUI 的 shadow({ radius, color, offsetX, offsetY })。
 *
 * 不用 graphicsLayer 的 shadowElevation —— 那一套在软件渲染下会给整层加一个
 * 半透明离屏缓冲，卡片背后会透出下面页面的字。这里改成自己画几层渐渐变淡的圆角底：
 * 观感是同样的「贴纸浮起来」，但完全不碰渲染层。
 */
internal fun Modifier.shadowSoft(elevation: Dp, radius: Dp): Modifier = this.drawBehind {
    val spread = elevation.toPx() * 0.45f
    val rings = 8
    val down = elevation.toPx() * 0.1f
    for (i in rings downTo 1) {
        val t = i.toFloat() / rings
        val outset = spread * t
        // 只用描边，不填充：卡片本身是半透明的，填色会从背面透出来变成灰块
        drawRoundRect(
            color = Color(0x0D2C251D),
            topLeft = androidx.compose.ui.geometry.Offset(-outset, -outset + down),
            size = androidx.compose.ui.geometry.Size(
                size.width + outset * 2f,
                size.height + outset * 2f
            ),
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(radius.toPx() + outset),
            style = androidx.compose.ui.graphics.drawscope.Stroke(width = 2.dp.toPx())
        )
    }
}

val MicroLabel = 8.5.sp
