package sa.hadayah.streamer_app

import sa.hadayah.streamer_app.streaming.RtmpPublisherBridge
import sa.hadayah.streamer_app.streaming.RtmpPublisherViewFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val METHOD_CHANNEL = "streamer_app/rtmp_publisher"
        private const val EVENT_CHANNEL = "streamer_app/rtmp_publisher/events"
        private const val VIEW_TYPE = "streamer_app/rtmp_camera_preview"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // v0.7 Checkpoint 2 -- direct platform-channel wrapper against
        // RootEncoder, owned end to end by RtmpPublisherBridge. See
        // doc/Roadmap/v0.7_Mobile_Streaming_Android.md.
        val bridge = RtmpPublisherBridge(applicationContext)

        flutterEngine.platformViewsController.registry.registerViewFactory(
            VIEW_TYPE,
            RtmpPublisherViewFactory(bridge)
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler(bridge)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(bridge)
    }
}
