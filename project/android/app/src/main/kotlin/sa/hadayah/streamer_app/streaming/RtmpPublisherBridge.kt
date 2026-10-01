package sa.hadayah.streamer_app.streaming

import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.SurfaceView
import com.pedro.common.ConnectChecker
import com.pedro.encoder.input.sources.audio.MicrophoneSource
import com.pedro.encoder.utils.ViewPort
import com.pedro.library.rtmp.RtmpStream
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** A single capture owner. Surface replacement never replaces an active encoder.
 * Network attempts are separate instances: callbacks from a retired client cannot
 * affect its replacement. Only Dart may request another attempt after authorization.
 */
class RtmpPublisherBridge(private val appContext: Context, private val displayId: Int) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private var preview: SurfaceView? = null
    private var stream: RtmpStream? = null
    private var eventSink: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())
    private var nativeGeneration = 0
    private var width = 1280
    private var height = 720
    private var bitrate = 2_500_000
    private var audioOnly = false
    private var muted = false
    private val displays = appContext.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    private val cameras = appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(id: Int) {}
        override fun onDisplayRemoved(id: Int) {}
        override fun onDisplayChanged(id: Int) { if (id == displayId) syncOrientation() }
    }

    fun attach(view: SurfaceView) {
        if (preview !== view && stream?.isOnPreview == true) stream?.stopPreview()
        preview = view
        attachPreview()
        syncOrientation()
    }

    fun resize(view: SurfaceView, width: Int, height: Int) {
        if (preview === view) {
            stream?.getGlInterface()?.setPreviewResolution(width, height)
            syncOrientation()
        }
    }

    private fun attachPreview() {
        val view = preview ?: return
        val current = stream ?: return
        if (view.holder.surface.isValid && !current.isOnPreview) current.startPreview(view)
    }

    fun onSurfaceLost(view: SurfaceView) {
        if (preview !== view) return
        // stopPreview detaches only the preview while streaming in RootEncoder 2.7.5.
        stream?.stopPreview()
        preview = null
    }

    private fun releaseStream() {
        nativeGeneration++
        val old = stream
        stream = null
        displays.unregisterDisplayListener(displayListener)
        old?.release()
        appContext.stopService(Intent(appContext, RtmpForegroundService::class.java))
    }

    fun detach() { releaseStream(); preview = null }

    private fun makeStream(dartGeneration: Int): RtmpStream {
        releaseStream()
        val token = nativeGeneration
        fun event(type: String, value: Long? = null) {
            main.post {
                if (token != nativeGeneration) return@post
                if (type == "disconnected" || type == "error") releaseStream()
                eventSink?.success(mapOf("type" to type, "generation" to dartGeneration,
                    "value" to value))
            }
        }
        val checker = object : ConnectChecker {
            override fun onConnectionStarted(url: String) = event("connecting")
            override fun onConnectionSuccess() = event("live")
            override fun onConnectionFailed(reason: String) = event("disconnected")
            override fun onDisconnect() = event("disconnected")
            override fun onAuthError() = event("error")
            override fun onAuthSuccess() {}
            override fun onNewBitrate(bitrate: Long) = event("bitrate", bitrate)
        }
        val camera = RearCameraSource(appContext)
        val current = RtmpStream(appContext, checker, camera, MicrophoneSource())
        stream = current
        check(current.prepareVideo(width, height, bitrate, rotation = 0) &&
            current.prepareAudio(44100, true, 128_000)) { "Unsupported encoder configuration" }
        // Display events cover both landscape directions and 180-degree rotations.
        // SDK sensor polling follows UI only after a matching sensor event and
        // assumes a portrait-native device; don't let it overwrite these transforms.
        current.getGlInterface().apply {
            autoHandleOrientation = false
            if (audioOnly) muteVideo()
        }
        displays.registerDisplayListener(displayListener, main)
        syncOrientation()
        if (muted) (current.audioSource as MicrophoneSource).mute()
        current.getStreamClient().apply {
            setTlsHostVerification(true)
            setCheckServerAlive(true)
            shouldFailOnRead(true)
            setReTries(0) // Dart owns bounded, authorized recovery. No native retry loop.
        }
        attachPreview()
        return current
    }

    private fun syncOrientation() {
        val current = stream ?: return
        val camera = current.videoSource as? RearCameraSource ?: return
        // Flutter may host SurfaceView in a virtual display which never rotates.
        // Use the Activity's display identity, not preview.display.
        val display = displays.getDisplay(displayId) ?: return
        val degrees = display.rotation * 90
        val sensor = cameras.getCameraCharacteristics(camera.cameraId)
            .get(CameraCharacteristics.SENSOR_ORIENTATION) ?: return
        val swapped = CameraFraming.swapsAxes(sensor, degrees)
        val sourceWidth = if (swapped) camera.captureSize.height else camera.captureSize.width
        val sourceHeight = if (swapped) camera.captureSize.width else camera.captureSize.height
        val portrait = sourceHeight > sourceWidth
        fun viewport(w: Int, h: Int): ViewPort {
            val rect = CameraFraming.viewport(w, h, sourceWidth, sourceHeight, portrait)
            return ViewPort(rect[0], rect[1], rect[2], rect[3])
        }
        current.getGlInterface().apply {
            // CameraRender uses getTransformMatrix each frame (sensor correction).
            // Apply only the inverse display rotation here, never the sensor twice.
            setCameraOrientation(CameraFraming.displayCorrection(degrees))
            // muteVideo uses a zero-sized viewport in SDK 2.7.5. A custom
            // viewport would override that and leak camera frames while hidden.
            setStreamViewPort(if (audioOnly) null else viewport(width, height))
            preview?.let { view ->
                if (view.width > 0 && view.height > 0) setPreviewViewPort(viewport(view.width, view.height))
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "prepare" -> {
                    if (preview == null) {
                        result.error("NOT_READY", "Camera preview is not attached yet.", null)
                        return
                    }
                    width = call.argument<Int>("width") ?: 1280
                    height = call.argument<Int>("height") ?: 720
                    bitrate = call.argument<Int>("videoBitrate") ?: 2_500_000
                    makeStream(-1)
                }
                "startStream" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrBlank()) {
                        result.error("INVALID_URL", "No RTMP URL was provided.", null)
                        return
                    }
                    muted = call.argument<Boolean>("muted") ?: muted
                    audioOnly = call.argument<Boolean>("audioOnly") ?: audioOnly
                    val current = makeStream(call.argument<Int>("generation") ?: 0)
                    val intent = Intent(appContext, RtmpForegroundService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                        appContext.startForegroundService(intent) else appContext.startService(intent)
                    current.startStream(url)
                }
                "stopStream" -> { releaseStream(); muted = false }
                "dispose" -> detach()
                "switchCamera" -> {
                    result.error("COMING_SOON", "Front camera switching is coming soon.", null)
                    return
                }
                "setAudioOnly" -> {
                    audioOnly = call.argument<Boolean>("audioOnly") ?: false
                    syncOrientation()
                    if (audioOnly) stream?.getGlInterface()?.muteVideo()
                    else stream?.getGlInterface()?.unMuteVideo()
                }
                "setMuted" -> {
                    muted = call.argument<Boolean>("muted") ?: false
                    val mic = stream?.audioSource as? MicrophoneSource
                    if (muted) mic?.mute() else mic?.unMute()
                }
                "setOrientation" -> syncOrientation()
                else -> { result.notImplemented(); return }
            }
            result.success(null)
        } catch (_: Exception) {
            releaseStream()
            // SDK exception strings can contain the ingest URL/key.
            result.error("ENCODER_FAILED", "The encoder operation failed.", null)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { eventSink = events }
    override fun onCancel(arguments: Any?) { eventSink = null }
}
