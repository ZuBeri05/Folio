package com.jiesheng.folio.ui

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.AnimationSpec
import androidx.compose.animation.core.Easing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color

/**
 * ArkUI 的 `animateTo({ curve }, () => x = v)` 与 `.animation({ curve })` 的等价物。
 *
 * 每个可动画值自带「目标 + 本次曲线」：目标一变，Compose 就从当前值按新曲线补过去。
 * 中途换目标也像 ArkUI 一样从当前进度接着走，不会跳。
 */
class Anim(initial: Float) {
    private var target by mutableStateOf(initial)
    private var spec by mutableStateOf<AnimationSpec<Float>>(snap())

    /** 直接赋值：沿用上一次的曲线（对应 ArkUI 里没包 animateTo 的赋值） */
    fun set(value: Float) {
        target = value
    }

    /** 带曲线的赋值：对应 animateTo({ curve }) { this.x = value } */
    fun set(value: Float, animationSpec: AnimationSpec<Float>) {
        target = value
        spec = animationSpec
    }

    /** 立即落位，不做过渡（用于动画开始前把起点写死） */
    fun snapTo(value: Float) {
        target = value
        spec = snap()
    }

    @Composable
    fun v(label: String = "anim"): Float =
        animateFloatAsState(targetValue = target, animationSpec = spec, label = label).value
}

class AnimC(initial: Color) {
    private var target by mutableStateOf(initial)
    private var spec by mutableStateOf<AnimationSpec<Color>>(snap())

    fun set(value: Color) {
        target = value
    }

    fun set(value: Color, animationSpec: AnimationSpec<Color>) {
        target = value
        spec = animationSpec
    }

    @Composable
    fun v(label: String = "animColor"): Color =
        animateColorAsState(targetValue = target, animationSpec = spec, label = label).value
}

/** 曲线 + 时长，写法对齐 ArkUI 的 `{ duration, curve }` */
fun ease(durationMs: Int, easing: Easing): AnimationSpec<Float> =
    tween(durationMillis = durationMs, easing = easing)

fun easeColor(durationMs: Int, easing: Easing): AnimationSpec<Color> =
    tween(durationMillis = durationMs, easing = easing)
