package dev.favad.flutter_device_insights

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import java.io.File
import org.junit.jupiter.api.io.TempDir
import org.mockito.kotlin.any
import org.mockito.kotlin.doReturn
import org.mockito.kotlin.doThrow
import org.mockito.kotlin.mock
import org.mockito.kotlin.never
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

internal class FlutterDeviceInsightsPluginTest {
    private val appContext: Context = mock()
    private val activity: Activity = mock()
    private val plugin = FlutterDeviceInsightsPlugin()

    private fun attachToEngine() {
        val binding: FlutterPlugin.FlutterPluginBinding =
            mock {
                on { applicationContext } doReturn appContext
                on { binaryMessenger } doReturn mock<BinaryMessenger>()
            }
        plugin.onAttachedToEngine(binding)
    }

    private fun attachToActivity() {
        val binding: ActivityPluginBinding = mock { on { activity } doReturn this@FlutterDeviceInsightsPluginTest.activity }
        plugin.onAttachedToActivity(binding)
    }

    private fun code(block: () -> Unit): String = assertFailsWith<FlutterError> { block() }.code

    @Test
    fun beforeAttaching_hostCallsFailWithAStableCode() {
        assertEquals("UNAVAILABLE", code { plugin.getBatteryLevel() })
        assertEquals("NO_CONTEXT", code { plugin.openAppSettings() })
        assertEquals("UNAVAILABLE", code { plugin.getCacheSizeBytes() })
    }

    @Test
    fun getCacheSizeBytes_sumsEveryFileInTheTree(
        @TempDir cache: File
    ) {
        File(cache, "a.bin").writeBytes(ByteArray(100))
        File(cache, "nested/deeper").mkdirs()
        File(cache, "nested/b.bin").writeBytes(ByteArray(250))
        File(cache, "nested/deeper/c.bin").writeBytes(ByteArray(7))
        whenever(appContext.cacheDir) doReturn cache
        attachToEngine()

        assertEquals(357L, plugin.getCacheSizeBytes())
    }

    @Test
    fun getCacheSizeBytes_isZeroForAnEmptyCache(
        @TempDir cache: File
    ) {
        File(cache, "empty/dirs/only").mkdirs()
        whenever(appContext.cacheDir) doReturn cache
        attachToEngine()

        assertEquals(0L, plugin.getCacheSizeBytes())
    }

    @Test
    fun getCacheSizeBytes_isUnavailableWithoutACacheDirectory() {
        attachToEngine()
        // cacheDir is null on the mock.
        assertEquals("UNAVAILABLE", code { plugin.getCacheSizeBytes() })
    }

    @Test
    fun getCacheSizeBytes_isUnavailableAfterDetachingFromTheEngine() {
        attachToEngine()
        plugin.onDetachedFromEngine(mock())

        assertEquals("UNAVAILABLE", code { plugin.getCacheSizeBytes() })
    }

    @Test
    fun getBatteryLevel_isUnavailableWhenTheServiceIsMissing() {
        attachToEngine()
        // getSystemService returns null on the mock.
        assertEquals("UNAVAILABLE", code { plugin.getBatteryLevel() })
    }

    @Test
    fun openAppSettings_prefersTheActivity() {
        attachToEngine()
        attachToActivity()

        plugin.openAppSettings()

        verify(activity).startActivity(any<Intent>())
        verify(appContext, never()).startActivity(any<Intent>())
    }

    @Test
    fun openAppSettings_fallsBackToTheApplicationContext() {
        attachToEngine()

        plugin.openAppSettings()

        verify(appContext).startActivity(any<Intent>())
    }

    @Test
    fun configChangeDetach_dropsTheActivity() {
        attachToEngine()
        attachToActivity()

        plugin.onDetachedFromActivityForConfigChanges()
        plugin.openAppSettings()

        verify(activity, never()).startActivity(any<Intent>())
        verify(appContext).startActivity(any<Intent>())
    }

    @Test
    fun reattaching_usesTheNewActivity() {
        attachToEngine()
        attachToActivity()
        plugin.onDetachedFromActivityForConfigChanges()
        val next: Activity = mock()
        plugin.onReattachedToActivityForConfigChanges(mock<ActivityPluginBinding> { on { activity } doReturn next })

        plugin.openAppSettings()

        verify(next).startActivity(any<Intent>())
        verify(activity, never()).startActivity(any<Intent>())
    }

    @Test
    fun detachingFromTheActivity_dropsTheReference() {
        attachToEngine()
        attachToActivity()

        plugin.onDetachedFromActivity()
        plugin.openAppSettings()

        verify(activity, never()).startActivity(any<Intent>())
    }

    @Test
    fun noSettingsScreen_isReportedAsNoActivity() {
        attachToEngine()
        attachToActivity()
        whenever(activity.startActivity(any<Intent>())) doThrow ActivityNotFoundException("none")

        assertEquals("NO_ACTIVITY", code { plugin.openAppSettings() })
    }

    @Test
    fun afterDetachingFromTheEngine_hostCallsFailAgain() {
        attachToEngine()
        plugin.onDetachedFromEngine(mock())

        assertEquals("NO_CONTEXT", code { plugin.openAppSettings() })
    }
}
