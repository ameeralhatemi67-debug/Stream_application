package sa.hadayah.streamer_app.streaming;

/** Geometry only: Camera2's SurfaceTexture already includes the sensor transform. */
public final class CameraFraming {
    private CameraFraming() {}

    public static int displayCorrection(int displayDegrees) {
        return Math.floorMod(-displayDegrees, 360);
    }

    public static boolean swapsAxes(int sensorDegrees, int displayDegrees) {
        return Math.floorMod(sensorDegrees - displayDegrees, 180) == 90;
    }

    /** Center-fit portrait, center-fill landscape. Negative offsets are intentional crops. */
    public static int[] viewport(int canvasWidth, int canvasHeight,
                                 int sourceWidth, int sourceHeight, boolean portrait) {
        if (canvasWidth <= 0 || canvasHeight <= 0 || sourceWidth <= 0 || sourceHeight <= 0) {
            throw new IllegalArgumentException("Invalid camera dimensions");
        }
        double sx = (double) canvasWidth / sourceWidth;
        double sy = (double) canvasHeight / sourceHeight;
        double scale = portrait ? Math.min(sx, sy) : Math.max(sx, sy);
        int width = Math.max(1, (int) Math.round(sourceWidth * scale));
        int height = Math.max(1, (int) Math.round(sourceHeight * scale));
        return new int[] {(canvasWidth - width) / 2, (canvasHeight - height) / 2, width, height};
    }
}
