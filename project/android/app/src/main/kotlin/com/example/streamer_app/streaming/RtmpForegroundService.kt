package com.example.streamer_app.streaming

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.example.streamer_app.R

/**
 * Keeps camera+mic capture alive while the app is backgrounded or the screen
 * is locked mid-broadcast (v0.7 Checkpoint 2 -- closes the foreground-service
 * gap doc/Audit/02_Permissions_Audit.md flagged as unverified). Started and
 * stopped by [RtmpPublisherBridge] only while a stream is actually live; this
 * service does no capture of its own.
 */
class RtmpForegroundService : Service() {

    companion object {
        private const val CHANNEL_ID = "rtmp_broadcast_channel"
        private const val NOTIFICATION_ID = 4201
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        return START_NOT_STICKY
    }

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Live broadcast",
                NotificationManager.IMPORTANCE_LOW
            )
            manager.createNotificationChannel(channel)
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("You're broadcasting live")
            .setContentText("Camera and microphone are being streamed.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
