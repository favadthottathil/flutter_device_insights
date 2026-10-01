package dev.favad.flutter_device_insights

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.util.Log

/**
 * Streams battery level/status. The receiver is registered in [onListen] and
 * always unregistered in [onCancel] or [stop]; a leaked receiver keeps the
 * Context (and the sink) alive after Dart stopped listening.
 *
 * ACTION_BATTERY_CHANGED fires for voltage and temperature changes too, so
 * events are de-duplicated and only real level/status changes reach Dart.
 */
internal class BatteryStreamHandler(
    private val context: Context
) : BatteryStateStreamHandler() {
    private var receiver: BroadcastReceiver? = null
    private var lastEmitted: BatteryStateMessage? = null

    override fun onListen(
        p0: Any?,
        sink: PigeonEventSink<BatteryStateMessage>
    ) {
        // A second onListen without onCancel replaces the sink; drop the old
        // receiver first so we never hold two.
        stop()

        val newReceiver =
            object : BroadcastReceiver() {
                override fun onReceive(
                    context: Context,
                    intent: Intent
                ) {
                    emit(intent, sink)
                }
            }
        receiver = newReceiver

        // ACTION_BATTERY_CHANGED is sticky: registering returns the current
        // value, so the first event does not wait for the next change.
        val sticky = registerBatteryReceiver(newReceiver)
        Log.i(TAG, "battery receiver registered")
        sticky?.let { emit(it, sink) }
    }

    override fun onCancel(p0: Any?) {
        stop()
    }

    /** Idempotent. Also called when the plugin detaches from the engine. */
    fun stop() {
        val current = receiver ?: return
        receiver = null
        lastEmitted = null
        try {
            context.unregisterReceiver(current)
            Log.i(TAG, "battery receiver unregistered")
        } catch (e: IllegalArgumentException) {
            // Already unregistered; nothing to release.
            Log.w(TAG, "battery receiver was not registered", e)
        }
    }

    private fun registerBatteryReceiver(receiver: BroadcastReceiver): Intent? {
        val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }
    }

    private fun emit(
        intent: Intent,
        sink: PigeonEventSink<BatteryStateMessage>
    ) {
        val rawLevel = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        if (rawLevel < 0 || scale <= 0) return

        val message =
            BatteryStateMessage(
                level = (rawLevel * 100 / scale).toLong(),
                status = status(intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1))
            )
        if (message == lastEmitted) return
        lastEmitted = message

        // onReceive runs on the main thread, as EventSink requires.
        sink.success(message)
    }

    private fun status(status: Int): BatteryStatusMessage =
        when (status) {
            BatteryManager.BATTERY_STATUS_CHARGING -> BatteryStatusMessage.CHARGING
            BatteryManager.BATTERY_STATUS_DISCHARGING -> BatteryStatusMessage.DISCHARGING
            BatteryManager.BATTERY_STATUS_FULL -> BatteryStatusMessage.FULL
            BatteryManager.BATTERY_STATUS_NOT_CHARGING -> BatteryStatusMessage.NOT_CHARGING
            else -> BatteryStatusMessage.UNKNOWN
        }

    private companion object {
        const val TAG = "DeviceInsights"
    }
}
