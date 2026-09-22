package sa.hadayah.streamer_app.streaming

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.pedro.common.ConnectChecker
import com.pedro.library.rtmp.RtmpCamera2
import com.pedro.library.view.OpenGlView
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Owns the [RtmpCamera2] lifecycle end to end. Uses RootEncoder's dedicated
 * camera pipeline so sensor orientation, aspect ratios, and OpenGL preview
 * are calculated naturally without compression.
 */
class RtmpPublisherBridge(
    private val appContext: Context
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler, ConnectChecker {

    private var openGlView: OpenGlView? = null
    private var camera: RtmpCamera2? = null

    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var isStoppingIntentionally = false
    private var reconnectAttempt = 0
    private val maxReconnectAttempts = 6

    fun attach(view: OpenGlView) {
        openGlView = view
        if (camera == null) {
            camera = RtmpCamera2(view, this)
        } else {
            camera?.replaceView(view)
        }
        if (camera?.isStreaming == true && camera?.isOnPreview != true) {
            camera?.startPreview()
        }
    }

    fun onSurfaceLost() {
        openGlView = null
    }

    fun detach() {
        val cam = camera
        if (cam != null) {
            if (cam.isStreaming) cam.stopStream()
            if (cam.isOnPreview) cam.stopPreview()
        }
        camera = null
        openGlView = null
        stopForegroundService()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val view = openGlView
        if (view == null) {
            result.error("NOT_READY", "Camera preview is not attached yet.", null)
            return
        }
        if (camera == null) {
            camera = RtmpCamera2(view, this)
        }
        val cam = camera!!
        when (call.method) {
            "prepare" -> handlePrepare(call, result, cam, view)
            "switchCamera" -> handleSwitchCamera(result, cam)
            "setAudioOnly" -> handleSetAudioOnly(call, result, cam)
            "startStream" -> handleStartStream(call, result, cam)
            "stopStream" -> handleStopStream(result, cam)
            "setMuted" -> handleSetMuted(call, result, cam)
            "setOrientation" -> handleSetOrientation(call, result, cam)
            "dispose" -> {
                detach()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun handlePrepare(
        call: MethodCall,
        result: MethodChannel.Result,
        cam: RtmpCamera2,
        view: OpenGlView
    ) {
        val width = call.argument<Int>("width") ?: 1280
        val height = call.argument<Int>("height") ?: 720
        val videoBitrate = call.argument<Int>("videoBitrate") ?: 2_500_000
        try {
            if (cam.isOnPreview) {
                cam.stopPreview()
            }
            val videoPrepared = cam.prepareVideo(width, height, videoBitrate)
            val audioPrepared = cam.prepareAudio(128_000, 44100, true)
            if (videoPrepared && audioPrepared) {
                cam.startPreview()
                result.success(null)
            } else {
                result.error(
                    "PREPARE_FAILED",
                    "This device does not support the requested encoder configuration ($width x $height).",
                    null
                )
            }
        } catch (e: Exception) {
            result.error("PREPARE_FAILED", e.message, null)
        }
    }

    private fun handleSwitchCamera(result: MethodChannel.Result, cam: RtmpCamera2) {
        try {
            cam.switchCamera()
            result.success(null)
        } catch (e: Exception) {
            result.error("SWITCH_FAILED", e.message, null)
        }
    }

    private fun handleSetAudioOnly(
        call: MethodCall,
        result: MethodChannel.Result,
        cam: RtmpCamera2
    ) {
        val audioOnly = call.argument<Boolean>("audioOnly") ?: false
        try {
            if (audioOnly) {
                cam.glInterface?.muteVideo()
            } else {
                cam.glInterface?.unMuteVideo()
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("SOURCE_SWITCH_FAILED", e.message, null)
        }
    }

    private fun handleStartStream(
        call: MethodCall,
        result: MethodChannel.Result,
        cam: RtmpCamera2
    ) {
        val url = call.argument<String>("url")
        if (url.isNullOrBlank()) {
            result.error("INVALID_URL", "No RTMP URL was provided.", null)
            return
        }
        try {
            isStoppingIntentionally = false
            reconnectAttempt = 0
            startForegroundService()
            cam.getStreamClient().apply {
                setCheckServerAlive(true)
                shouldFailOnRead(true)
            }
            cam.startStream(url)
            result.success(null)
        } catch (e: Exception) {
            stopForegroundService()
            result.error("START_FAILED", e.message, null)
        }
    }

    private fun handleStopStream(result: MethodChannel.Result, cam: RtmpCamera2) {
        try {
            isStoppingIntentionally = true
            cam.stopStream()
        } finally {
            stopForegroundService()
        }
        result.success(null)
    }

    private fun handleSetOrientation(
        call: MethodCall,
        result: MethodChannel.Result,
        cam: RtmpCamera2
    ) {
        val orientation = call.argument<Int>("orientation") ?: 0
        try {
            result.success(null)
        } catch (e: Exception) {
            result.error("ORIENTATION_FAILED", e.message, null)
        }
    }

    private fun handleSetMuted(
        call: MethodCall,
        result: MethodChannel.Result,
        cam: RtmpCamera2
    ) {
        val muted = call.argument<Boolean>("muted") ?: false
        if (muted) cam.disableAudio() else cam.enableAudio()
        result.success(null)
    }

    private fun startForegroundService() {
        val intent = Intent(appContext, RtmpForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            appContext.startForegroundService(intent)
        } else {
            appContext.startService(intent)
        }
    }

    private fun stopForegroundService() {
        appContext.stopService(Intent(appContext, RtmpForegroundService::class.java))
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun emit(event: Map<String, Any?>) {
        // ConnectChecker callbacks aren't guaranteed to fire on the main
        // thread -- confirmed on-device: a read-error-triggered
        // onConnectionFailed (e.g. the "Broken pipe" from a killed server)
        // arrives on a background coroutine dispatcher, and EventChannel's
        // EventSink requires the platform (main) thread. Posting here makes
        // every emit() call site safe regardless of which thread called it.
        mainHandler.post {
            eventSink?.success(event)
        }
    }

    override fun onConnectionStarted(url: String) {
        emit(mapOf("type" to "connecting"))
    }

    override fun onConnectionSuccess() {
        reconnectAttempt = 0
        emit(mapOf("type" to "live"))
    }

    override fun onConnectionFailed(reason: String) {
        // Fires for a dropped mid-broadcast connection attempt too (not
        // just the initial connect), so this is also the recovery path for
        // "network switch / weak signal" -- distinct from onAuthError,
        // which means retrying with the same stream key won't help.
        attemptReconnect(reason)
    }

    override fun onDisconnect() {
        if (isStoppingIntentionally) {
            emit(mapOf("type" to "stopped"))
        } else {
            attemptReconnect("Connection lost")
        }
    }

    override fun onAuthError() {
        stopForegroundService()
        emit(mapOf("type" to "error", "message" to "RTMP authentication failed."))
    }

    /**
     * Bounded exponential-backoff reconnect (2s, 4s, 8s, 16s, capped at
     * 30s), driven by RootEncoder's own reTry -- the same ConnectChecker
     * callbacks fire again for each attempt, so this naturally loops until
     * either onConnectionSuccess (resets the counter) or maxReconnectAttempts
     * is exceeded (gives up for real, matching a genuine dropped-and-
     * unrecoverable connection rather than a silent freeze).
     */
    private fun attemptReconnect(reason: String) {
        reconnectAttempt++
        if (reconnectAttempt > maxReconnectAttempts) {
            emit(
                mapOf(
                    "type" to "error",
                    "message" to "Lost connection and could not reconnect: $reason"
                )
            )
            stopForegroundService()
            return
        }
        val delayMs = (2_000L shl (reconnectAttempt - 1)).coerceAtMost(30_000L)
        emit(
            mapOf(
                "type" to "reconnecting",
                "attempt" to reconnectAttempt,
                "maxAttempts" to maxReconnectAttempts
            )
        )
        // reTry() is called from wherever the triggering ConnectChecker
        // callback fired (not guaranteed to be the main thread -- see
        // emit()'s note), and RootEncoder's own @UiThread-annotated
        // internals don't tolerate that. Posting keeps this consistent with
        // emit() regardless of which thread attemptReconnect was entered on.
        mainHandler.post {
            val initiated = camera?.getStreamClient()?.reTry(delayMs, reason) ?: false
            if (!initiated) {
                // reTry() declined to schedule anything (e.g. the stream
                // isn't in a retryable state) -- give up for real instead of
                // leaving the UI stuck showing "reconnecting" forever with
                // no further callback ever coming.
                emit(
                    mapOf(
                        "type" to "error",
                        "message" to "Lost connection and could not reconnect: $reason"
                    )
                )
                stopForegroundService()
            }
        }
    }

    override fun onAuthSuccess() {}

    override fun onNewBitrate(bitrate: Long) {
        emit(mapOf("type" to "bitrate", "value" to bitrate))
    }
}
