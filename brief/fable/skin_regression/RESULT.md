# Proof that gold & black and Hedayah did not change

Checked 2026-11-12 on branch `fable/lantern-skin` at the last code commit ("perf(web): load twelve rarely opened pages on demand"), against `master` `77bcff0`. The pictures are on the owner's computer in this folder and are not committed.

## 1. Test pictures (38)

Method: `bash brief/tools/skin_proof.sh <checkout of master> <absolute output folder>`. It draws 19 screens in each of the two older designs on `master` and on the branch at the same time, and compares them pixel by pixel. Output folder: `tip_36308b5/` (`before/`, `after/`, `diff/`, `result.txt`).

Result: **36 same, 2 different, 0 missing.**

The 2 different pictures are `14-settings-phone-ar-gold-black.png` and `14-settings-phone-ar-hedayah-skin.png`. The only difference is the new "Lantern and Arch" tile in Settings → Design. It adds a second row of tiles, so the rows below it move down. This change is intended.

## 2. Android emulator (Pixel 5, guest, Arabic, hosted data)

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
