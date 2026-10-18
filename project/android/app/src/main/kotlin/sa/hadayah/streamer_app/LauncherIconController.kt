package sa.hadayah.streamer_app

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Only launcher aliases change; MainActivity and its OAuth callbacks stay enabled. */
class LauncherIconController(private val context: Context) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "setHidayahIcon") {
            result.notImplemented()
            return
        }
        val hidayah = call.argument<Boolean>("enabled")
        if (hidayah == null) {
            result.error("invalid_appearance", "enabled must be a boolean", null)
            return
        }
        try {
            setHidayah(hidayah)
            result.success(null)
        } catch (error: Exception) {
            result.error("launcher_icon_failed", "Could not update the launcher icon", null)
        }
    }

    private fun setHidayah(hidayah: Boolean) {
        val manager = context.packageManager
        val normal = ComponentName(context, "sa.hadayah.streamer_app.DefaultLauncher")
        val gold = ComponentName(context, "sa.hadayah.streamer_app.HidayahLauncher")
        val target = if (hidayah) gold else normal
        val previous = if (hidayah) normal else gold
        fun enabled(component: ComponentName): Boolean =
            when (manager.getComponentEnabledSetting(component)) {
                PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> component == normal
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
                else -> false
            }
        if (enabled(target) && !enabled(previous)) return
        val flags = PackageManager.DONT_KILL_APP
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            manager.setComponentEnabledSettings(listOf(
                PackageManager.ComponentEnabledSetting(target, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, flags),
                PackageManager.ComponentEnabledSetting(previous, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, flags)
            ))
        } else {
            // Keep at least one launcher available even if the second operation fails.
            manager.setComponentEnabledSetting(target, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, flags)
            manager.setComponentEnabledSetting(previous, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, flags)
        }
    }
}
