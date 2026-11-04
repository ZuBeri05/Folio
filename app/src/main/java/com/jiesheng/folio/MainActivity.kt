package com.jiesheng.folio

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.rememberCoroutineScope
import androidx.core.view.WindowCompat
import com.jiesheng.folio.services.ReminderService
import com.jiesheng.folio.ui.FolioEntry
import com.jiesheng.folio.ui.FolioState

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        // 状态栏、导航栏图标用深色（原版 statusBarContentColor = #1F1B14）
        WindowCompat.getInsetsController(window, window.decorView).apply {
            isAppearanceLightStatusBars = true
            isAppearanceLightNavigationBars = true
        }
        ReminderService.ensureChannels(this)
        requestNotificationPermission()

        setContent {
            val scope = rememberCoroutineScope()
            val state = androidx.compose.runtime.remember { FolioState(applicationContext, scope) }
            FolioEntry(state)
        }
    }

    /** Android 13 起通知要用户点一次同意，和鸿蒙版 requestEnableNotification 对应 */
    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
            ) {
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
            }
        }
    }
}
