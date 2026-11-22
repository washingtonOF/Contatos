package com.washingtonof.conecta_messenger

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Intent
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.jitsi.meet.sdk.JitsiMeetActivity
import org.jitsi.meet.sdk.JitsiMeetConferenceOptions
import java.net.URI
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.washingtonof.conecta_messenger/calls",
        ).setMethodCallHandler { call, result ->
            if (call.method != "join") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            try {
                val server = URI(call.argument<String>("server").orEmpty())
                val room = call.argument<String>("room").orEmpty()
                val video = call.argument<Boolean>("video")
                require(server.scheme == "https" && !server.host.isNullOrEmpty() &&
                    server.userInfo == null && server.query == null && server.fragment == null)
                require(room.matches(Regex("[a-f0-9]{40}")) && video != null)

                val options = JitsiMeetConferenceOptions.Builder()
                    .setServerURL(server.toURL())
                    .setRoom(room)
                    .setVideoMuted(!video)
                    .setFeatureFlag("welcomepage.enabled", false)
                    .build()
                JitsiMeetActivity.launch(this, options)
                result.success(null)
            } catch (_: Exception) {
                result.error("CALL_UNAVAILABLE", "Não foi possível abrir o Jitsi.", null)
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.washingtonof.conecta_messenger/usage",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openSettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(null)
                    } catch (_: Exception) {
                        result.error("SETTINGS_UNAVAILABLE", "Acesso ao uso indisponível.", null)
                    }
                }
                "readToday" -> Thread {
                    try {
                        val report = readToday()
                        runOnUiThread { result.success(report) }
                    } catch (_: Exception) {
                        runOnUiThread {
                            result.error("USAGE_UNAVAILABLE", "Resumo indisponível.", null)
                        }
                    }
                }.start()
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun readToday(): Map<String, Any> {
        val appOps = getSystemService(AppOpsManager::class.java)
            ?: error("App operations unavailable")
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName,
        )
        if (mode != AppOpsManager.MODE_ALLOWED) return mapOf("authorized" to false)

        val now = System.currentTimeMillis()
        val midnight = Calendar.getInstance().apply {
            timeInMillis = now
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val dayStart = midnight.timeInMillis
        val lookback = (midnight.clone() as Calendar).apply { add(Calendar.DATE, -1) }
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val visible = packageManager.queryIntentActivities(launcher, 0)
            .associateBy { it.activityInfo.packageName }
        val manager = getSystemService(UsageStatsManager::class.java)
            ?: error("Usage statistics unavailable")
        val events = manager.queryEvents(lookback.timeInMillis, now)
            ?: error("Usage events unavailable")
        val started = mutableMapOf<String, Long>()
        val totals = mutableMapOf<String, Long>()

        fun finish(packageId: String, end: Long) {
            val start = started.remove(packageId) ?: return
            val elapsed = (end - maxOf(start, dayStart)).coerceAtLeast(0L)
            totals[packageId] = (totals[packageId] ?: 0L) + elapsed
        }

        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val packageId = event.packageName
            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    if (visible.containsKey(packageId)) {
                        started.putIfAbsent(packageId, event.timeStamp)
                    }
                }
                UsageEvents.Event.ACTIVITY_PAUSED -> {
                    if (packageId != null) finish(packageId, event.timeStamp)
                }
                UsageEvents.Event.SCREEN_NON_INTERACTIVE, UsageEvents.Event.DEVICE_SHUTDOWN ->
                    started.keys.toList().forEach { finish(it, event.timeStamp) }
            }
        }
        started.keys.toList().forEach { finish(it, now) }

        val apps = totals.entries
            .filter { it.value >= 60_000 }
            .sortedByDescending { it.value }
            .take(8)
            .mapNotNull { (packageId, elapsed) ->
                val label = visible[packageId]?.loadLabel(packageManager)
                    ?.toString()?.trim()?.take(60)?.takeIf { it.isNotEmpty() }
                    ?: return@mapNotNull null
                mapOf("name" to label, "minutes" to (elapsed / 60_000).coerceAtMost(1500L).toInt())
            }

        return mapOf(
            "authorized" to true,
            "day" to SimpleDateFormat("yyyy-MM-dd", Locale.US).format(midnight.time),
            "apps" to apps,
        )
    }
}
