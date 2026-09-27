package sa.hadayah.streamer_app.streaming

import android.content.Context
import android.view.SurfaceHolder
import android.view.SurfaceView
import io.flutter.plugin.platform.PlatformView

/** Preview surface only. The bridge owns capture and the encoder. */
class RtmpPublisherView(context: Context, private val bridge: RtmpPublisherBridge) : PlatformView {
    private val surface = SurfaceView(context)
    init {
        surface.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) = bridge.attach(surface)
            override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) =
                bridge.resize(surface, width, height)
            override fun surfaceDestroyed(holder: SurfaceHolder) = bridge.onSurfaceLost(surface)
        })
    }
    override fun getView() = surface
    override fun dispose() = bridge.onSurfaceLost(surface)
}
