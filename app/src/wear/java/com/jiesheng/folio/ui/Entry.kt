package com.jiesheng.folio.ui

import androidx.compose.runtime.Composable
import com.jiesheng.folio.wear.WearApp

/**
 * 手表版的根入口。
 *
 * 注意它拿到的还是同一个 FolioState —— 所有动效编排都在那里，
 * 手表只是换了一套更适合圆屏的排版，动画一行都没重写。
 */
@Composable
fun FolioEntry(state: FolioState) {
    WearApp(state)
}
