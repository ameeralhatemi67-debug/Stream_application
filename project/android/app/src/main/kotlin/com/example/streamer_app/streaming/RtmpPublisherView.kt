package com.example.streamer_app.streaming

import android.content.Context
import android.view.SurfaceHolder
import android.widget.FrameLayout
import com.pedro.library.view.OpenGlView
import io.flutter.plugin.platform.PlatformView

/**
 * PlatformView hosting RootEncoder's [OpenGlView] camera preview. Only
 * hands the raw view to [RtmpPublisherBridge] once its surface actually
 * exists -- attaching RtmpCamera2 to a not-yet-created surface is what the
 * library's own preview/stream lifecycle assumes never happens.
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
        container.addView(openGlView)
        openGlView.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) {
                bridge.attach(openGlView)
            }

            override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {}

            override fun surfaceDestroyed(holder: SurfaceHolder) {
                bridge.detach()
            }
        })
    }

    override fun getView() = container

    override fun dispose() {
        bridge.detach()
    }
}
