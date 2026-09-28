# Laptop layout batch, 2026-09-28

Base checkout: local `master` at `2ff8c94e605dbd8209b97ea050354567d3c2fae3`. The owner-supplied screenshots show the previous running layout; their executable build identity is not present in the image files. No browser build, phone build/install, backend operation or push was performed here. The tracked owner logo SVG and other pre-existing untracked evidence were preserved.

| ID | Root cause | Local repair |
| --- | --- | --- |
| DESK-01 | Shared identity card and Settings wrapper each imposed a 420px cap. | Settings identity fills its existing bounded section rail on laptop; phone remains capped. |
| DESK-02 | Channel reused the phone-width card and separate AppBar controls. | Desktop header fills the channel content width; actions sit at the physical left; back stays top left and translucent language/share controls top right in both languages. Existing approval, Follow, reminder and sharing calls remain in place. |
| DESK-03 | Desktop rendered a permanent second list beside the already available drawer. | Removed that panel; laptop button opens the existing drawer at top right with a transparent scrim. Phone placement and scrim stay unchanged. |
| DESK-04 | Discovery's responsive Wrap centered sparse rows and RTL start alignment would put them on the physical right. | Desktop rows start at the physical left in both locales. Existing 4-column cap and card data/rendering remain. |

Checks: `flutter analyze --no-pub` reported zero issues. `streamer_card_design_test.dart` passed 45 cases across English/Arabic, phone/desktop, 1x/2x text, fixed profile control corners, Follow/reminder and Discovery 1/2/3/4 columns. `map_tricity_widgets_test.dart` passed 144 cases including the new closed-by-default desktop drawer test and existing phone/Arabic/large-text map matrix. The final `flutter test --no-pub` run passed all 956 tests. Its first run found 18 stale map assertions for the former bottom button placement; those were updated for desktop while retaining phone expectations, and the full suite then passed.

Owner retest on a newly identified laptop build: open Settings and compare the identity/edit-button edges to the role and verification sections; open an approved broadcaster channel and check the full-width header, lower-left actions and fixed corner controls after switching Arabic; open Map, verify no permanent list or dimming and use the top-right list button to select a real saved venue; open Discovery with two saved broadcasters and resize through four to one columns. Check a phone view before acceptance. All four new test rows stay `NOT RUN` until this is observed on the new build. The map button corner is pending clarification because the owner note mentions both top right and top left.
