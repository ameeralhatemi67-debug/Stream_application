import java.util.Arrays;
import sa.hadayah.streamer_app.streaming.CameraFraming;

/** Run with javac + java -ea; no Android runtime or additional dependency. */
public class CameraFramingCheck {
    public static void main(String[] args) {
        for (int sensor : new int[] {0, 90, 180, 270}) {
            for (int display : new int[] {0, 90, 180, 270}) {
                assert (CameraFraming.displayCorrection(display) + display) % 360 == 0;
                assert CameraFraming.swapsAxes(sensor, display) == ((sensor + display) % 180 == 90);
            }
        }
        rect(1280, 720, 720, 1280, true, 437, 0, 405, 720);
        rect(1280, 720, 1280, 720, false, 0, 0, 1280, 720);
        rect(1280, 720, 640, 480, false, 0, -120, 1280, 960);
        rect(1280, 720, 480, 640, true, 370, 0, 540, 720);
        rect(1280, 720, 2100, 900, false, -200, 0, 1680, 720);
        rect(1280, 720, 1000, 1000, false, 0, -280, 1280, 1280);
        // Short/wide previews and all canvas presets: fit has no lost edges;
        // fill has no bars, and rounding error is at most one output pixel.
        for (int[] canvas : new int[][] {{640,360},{1280,720},{1920,1080},{915,412},{412,915}}) {
            for (int[] source : new int[][] {{640,480},{1280,720},{720,1280},{480,640},{2100,900}}) {
                for (boolean fit : new boolean[] {true, false}) {
                    int[] r = CameraFraming.viewport(canvas[0], canvas[1], source[0], source[1], fit);
                    assert fit ? r[2] <= canvas[0] && r[3] <= canvas[1]
                               : r[2] >= canvas[0] && r[3] >= canvas[1];
                    assert Math.abs(r[2] * (double) source[1] / source[0] - r[3]) <= 1;
                }
            }
        }
        try {
            CameraFraming.viewport(0, 720, 640, 480, false);
            throw new AssertionError("Invalid canvas accepted");
        } catch (IllegalArgumentException expected) {}
        System.out.println("PASS: 16 rotation combinations, 6 exact rectangles, 50 aspect/fit cases, invalid dimensions");
    }

    private static void rect(int cw, int ch, int sw, int sh, boolean fit, int... expected) {
        int[] actual = CameraFraming.viewport(cw, ch, sw, sh, fit);
        assert Arrays.equals(actual, expected) : Arrays.toString(actual);
    }
}
