package dev.favad.flutter_device_insights

import android.content.Context
import android.os.Build
import android.os.PowerManager
import android.util.Log

/**
 * Streams the device thermal status (API 29+). The listener is registered in
 * [onListen] and removed in [onCancel] or [stop]. It is delivered on the main
 * executor so the sink is only touched from the main thread.
 */
internal class ThermalStreamHandler(
    private val context: Context
) : ThermalStatusStreamHandler() {
    private var powerManager: PowerManager? = null
    private var listener: PowerManager.OnThermalStatusChangedListener? = null
    private var lastEmitted: ThermalStatusMessage? = null

    override fun onListen(
        p0: Any?,
        sink: PigeonEventSink<ThermalStatusMessage>
    ) {
        stop()

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            sink.error("UNAVAILABLE", "Thermal status requires Android 10 (API 29).", null)
            sink.endOfStream()
            return
        }

        val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        if (pm == null) {
            sink.error("UNAVAILABLE", "PowerManager not available.", null)
            sink.endOfStream()
            return
        }

        val newListener =
            PowerManager.OnThermalStatusChangedListener { status -> emit(status, sink) }
        powerManager = pm
        listener = newListener
        pm.addThermalStatusListener(context.mainExecutor, newListener)
        Log.i(TAG, "thermal listener registered")
        emit(pm.currentThermalStatus, sink)
    }

    override fun onCancel(p0: Any?) {
        stop()
    }

    /** Idempotent. Also called when the plugin detaches from the engine. */
    fun stop() {
        val pm = powerManager
        val current = listener
        powerManager = null
        listener = null
        lastEmitted = null
        if (pm != null && current != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            pm.removeThermalStatusListener(current)
            Log.i(TAG, "thermal listener removed")
        }
    }

    private fun emit(
        status: Int,
        sink: PigeonEventSink<ThermalStatusMessage>
    ) {
        val message = thermalStatus(status)
        if (message == lastEmitted) return
        lastEmitted = message
        sink.success(message)
    }

    private fun thermalStatus(status: Int): ThermalStatusMessage =
        when (status) {
            PowerManager.THERMAL_STATUS_NONE -> ThermalStatusMessage.NONE
            PowerManager.THERMAL_STATUS_LIGHT -> ThermalStatusMessage.LIGHT
            PowerManager.THERMAL_STATUS_MODERATE -> ThermalStatusMessage.MODERATE
            PowerManager.THERMAL_STATUS_SEVERE -> ThermalStatusMessage.SEVERE
            PowerManager.THERMAL_STATUS_CRITICAL -> ThermalStatusMessage.CRITICAL
            PowerManager.THERMAL_STATUS_EMERGENCY -> ThermalStatusMessage.EMERGENCY
            PowerManager.THERMAL_STATUS_SHUTDOWN -> ThermalStatusMessage.SHUTDOWN
            else -> ThermalStatusMessage.UNKNOWN
        }

    private companion object {
        const val TAG = "DeviceInsights"
    }
}
