package dev.favad.flutter_device_insights

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import org.mockito.kotlin.any
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.doReturn
import org.mockito.kotlin.doThrow
import org.mockito.kotlin.inOrder
import org.mockito.kotlin.mock
import org.mockito.kotlin.never
import org.mockito.kotlin.times
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import kotlin.test.Test

internal class BatteryStreamHandlerTest {
    private val context: Context = mock()
    private val sink: PigeonEventSink<BatteryStateMessage> = mock()
    private val handler = BatteryStreamHandler(context)

    private fun intent(
        level: Int = 80,
        scale: Int = 100,
        status: Int = BatteryManager.BATTERY_STATUS_CHARGING
    ): Intent =
        mock {
            on { getIntExtra(BatteryManager.EXTRA_LEVEL, -1) } doReturn level
            on { getIntExtra(BatteryManager.EXTRA_SCALE, -1) } doReturn scale
            on { getIntExtra(BatteryManager.EXTRA_STATUS, -1) } doReturn status
        }

    /** Starts listening and returns the receiver the handler registered. */
    private fun listen(sticky: Intent? = null): BroadcastReceiver {
        whenever(context.registerReceiver(any<BroadcastReceiver>(), any<IntentFilter>())) doReturn sticky
        handler.onListen(null, sink)
        return argumentCaptor<BroadcastReceiver>()
            .also { verify(context).registerReceiver(it.capture(), any<IntentFilter>()) }
            .firstValue
    }

    @Test
    fun onListen_emitsTheStickyValueImmediately() {
        listen(sticky = intent(level = 80))

        verify(sink).success(BatteryStateMessage(80, BatteryStatusMessage.CHARGING))
    }

    @Test
    fun onListen_withoutAStickyValue_emitsNothingUntilABroadcast() {
        val receiver = listen(sticky = null)
        verify(sink, never()).success(any())

        receiver.onReceive(context, intent(level = 55, status = BatteryManager.BATTERY_STATUS_DISCHARGING))

        verify(sink).success(BatteryStateMessage(55, BatteryStatusMessage.DISCHARGING))
    }

    @Test
    fun broadcastsThatChangeNothing_areDroppedButRealChangesPass() {
        val receiver = listen(sticky = intent(level = 80))

        // Voltage/temperature broadcasts repeat the same level and status.
        receiver.onReceive(context, intent(level = 80))
        receiver.onReceive(context, intent(level = 79))

        verify(sink, times(1)).success(BatteryStateMessage(80, BatteryStatusMessage.CHARGING))
        verify(sink, times(1)).success(BatteryStateMessage(79, BatteryStatusMessage.CHARGING))
    }

    @Test
    fun levelIsScaledToAPercentage() {
        listen(sticky = intent(level = 150, scale = 200))

        verify(sink).success(BatteryStateMessage(75, BatteryStatusMessage.CHARGING))
    }

    @Test
    fun unknownStatusCodes_mapToUnknown() {
        listen(sticky = intent(status = 99))

        verify(sink).success(BatteryStateMessage(80, BatteryStatusMessage.UNKNOWN))
    }

    @Test
    fun invalidExtras_areIgnored() {
        val receiver = listen(sticky = null)

        receiver.onReceive(context, intent(level = -1))
        receiver.onReceive(context, intent(scale = 0))

        verify(sink, never()).success(any())
    }

    @Test
    fun onCancel_unregistersTheReceiver() {
        val receiver = listen()

        handler.onCancel(null)

        verify(context).unregisterReceiver(receiver)
    }

    @Test
    fun stop_isIdempotent() {
        listen()

        handler.stop()
        handler.stop()
        handler.onCancel(null)

        verify(context, times(1)).unregisterReceiver(any())
    }

    @Test
    fun stop_withoutListening_doesNothing() {
        handler.stop()

        verify(context, never()).unregisterReceiver(any())
    }

    @Test
    fun aSecondOnListen_releasesTheFirstReceiverBeforeRegisteringAgain() {
        whenever(context.registerReceiver(any<BroadcastReceiver>(), any<IntentFilter>())) doReturn null as Intent?

        handler.onListen(null, sink)
        handler.onListen(null, sink)

        val order = inOrder(context)
        val captor = argumentCaptor<BroadcastReceiver>()
        order.verify(context).registerReceiver(captor.capture(), any<IntentFilter>())
        order.verify(context).unregisterReceiver(captor.firstValue)
        order.verify(context).registerReceiver(any<BroadcastReceiver>(), any<IntentFilter>())
    }

    @Test
    fun stop_survivesAReceiverThatIsAlreadyGone() {
        val receiver = listen()
        whenever(context.unregisterReceiver(receiver)) doThrow IllegalArgumentException("not registered")

        handler.stop()
        // Reaching here without an exception is the assertion; a retry is a no-op.
        handler.stop()

        verify(context, times(1)).unregisterReceiver(receiver)
    }

    @Test
    fun afterStop_theNextListenReEmitsTheSameValue() {
        listen(sticky = intent(level = 80))
        handler.stop()

        // Build the mock first: creating one inside whenever(...) breaks Mockito's stubbing.
        val sameValue = intent(level = 80)
        whenever(context.registerReceiver(any<BroadcastReceiver>(), any<IntentFilter>())) doReturn sameValue
        handler.onListen(null, sink)

        verify(sink, times(2)).success(BatteryStateMessage(80, BatteryStatusMessage.CHARGING))
    }
}
