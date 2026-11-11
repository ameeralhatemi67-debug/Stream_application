# Proof of what changed in gold & black and Hedayah

Checked 2026-11-12 on branch `fable/lantern-skin`, against `master` `77bcff0`. The pictures are on the owner's computer in this folder and are not committed.

Two changes in the older designs are intended: the new tile in Settings → Design, and the Report button for a broadcast or a channel (owner decision 2026-11-12). Part 1 shows that nothing else changed.

## 1. Test pictures (38)

Method: `bash brief/tools/skin_proof.sh <checkout of master> <absolute output folder>`. It draws 19 screens in each of the two older designs on `master` and on the branch at the same time, and compares them pixel by pixel. Output folder: `tip_36308b5/` (`before/`, `after/`, `diff/`, `result.txt`).

Result before the Report button (commit "perf(web): load twelve rarely opened pages on demand", folder `tip_36308b5/`): **36 same, 2 different, 0 missing.** The 2 different pictures are `14-settings-phone-ar-gold-black.png` and `14-settings-phone-ar-hedayah-skin.png`. The only difference is the new "Lantern and Arch" tile in Settings → Design. It adds a second row of tiles, so the rows below it move down.

Result with the Report button (the final code, folder `with_report/`): **28 same, 10 different, 0 missing.** The 10 are the 2 Settings pictures above and these 8, in which the difference is confined to the row of action buttons:

| Picture | Gold & black: changed area | Hedayah: changed area |
|---|---|---|
| `06-live-room-phone-ar` | x 22 to 185, y 4 to 52 | x 22 to 180, y 4 to 52 |
| `07-live-room-laptop-ar` | x 448 to 815, y 828 to 876 | x 448 to 851, y 828 to 876 |
| `08-audio-room-phone-ar` | x 22 to 185, y 4 to 52 | x 22 to 180, y 4 to 52 |
| `16-channel-phone-ar` | x 22 to 144, y 16 to 40 | x 22 to 142, y 18 to 38 |

In each, one button was added (a warning sign: a circle in gold & black, a triangle in Hedayah, from each design's own icon set). On a phone the room's title has one button less of room. On the laptop the Follow and "keep watching in the corner" buttons move by the width of the new button.

## 2. Android emulator (Pixel 5, guest, Arabic, hosted data)

These pairs were taken before the Report button was added, so the channel page and the replay in them do not show it.

Method: a profile build of `master` and of the branch with the same settings, installed in turn on the same emulator. The same taps open Discover, the map, lessons, the first channel and its first replay. The comparison ignores the status bar (the clock). Folders: `emulator/before/` (`master`) and `emulator/after/` (the branch).

| Screen | Gold & black | Hedayah |
|---|---|---|
| Discover | same | same |
| Map | same | same |
| Lessons | same | same |
| Channel page | differs only inside the cover | differs only inside the cover |
| Replay | differs only inside the YouTube player | differs only inside the YouTube player |

The channel cover has a slowly moving pattern: two pictures of the same build, taken four seconds apart, differ in the same area (about 78,000 pixels, largest colour step 26 of 255). The replay shows a different video frame each time.

Not covered on the emulator: Settings and the admin page (they need an account), and the live and audio rooms (no channel was live). The test pictures in part 1 cover them.
