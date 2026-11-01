package sa.hadayah.streamer_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createAlertsChannel()
    }

    // Where live, lesson and reminder pushes land (the manifest names it as
    // FCM's default). FCM's own fallback channel leaves them quiet in the tray;
    // these are time-sensitive, so they show as a heads-up.
    private fun createAlertsChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(
                getString(R.string.alerts_channel_id),
                getString(R.string.alerts_channel_name),
                NotificationManager.IMPORTANCE_HIGH
            )
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // v0.7 Checkpoint 2 -- direct platform-channel wrapper against
        // RootEncoder, owned end to end by RtmpPublisherBridge. See
        // doc/Roadmap/v0.7_Mobile_Streaming_Android.md.
        @Suppress("DEPRECATION") // Activity display on all supported API levels.
        val bridge = RtmpPublisherBridge(applicationContext, windowManager.defaultDisplay.displayId)

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
