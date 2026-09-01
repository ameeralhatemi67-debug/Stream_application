package com.example.streamer_app.streaming

import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.SurfaceView
import com.example.streamer_app.R
import com.pedro.common.ConnectChecker
import com.pedro.encoder.input.sources.audio.MicrophoneSource
import com.pedro.encoder.input.sources.video.BitmapSource
import com.pedro.encoder.input.sources.video.Camera2Source
import com.pedro.library.rtmp.RtmpStream
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Owns the [RtmpStream] lifecycle end to end. Built on RootEncoder's generic
 * pluggable-source architecture (not the camera-only RtmpCamera2 used by the
 * v0.7 Checkpoint 1 spike and Checkpoint 2 Phase 1) specifically so
 * Checkpoint 3 can swap the video source between the live camera and a
 * static [BitmapSource] for audio-only broadcasts, without needing two
 * separate encoder pipelines. [RtmpPublisherView] only ever hands this
 * bridge the [SurfaceView] it renders into; Dart's RtmpPublishEngine only
 * ever talks to this bridge over MethodChannel/EventChannel, never to
 * RootEncoder directly -- the same engine/UI split validated by the
 * Checkpoint 1 spike, so v1.1's iOS engine can sit behind the exact same
 * Dart-facing surface.
 */
class RtmpPublisherBridge(
    private val appContext: Context
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler, ConnectChecker {

    private val cameraSource = Camera2Source(appContext)
    private val microphoneSource = MicrophoneSource()
    private val stream = RtmpStream(appContext, this, cameraSource, microphoneSource)

    private var surfaceView: SurfaceView? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // v0.7 Checkpoint 4 Phase 1 -- connection-drop detection & reconnect.
    // isStoppingIntentionally distinguishes "the user tapped End Broadcast"
    // (handleStopStream) from "the connection actually dropped"
    // (onDisconnect firing on its own) -- RootEncoder's ConnectChecker
    // can't tell those apart itself, since it's the same callback either way.
    private var isStoppingIntentionally = false
    private var reconnectAttempt = 0
    private val maxReconnectAttempts = 6

    fun attach(view: SurfaceView) {
        // Only stores the view -- RtmpStream rejects prepareVideo/
        // prepareAudio once a preview is already running ("Stream, record
        // and preview must be stopped before prepareVideo"), so startPreview
        // has to happen *after* handlePrepare's prepareVideo/prepareAudio,
        // not as soon as the surface exists.
        surfaceView = view
        // Resuming from background/screen-lock (v0.7 Checkpoint 3 Phase 2):
        // Android recreates a new Surface for the PlatformView, but the
        // broadcast itself never stopped (see onSurfaceLost) -- just
        // reattach the preview so the on-screen view comes back.
        if (stream.isStreaming && !stream.isOnPreview) {
            stream.startPreview(view)
        }
    }

    /**
     * The OS tore down the PlatformView's Surface -- app backgrounded,
     * screen locked, etc. Only drops the on-screen preview binding; the
     * broadcast itself (RtmpForegroundService keeping the process alive)
     * keeps running. Only [detach] (the screen actually being disposed)
     * stops the stream for real -- conflating the two here previously meant
     * every background/lock silently ended the broadcast.
     */
    fun onSurfaceLost() {
        if (stream.isOnPreview) stream.stopPreview()
        surfaceView = null
    }

    fun detach() {
        if (stream.isStreaming) stream.stopStream()
        if (stream.isOnPreview) stream.stopPreview()
        surfaceView = null
        stopForegroundService()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (surfaceView == null) {
            result.error("NOT_READY", "Camera preview is not attached yet.", null)
            return
        }
        when (call.method) {
            "prepare" -> handlePrepare(call, result)
            "switchCamera" -> handleSwitchCamera(result)
            "setAudioOnly" -> handleSetAudioOnly(call, result)
            "startStream" -> handleStartStream(call, result)
            "stopStream" -> handleStopStream(result)
            "setMuted" -> handleSetMuted(call, result)
            "setOrientation" -> handleSetOrientation(call, result)
            "dispose" -> {
                detach()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun handlePrepare(call: MethodCall, result: MethodChannel.Result) {
        // Resolution/bitrate preset (v0.7 Checkpoint 2 Phase 3 -- see
        // BroadcastQualityPreset in rtmp_publish_engine.dart). Falls back to
        // the medium preset's values if Dart ever calls prepare() without
        // arguments.
        val width = call.argument<Int>("width") ?: 1280
        val height = call.argument<Int>("height") ?: 720
        val videoBitrate = call.argument<Int>("videoBitrate") ?: 2_500_000
        val view = surfaceView
        if (view == null) {
            result.error("NOT_READY", "Camera preview is not attached yet.", null)
            return
        }
        try {
            val prepared = stream.prepareVideo(width, height, videoBitrate) &&
                stream.prepareAudio(44100, true, 128_000)
            if (prepared) {
                if (!stream.isOnPreview) stream.startPreview(view)
                result.success(null)
            } else {
                result.error(
                    "PREPARE_FAILED",
                    "This device does not support the requested encoder configuration.",
                    null
                )
            }
        } catch (e: Exception) {
            result.error("PREPARE_FAILED", e.message, null)
        }
    }

    private fun handleSwitchCamera(result: MethodChannel.Result) {
        try {
            cameraSource.switchCamera()
            result.success(null)
        } catch (e: Exception) {
            result.error("SWITCH_FAILED", e.message, null)
        }
    }

    private fun handleSetAudioOnly(call: MethodCall, result: MethodChannel.Result) {
        val audioOnly = call.argument<Boolean>("audioOnly") ?: false
        try {
            if (audioOnly) {
                // v0.7 Checkpoint 3 Phase 1 -- YouTube's RTMP ingest requires
                // a video track even for an audio-only broadcast, so a
                // static branded image stands in for the camera feed rather
                // than dropping video entirely (RtmpOnlyAudio would send no
                // video track at all).
                val bitmap = BitmapFactory.decodeResource(
                    appContext.resources,
                    R.mipmap.ic_launcher
                )
                stream.changeVideoSource(BitmapSource(bitmap))
            } else {
                stream.changeVideoSource(cameraSource)
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("SOURCE_SWITCH_FAILED", e.message, null)
        }
    }

    private fun handleStartStream(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        if (url.isNullOrBlank()) {
            result.error("INVALID_URL", "No RTMP URL was provided.", null)
            return
        }
        try {
            isStoppingIntentionally = false
            reconnectAttempt = 0
            startForegroundService()
            // Without these, RootEncoder is slow (sometimes minutes) to
            // notice a dropped connection: a TCP socket can stay reported as
            // "connected" long after the network is actually gone (weak
            // signal, network switch). setCheckServerAlive proactively
            // checks reachability every read loop instead of waiting on a
            // stall; shouldFailOnRead makes a failed read actually surface
            // as onConnectionFailed instead of being swallowed silently.
            //
            // shouldSendPings deliberately NOT enabled: confirmed on-device
            // (killed a local test RTMP server mid-broadcast) that it
            // crashes the whole app -- CommandsManager.sendPing's
            // SocketException("Broken pipe") on a dead connection is thrown
            // from RtmpClient's own coroutine, uncaught, outside the
            // read-loop's runCatching that normally turns failures into
            // onConnectionFailed/onDisconnect. Reachability + read-failure
            // detection alone is what this app relies on for drop detection.
            stream.getStreamClient().apply {
                setCheckServerAlive(true)
                shouldFailOnRead(true)
            }
            stream.startStream(url)
            result.success(null)
        } catch (e: Exception) {
            stopForegroundService()
            result.error("START_FAILED", e.message, null)
        }
    }

    private fun handleStopStream(result: MethodChannel.Result) {
        try {
            isStoppingIntentionally = true
            stream.stopStream()
        } finally {
            stopForegroundService()
        }
        result.success(null)
    }

    private fun handleSetOrientation(call: MethodCall, result: MethodChannel.Result) {
        val orientation = call.argument<Int>("orientation") ?: 0
        try {
            stream.setOrientation(orientation)
            result.success(null)
        } catch (e: Exception) {
            result.error("ORIENTATION_FAILED", e.message, null)
        }
    }

    private fun handleSetMuted(call: MethodCall, result: MethodChannel.Result) {
        val muted = call.argument<Boolean>("muted") ?: false
        // RtmpStream (unlike the camera-specific RtmpCamera2) has no
        // disableAudio()/enableAudio() of its own -- mute lives on the
        // MicrophoneSource instance itself.
        if (muted) microphoneSource.mute() else microphoneSource.unMute()
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
            val initiated = stream.getStreamClient().reTry(delayMs, reason)
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
