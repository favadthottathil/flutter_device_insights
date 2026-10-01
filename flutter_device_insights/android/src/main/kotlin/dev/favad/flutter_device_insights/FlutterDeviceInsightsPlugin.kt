package dev.favad.flutter_device_insights

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger

/**
 * Implements the Pigeon-generated [DeviceInsightsHostApi]. Calls arrive on the
 * platform (main) thread, and every method except [getCacheSizeBytes] is cheap
 * enough to stay there. [getCacheSizeBytes] walks the disk, so Pigeon routes it
 * to a serial background queue (`@TaskQueue` in `pigeons/messages.dart`); it
 * must only touch state that is safe to read off the main thread.
 *
 * Errors are thrown as [FlutterError]; the generated code turns them into the
 * `PlatformException` Dart sees.
 */
class FlutterDeviceInsightsPlugin :
    FlutterPlugin,
    ActivityAware,
    DeviceInsightsHostApi {
    private var messenger: BinaryMessenger? = null

    // Written on the main thread (attach/detach) and read by getCacheSizeBytes
    // on the background queue, so it must be volatile.
    @Volatile
    private var applicationContext: Context? = null
    private var activity: Activity? = null
    private var batteryHandler: BatteryStreamHandler? = null
    private var thermalHandler: ThermalStreamHandler? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        val context = flutterPluginBinding.applicationContext
        val binaryMessenger = flutterPluginBinding.binaryMessenger
        applicationContext = context
        messenger = binaryMessenger

        DeviceInsightsHostApi.setUp(binaryMessenger, this)

        val battery = BatteryStreamHandler(context)
        val thermal = ThermalStreamHandler(context)
        batteryHandler = battery
        thermalHandler = thermal
        BatteryStateStreamHandler.register(binaryMessenger, battery)
        ThermalStatusStreamHandler.register(binaryMessenger, thermal)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        messenger?.let { DeviceInsightsHostApi.setUp(it, null) }
        // Detaching an engine does not call onCancel, so release native
        // listeners explicitly or the receiver outlives the engine. The
        // generated `register` does not return its EventChannel, so the stream
        // handlers themselves cannot be unset; they are dropped with the
        // engine's messenger.
        batteryHandler?.stop()
        thermalHandler?.stop()
        batteryHandler = null
        thermalHandler = null
        messenger = null
        applicationContext = null
    }

    // The Activity reference is only held between attach and detach, so a
    // rotation or a destroyed Activity never leaks through this plugin.
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun getBatteryLevel(): Long {
        val manager = applicationContext?.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        val level = manager?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        // The property is Int.MIN_VALUE when the device does not report it.
        if (level == null || level !in 0..100) {
            throw FlutterError("UNAVAILABLE", "Battery level not available.")
        }
        return level.toLong()
    }

    override fun getDeviceModel(): String {
        val manufacturer = Build.MANUFACTURER.replaceFirstChar { it.uppercase() }
        // Many models already include the manufacturer name; avoid "Samsung Samsung ...".
        return if (Build.MODEL.startsWith(Build.MANUFACTURER, ignoreCase = true)) {
            Build.MODEL
        } else {
            "$manufacturer ${Build.MODEL}"
        }
    }

    // Runs on the Pigeon background queue. `onFail` skips unreadable entries
    // instead of aborting the walk, so a file deleted mid-walk is not an error.
    override fun getCacheSizeBytes(): Long {
        val cacheDir =
            applicationContext?.cacheDir
                ?: throw FlutterError("UNAVAILABLE", "Cache directory not available.")
        return cacheDir
            .walkTopDown()
            .onFail { _, _ -> }
            .filter { it.isFile }
            .sumOf { it.length() }
    }

    override fun openAppSettings() {
        // Prefer the Activity so the settings screen opens in the app's task.
        // With no Activity (background engine) fall back to the application
        // context, which needs FLAG_ACTIVITY_NEW_TASK.
        val launcher: Context =
            activity ?: applicationContext
                ?: throw FlutterError("NO_CONTEXT", "Plugin is not attached to an engine.")
        val intent =
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", launcher.packageName, null)
                if (launcher !is Activity) addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        try {
            launcher.startActivity(intent)
        } catch (e: ActivityNotFoundException) {
            throw FlutterError("NO_ACTIVITY", "No settings screen available.", e.message)
        }
    }
}
