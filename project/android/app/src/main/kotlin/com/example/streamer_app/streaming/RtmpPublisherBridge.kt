package com.example.streamer_app.streaming

import android.content.Context
import android.content.Intent
import android.os.Build
import com.pedro.common.ConnectChecker
import com.pedro.library.rtmp.RtmpCamera2
import com.pedro.library.view.OpenGlView
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Owns the [RtmpCamera2] lifecycle end to end. [RtmpPublisherView] only ever
 * hands this bridge the [OpenGlView] it renders into; Dart's
 * RtmpPublishEngine only ever talks to this bridge over
 * MethodChannel/EventChannel, never to RootEncoder directly -- the same
 * engine/UI split validated by the v0.7 Checkpoint 1 spike
 * (lib/spike_rtmp/rtmp_publish_engine.dart), so v1.1's iOS engine can sit
 * behind the exact same Dart-facing surface.
 */
class RtmpPublisherBridge(
    private val appContext: Context
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler, ConnectChecker {

    private var camera: RtmpCamera2? = null
    private var openGlView: OpenGlView? = null
    private var eventSink: EventChannel.EventSink? = null

    fun attach(view: OpenGlView) {
        if (camera != null) return
        openGlView = view
        camera = RtmpCamera2(view, this)
    }

    fun detach() {
        val cam = camera ?: return
        if (cam.isStreaming) cam.stopStream()
        if (cam.isOnPreview()) cam.stopPreview()
        camera = null
        openGlView = null
        stopForegroundService()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val cam = camera
        if (cam == null) {
            result.error("NOT_READY", "Camera preview is not attached yet.", null)
            return
        }
        when (call.method) {
            "prepare" -> handlePrepare(cam, result)
            "switchCamera" -> handleSwitchCamera(cam, result)
            "startStream" -> handleStartStream(cam, call, result)
            "stopStream" -> handleStopStream(cam, result)
            "setMuted" -> handleSetMuted(cam, call, result)
            "dispose" -> {
                detach()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun handlePrepare(cam: RtmpCamera2, result: MethodChannel.Result) {
        try {
            val prepared = cam.prepareVideo(1280, 720, 2_500_000) &&
                cam.prepareAudio(128_000, 44100, true)
            if (prepared) {
                cam.startPreview()
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

    private fun handleSwitchCamera(cam: RtmpCamera2, result: MethodChannel.Result) {
        try {
            cam.switchCamera()
            result.success(null)
        } catch (e: Exception) {
            result.error("SWITCH_FAILED", e.message, null)
        }
    }

    private fun handleStartStream(cam: RtmpCamera2, call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        if (url.isNullOrBlank()) {
            result.error("INVALID_URL", "No RTMP URL was provided.", null)
            return
        }
        try {
            startForegroundService()
            cam.startStream(url)
            result.success(null)
        } catch (e: Exception) {
            stopForegroundService()
            result.error("START_FAILED", e.message, null)
        }
    }

    private fun handleStopStream(cam: RtmpCamera2, result: MethodChannel.Result) {
        try {
            cam.stopStream()
        } finally {
            stopForegroundService()
        }
        result.success(null)
    }

    private fun handleSetMuted(cam: RtmpCamera2, call: MethodCall, result: MethodChannel.Result) {
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
        eventSink?.success(event)
    }

    override fun onConnectionStarted(url: String) {
        emit(mapOf("type" to "connecting"))
    }

    override fun onConnectionSuccess() {
        emit(mapOf("type" to "live"))
    }

    override fun onConnectionFailed(reason: String) {
        emit(mapOf("type" to "error", "message" to reason))
    }

    override fun onDisconnect() {
        emit(mapOf("type" to "stopped"))
    }

    override fun onAuthError() {
        emit(mapOf("type" to "error", "message" to "RTMP authentication failed."))
    }

    override fun onAuthSuccess() {}

    override fun onNewBitrate(bitrate: Long) {
        emit(mapOf("type" to "bitrate", "value" to bitrate))
    }
}
