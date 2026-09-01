package com.example.streamer_app.streaming

import android.content.Context
import android.view.SurfaceHolder
import android.widget.FrameLayout
import com.pedro.encoder.utils.gl.AspectRatioMode
import com.pedro.library.view.OpenGlView
import io.flutter.plugin.platform.PlatformView

/**
 * PlatformView hosting RootEncoder's [OpenGlView] camera preview. Only
 * hands the raw view to [RtmpPublisherBridge] once its surface actually
 * exists -- starting a preview against a not-yet-created surface is what
 * the library's own preview/stream lifecycle assumes never happens.
 */
class RtmpPublisherView(
    context: Context,
    private val bridge: RtmpPublisherBridge
) : PlatformView {

    private val container = FrameLayout(context)
    private val openGlView = OpenGlView(context)

    init {
        openGlView.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        // Maintain aspect ratio without stretching the camera image
        openGlView.setAspectRatioMode(AspectRatioMode.Adjust)
        container.addView(openGlView)
        openGlView.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) {
                bridge.attach(openGlView)
            }

            override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {}

            override fun surfaceDestroyed(holder: SurfaceHolder) {
                // v0.7 Checkpoint 3 Phase 2 -- backgrounding/locking the
                // screen destroys this Surface (standard SurfaceView
                // behavior) without disposing this PlatformView. Only drop
                // the preview binding here; bridge.detach() (which actually
                // stops the broadcast) belongs to dispose() below, when the
                // screen is genuinely going away.
                bridge.onSurfaceLost()
            }
        })
    }

    override fun getView() = container

    override fun dispose() {
        bridge.detach()
    }
}
