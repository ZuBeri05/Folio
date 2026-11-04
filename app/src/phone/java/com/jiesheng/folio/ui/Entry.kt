package com.jiesheng.folio.ui

import androidx.compose.runtime.Composable

/**
 * 手机版的根入口。MainActivity 只认这个函数，具体渲染哪套界面由 flavor 决定。
 */
@Composable
fun FolioEntry(state: FolioState) {
    FolioApp(state)
}
