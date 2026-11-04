package com.jiesheng.folio.theme

import androidx.compose.animation.core.AnimationSpec
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.Easing
import androidx.compose.animation.core.spring
import androidx.compose.ui.graphics.Color

/**
 * 颜色 token。与鸿蒙版 theme/Tokens.ets 一一对应，改名不改值。
 */
object Tokens {
    val bg = Color(0xFFF7F2E4)
    val surface = Color(0xD9FFFDF8)
    /** 浮层卡片专用：原版靠 backdropBlur 压住背后的页面，Compose 没有，直接用实色 */
    val surfaceSolid = Color(0xFFFFFDF8)
    val surfaceSoft = Color(0xB3FFFDF8)
    val ink = Color(0xFF2C251D)
    val inkSoft = Color(0xFF4B4032)
    val muted = Color(0xFF8D7F6C)
    val mutedSoft = Color(0xFFB2A48F)
    val line = Color(0x1A5E4B30)
    val lineStrong = Color(0x2B5E4B30)
    val yellow = Color(0xFFFFC531)
    val yellowSoft = Color(0xFFFFF3C9)
    val orange = Color(0xFFFF8A2A)
    val coral = Color(0xFFFF6542)
    val blue = Color(0xFF7E9FB5)
    val pink = Color(0xFFD98F87)
    val shadow = Color(0x14000000)
    val dim = Color(0x660B0806)
    val white = Color(0xFFFFFFFF)
}

/**
 * 动效 token。规则和鸿蒙版一致：
 * 1. 时长只用 5 个刻度；
 * 2. 位移幅度一律走 travel()，按屏宽缩放；
 * 3. 弹簧是物理曲线，不配 duration。
 */
object Motion {
    /** 微反馈：按下、勾选 */
    const val instant = 110

    /** 轻量状态切换：图标、小控件 */
    const val quick = 170

    /** 常规：卡片、面板 */
    const val base = 260

    /** 慢速：整块入场 */
    const val slow = 380

    /** 页面切换 */
    const val page = 520

    /** 入场：快起慢停 */
    val decel: Easing = CubicBezierEasing(0.05f, 0.7f, 0.1f, 1f)

    /** 退场：慢起快走 */
    val accel: Easing = CubicBezierEasing(0.3f, 0f, 1f, 1f)

    /** 同屏内的平滑过渡 */
    val standard: Easing = CubicBezierEasing(0.2f, 0f, 0f, 1f)

    /** 弹簧：柔和落位，几乎不过冲（interpolatingSpring(0, 1, 180, 26)） */
    fun <T> settle(): AnimationSpec<T> = spring(dampingRatio = 1f, stiffness = 180f)

    /** 弹簧：脆快，轻微过冲（interpolatingSpring(0, 1, 420, 34)） */
    fun <T> snap(): AnimationSpec<T> = spring(dampingRatio = 0.86f, stiffness = 420f)

    /** 弹簧：明显回弹，阻尼比约 0.54（interpolatingSpring(0, 1, 340, 20)） */
    fun <T> bounce(): AnimationSpec<T> = spring(dampingRatio = 0.54f, stiffness = 340f)

    /** 跟手：拖拽、手势松手后的回位（responsiveSpringMotion(0.3, 0.85)） */
    fun <T> follow(): AnimationSpec<T> = spring(dampingRatio = 0.85f, stiffness = 300f)

    /** 屏宽 → 动效缩放因子。手机约 0.55，平板 1.0 上下 */
    fun scale(width: Float): Float {
        if (!(width > 0f)) {
            return 1f
        }
        val s = width / 1000f
        return maxOf(0.55f, minOf(1.15f, s))
    }

    /** 位移幅度（dp），随屏宽缩放 */
    fun travel(base: Float, width: Float): Float {
        val v = base * scale(width)
        return Math.round(v * 10f) / 10f
    }

    /** 时长（ms），位移越短时长越短，收敛在 0.86~1.14 倍 */
    fun time(base: Int, width: Float): Int {
        val k = 0.86f + 0.24f * scale(width)
        return Math.round(base * k)
    }
}
