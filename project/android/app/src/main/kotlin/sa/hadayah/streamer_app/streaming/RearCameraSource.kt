package sa.hadayah.streamer_app.streaming

import android.content.Context
import android.graphics.SurfaceTexture
import android.util.Size
import com.pedro.encoder.input.sources.video.VideoSource
import com.pedro.encoder.input.video.Camera2ApiManager
import com.pedro.encoder.input.video.CameraHelper.Facing
import kotlin.math.abs

/** Separate a supported capture size from the encoder canvas, including LEGACY cameras.
 * Camera2Source 2.7.5 rejects an unlisted encoder size even with setRequiredResolution.
 * The SDK camera manager still owns capture, autofocus, frame delivery and shutdown.
 */
internal class RearCameraSource(context: Context) : VideoSource() {
    private val camera = Camera2ApiManager(context)
    val cameraId = camera.getCameraIdForFacing(Facing.BACK)
    var captureSize = Size(1280, 720)
        private set

    override fun create(width: Int, height: Int, fps: Int, rotation: Int): Boolean {
        val sizes = camera.cameraResolutionsBack
        check(sizes.isNotEmpty()) { "No rear camera capture sizes" }
        // SDK's calculator returns the requested (unsupported) size if no aspect
        // ratio matches. Select an advertised buffer; GL crops/fits its real ratio.
        captureSize = sizes.minWith(compareBy<Size> {
            abs(it.width.toDouble() / it.height - width.toDouble() / height)
        }.thenBy { abs(it.width.toLong() * it.height - width.toLong() * height) })
        camera.setRequiredResolution(captureSize)
        return true
    }

    override fun start(surfaceTexture: SurfaceTexture) {
        if (isRunning()) return
        camera.prepareCamera(surfaceTexture, captureSize.width, captureSize.height, fps, Facing.BACK)
        camera.openCameraFacing(Facing.BACK)
    }

    override fun stop() = camera.closeCamera()
    override fun release() = stop()
    override fun isRunning() = camera.isRunning
}
