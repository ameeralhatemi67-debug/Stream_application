package sa.hadayah.streamer_app.streaming

import android.os.SystemClock
import com.pedro.encoder.input.audio.CustomAudioEffect
import kotlin.math.sqrt

/** Reads the microphone's loudness from the PCM the encoder is about to send and
 * passes it on unchanged. RootEncoder calls [process] on its audio thread for every
 * unmuted buffer (a muted microphone sends silence without calling it), so the
 * studio's level meter moves while the presenter speaks.
 *
 * [onLevel] gets the loudest RMS (0.0 to 1.0, 16-bit PCM) of the last ~100 ms,
 * at most ten times a second, on the audio thread.
 */
class MicLevelEffect(private val onLevel: (Double) -> Unit) : CustomAudioEffect() {
    private var lastEmit = 0L
    private var loudest = 0.0

    override fun process(pcmBuffer: ByteArray): ByteArray {
        val samples = pcmBuffer.size / 2
        if (samples > 0) {
            var sum = 0.0
            var i = 0
            while (i + 1 < pcmBuffer.size) {
                // Little-endian signed 16-bit.
                val sample = ((pcmBuffer[i + 1].toInt() shl 8) or
                    (pcmBuffer[i].toInt() and 0xFF)).toShort().toDouble()
                sum += sample * sample
                i += 2
            }
            val rms = sqrt(sum / samples) / 32768.0
            if (rms > loudest) loudest = rms
        }
        val now = SystemClock.elapsedRealtime()
        if (now - lastEmit >= 100) {
            lastEmit = now
            onLevel(loudest.coerceIn(0.0, 1.0))
            loudest = 0.0
        }
        return pcmBuffer
    }
}
