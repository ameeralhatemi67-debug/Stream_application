package sa.hadayah.streamer_app.streaming

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class RtmpPublisherViewFactory(
    private val bridge: RtmpPublisherBridge
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return RtmpPublisherView(context, bridge)
    }
}
