package com.example.dnd_auto_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        when (action) {
            Intent.ACTION_BOOT_COMPLETED -> {
                Log.d("DndRuleCache", "BootCompletedReceiver fired: BOOT_COMPLETED")
            }
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                Log.d("DndRuleCache", "BootCompletedReceiver fired: MY_PACKAGE_REPLACED")
            }
            else -> {
                Log.d("DndRuleCache", "BootCompletedReceiver fired: action=$action")
            }
        }

        val serviceIntent = Intent(context, DndForegroundService::class.java).apply {
            this.action = CachedRulePayloadStore.ACTION_RESTORE_FROM_CACHE
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.d("DndRuleCache", "Restore-from-cache service start requested from receiver: action=$action")
        } catch (e: Exception) {
            Log.e(
                "DndRuleCache",
                "Restore-from-cache service start failed from receiver: action=$action, exception=${e::class.java.simpleName}, message=${e.message}"
            )
        }
    }
}
