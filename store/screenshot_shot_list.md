# Store graphics and screenshot shot list

Status: 2026-10-16. The feature graphic and an icon fix are made; the screenshots must be taken by the owner from the signed release build, because they have to show real content from this build.

## 1. Files already made

| Asset | File | Play requirement | Status |
| --- | --- | --- | --- |
| Feature graphic | `store/assets/feature_graphic_1024x500.png` (source: `feature_graphic.html`) | 1024 x 500, PNG or JPEG, no transparency | Done, 24-bit, 1024 x 500. |
| App icon | `store/assets/icon_512_fullbleed.png` | 512 x 512, 32-bit PNG, up to 1 MB, full square | Use this one. The older `icon_512.png` has pre-rounded black corners, which Play's own rounding then shows as dark marks; the new file fills the corners with the icon's mint colour. |

The feature graphic holds the name in Arabic and English and "Live lectures, Channels, Venues". To change the wording, edit `feature_graphic.html` and run the Chrome command written in its first comment.

## 2. Screenshot rules (Play)

- **Phone: 2 to 8 per language**, PNG or JPEG, up to 8 MB each. Use 1080 x 1920 or similar.
- Each side between 320 and 3840 px, and the long side **at most 2 times the short side**. Many phones capture 1080 x 2400 (2.22:1), which Play **rejects**; crop to 1080 x 2160, or capture on an emulator at 1080 x 1920.
- Take the same set in **English** and in **Arabic** (RTL). Play lets you upload a separate set per language.
- Optional: 7-inch and 10-inch tablet sets (the app has tablet layouts). Skip for tomorrow if time is short.
- No device frames or text overlays are required. If you add captions, they must describe real features.

## 3. Before taking them

1. Install the **release** build from the Play internal-testing link, not `flutter run`.
2. Sign in as the **reviewer account** (`reviewer_access.md`), so the store images match what Google sees. It must be approved, own the test organization, and have a connected test YouTube channel.
3. Make real-looking content: one live stream running (or a recent recording), two channels, a scheduled show, a venue on the map. Use a real, tasteful lecture title. No lorem ipsum.
4. Clean the status bar so it looks tidy:

```bash
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command enter
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 1000
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
```

5. Capture each screen (PNG straight from the phone), then leave demo mode with `adb shell am broadcast -a com.android.systemui.demo -e command exit`:

```bash
adb exec-out screencap -p > en_01_feed.png
```

## 4. The eight screenshots (same order in English and Arabic)

| # | Screen | What must be visible | Avoid |
| --- | --- | --- | --- |
| 1 | **Discovery feed** | A live card with the LIVE badge and viewer count, channel cards, the bottom navigation. | Real private people's names. |
| 2 | **Live room** | Video playing, chat with a few messages, floating reactions, the viewer count. | Any real user's email, abusive text, a banned word. |
| 3 | **Channel profile** | Banner, avatar, Follow button, recordings and playlists tabs. | Empty tabs. |
| 4 | **Map** | Venues around Al Khobar, Dhahran or Dammam with markers, one venue card open. | A venue that is someone's home. |
| 5 | **Upcoming streams** | Planned cards with Saudi times and the reminder bell on. | Past one-time events. |
| 6 | **Go live studio** | The camera preview, the title field and the Go Live button. | The **stream key**, the RTMP address, a real face if the person has not agreed. |
| 7 | **Organization page** | Name, logo, team roster, venues, scheduled shows, live status. | Emails of members. |
| 8 | **Organization shows / scheduling** | "Shows and assignments" with a scheduled show and its presenter and Riyadh time. | The stream key and ingest address. |

Optional extras if Play lets you add more than eight: Settings > notification preferences, and Settings > Privacy (Download My Data and Delete My Account) to show the privacy controls.

## 5. Naming and checks

- Save as `store/screenshots/en/01_feed.png`..`08_org_shows.png` and `store/screenshots/ar/...` (keep these out of git if they contain real accounts).
- Open every image at full size once. Check: no clipped text, no debug banner, no "Hadayah Test" label or `.wave4v2` flavour, no red error screen, no stream key, no email address.
- The listing text names features that must appear in at least one screenshot: live room and chat, map, reminders, organizations, going live.
