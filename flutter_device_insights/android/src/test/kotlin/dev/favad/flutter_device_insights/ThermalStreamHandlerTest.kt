package dev.favad.flutter_device_insights

import android.content.Context
import org.mockito.kotlin.any
import org.mockito.kotlin.anyOrNull
import org.mockito.kotlin.mock
import org.mockito.kotlin.never
import org.mockito.kotlin.verify
import kotlin.test.Test

/**
 * On the JVM `Build.VERSION.SDK_INT` is 0, so these cover the pre-API-29
 * path. The API 29+ listener path needs a device (see the integration tests)
 * or Robolectric, which this package does not use.
 */
internal class ThermalStreamHandlerTest {
    private val context: Context = mock()
    private val sink: PigeonEventSink<ThermalStatusMessage> = mock()
    private val handler = ThermalStreamHandler(context)

    @Test
    fun belowApi29_reportsUnavailableThenEndsTheStream() {
        handler.onListen(null, sink)

        verify(sink).error("UNAVAILABLE", "Thermal status requires Android 10 (API 29).", null)
        verify(sink).endOfStream()
        verify(sink, never()).success(any())
    }

    @Test
    fun belowApi29_neverTouchesThePowerManager() {
        handler.onListen(null, sink)

        verify(context, never()).getSystemService(anyOrNull<String>())
    }

    @Test
    fun stopAndCancel_areSafeWithoutAListener() {
        handler.stop()
        handler.onCancel(null)
    }
}
