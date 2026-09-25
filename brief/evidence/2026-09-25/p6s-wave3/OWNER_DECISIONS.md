# P6S wave 3: owner decisions (D1–D8)

Date: 2026-09-25. Branch `opus/p6s-wave3-implementation`.

The branch does not decide any of these for you. Each default keeps the app truthful until you choose: nothing is labelled live, private or verified that has not been proven. The **Branch today** column gives the exact current behaviour, so you can accept it as it is or ask for the alternative.

| # | Decision | Branch today | Options | Recommendation | Blocks |
|---|---|---|---|---|---|
| D1 | Does "740" mean 720p? | Presets are unchanged: 480p (640×480, 4:3, 0.8 Mbps video), 720p (1280×720, 2.5 Mbps) and 1080p (1920×1080, 4.5 Mbps). The studio preset labels now come from the encoder's real bitrate (Group 3). They used to say "~1.2 Mbps" for a preset that sends 0.8 Mbps. No 740 preset exists and none was renamed. There is no Auto preset. | (a) 740 means 720p: keep 1280×720. (b) A literal 740-line size: that needs a custom dimension that the H.264 hardware encoders on both phones and YouTube ingest accept, measured on the phones. | (a). YouTube documents 720p. 740 has no standard ingest profile. | Nothing, if (a). |
| D2 | What "Remove from Feed" means | There are two admin actions (Group 1). **Hide from app discovery** is reversible and audited: the broadcast continues, current viewers stay, and the room and YouTube links keep working. **End and block link** ends the broadcast and blocks that watch ID from being listed again. Neither demotes the broadcaster or clears their device. Neither is described as private. | (a) Keep both. (b) Hide only. (c) Also change the YouTube visibility, which needs channel OAuth (D8). | (a). | (c) needs D8. |
| D3 | Local mode on the laptop: native Windows app, or browser? | Local is visibly unavailable (Group 4). No transport was built, nothing is saved, and no address is asked for. | (a) A native Windows app plus Android WebRTC peer rooms. (b) Browser viewers through a laptop hub (MediaMTX plus trusted local HTTPS). | (a) first, as the research recommends. It needs a `flutter_webrtc` packaging spike on your Windows toolchain and two physical devices. | Local mode (P6S-4). |
| D4 | Private internet streaming for v1.0 | Private stays behind a feature flag that is off. An unlisted YouTube link is never called private. | (a) Defer. (b) Pay for an authenticated media service (SFU or gateway plus TURN): new hosting cost and new security scope. | (a) Defer. | Private rooms. |
| D5 | Broadcasting from the laptop to YouTube inside the app | Unavailable. On a laptop, you broadcast with OBS Studio, and the app lists the watch link (Encoder tab, "OBS on a computer"). | (a) Keep OBS as the laptop route. (b) Build browser capture → gateway → RTMPS, which is new infrastructure. | (a). | Nothing, if (a). |
| D6 | External phone sender (for example Larix Broadcaster) | Offered as its own sender, "Another phone app" (Group 2). It is recorded on the server session as `external_phone`, never called OBS, and marked "not tested by us". Setup is manual; the app never shows or copies the key in this mode. | (a) Keep it as an unverified manual mode after your real test. (b) Remove it. | Keep it only after you run the retest script's step with the installed app and record the app version and its subscription or time limits. | Nothing. It is a copy and visibility decision. |
| D7 | Rotation during one broadcast | Unchanged. The encoder keeps the size chosen at the start. The native `setOrientation` call is still a no-op, so turning the phone does not rotate the picture that is sent. The End control stays visible in both orientations (Group 3). | (a) A fixed canvas chosen before the start, with rotation fitted by bars. (b) Dynamic output that switches between portrait and landscape: the encoder is reconfigured, which may interrupt viewers. | (a). It needs a native GL transform, which cannot be verified without your phones. | Correct rotation on physical phones (E4). |
| D8 | YouTube channel authorization (OAuth) for automatic create, bind, start and end | Not built. Before listing, the app checks the watch link with YouTube's public API. It confirms that the video exists, is live or starts within the hour, and belongs to the channel on your approved application or organization. When YouTube cannot be asked, or no channel is on record, the link is listed and the studio says plainly that it was not fully checked. These checks run in the app only; the server does not re-check them. | (a) Connect a Google Cloud OAuth client, complete sensitive-scope verification and run a server worker. (b) Stay manual. | Decide after the presentation demo. It needs your Google Cloud project, consent-screen verification and quota. | A server-enforced link check, automatic YouTube end, and changing YouTube visibility from the app. |

Also needed from you, not as a decision but to accept the work:
- **E4 on physical phones** (the retest script `RETEST_SCRIPT.md`). No behaviour in this branch counts as physically accepted until you run it.
- **Background broadcasting** ("Keep broadcasting"). The branch does not offer it. Leaving the phone broadcast screen asks first and then ends the broadcast. Offering it needs a foreground service that owns capture, verified on your phones.

## Local mode decision record (Group 4)

**Status.** Unavailable, on purpose. The studio's Local tab says that same-Wi-Fi streaming is not available in this version and points to Phone or Encoder. It asks for no address, starts no camera and saves nothing. The following were removed or corrected because they suggested Local streaming could be configured:
- the admin testing tools' "RTMP laptop IP" field, which stored an address no player read;
- the unused `rtmpStreamUrl`;
- the studio button's tooltip, which read "RTMP IP Settings" and now reads "Broadcaster Studio";
- the old guide's same-Wi-Fi steps ("no internet needed", "enter the laptop IP").

The laptop-IP state was removed. The only Local code left is the `localRtmp` player type and its `WebLivePlayerAdapter`, which cannot be reached because the room always plays YouTube. Removing them is a tracked follow-up.

**Why nothing was built.** Any honest Local transport needs choices and hardware that only you can provide:
- **D3, the topology.** The research recommends native peer-to-peer WebRTC between Android and a native Windows app, capped at three viewers. The alternative is a laptop relay (MediaMTX) for browser viewers, which needs trusted local HTTPS. The two lead to different builds; promising both would be untruthful.
- **Offline identity.** Should a Local room admit "locally admitted devices", or require an online approval check (which gives up fully offline rooms)?
- **Physical proof (E4).** The research's three-viewer cap depends on a thermal/CPU test on your phones. The four native combinations (phone→phone, phone→laptop, laptop→phone, laptop→laptop) must each run on your devices for 30 minutes, with three viewers, leave/rejoin, the router's internet unplugged and a host kill. The requirements are no internet requests, no public LIVE or map entry, revocation within 2 s, expiry within 60 s if renewal is lost, and no replay after End.

**What unblocks it.**
1. Choose D3 and the offline identity policy.
2. Run a `flutter_webrtc` packaging spike on your Windows toolchain.
3. Then build a dedicated `LocalSessionController`, a separate path that never uses the YouTube `set_live_state` flow or the public catalog.

No hosted migration is needed for the first LAN-only version.
