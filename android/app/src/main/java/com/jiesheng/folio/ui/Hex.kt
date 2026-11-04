package com.jiesheng.folio.ui

import androidx.compose.ui.graphics.Color

/**
 * 把鸿蒙版里的 `'#D9FFFDF8'` 这类字符串直接转成 Compose 的 Color。
 * 支持 #RRGGBB 和 #AARRGGBB 两种写法（鸿蒙那边 alpha 在前）。
 */
fun hexColor(value: String): Color {
    var raw = if (value.startsWith("#")) value.substring(1) else value
    if (raw.length == 6) {
        raw = "FF" + raw
    } else if (raw.length == 8) {
        // 已经是 AARRGGBB，和 Compose 一样
    } else if (raw.length == 3) {
        raw = "FF" + raw[0] + raw[0] + raw[1] + raw[1] + raw[2] + raw[2]
    } else {
        return Color.Black
    }
    val argb = raw.toLongOrNull(16) ?: return Color.Black
    return Color(argb.toInt())
}

/**
 * 把一层半透明遮罩直接压成一个实色。
 *
 * 原版用 `backdropBlur(6)` + 半透明 dim 盖住整页；Compose 里要拿到同样的观感，
 * 用「页面底色 × (1-α) + 遮罩色 × α」直接算出一个不透明色更省事，
 * 也不会让底下的文字透上来。
 */
fun dimmed(background: Color, overlay: Color): Color {
    val a = overlay.alpha
    return Color(
        red = background.red * (1f - a) + overlay.red * a,
        green = background.green * (1f - a) + overlay.green * a,
        blue = background.blue * (1f - a) + overlay.blue * a,
        alpha = 1f
    )
}
