# Phone-to-Phone Air-Gapped Local Streaming & Meeting System — Feature Specification

---

## 1. Executive Summary & Core Value Proposition

The **Phone-to-Phone Local Streaming System** enables a broadcaster to host a real-time live video and audio broadcast **directly from their mobile phone** to other audience devices on the **same local Wi-Fi / LAN network**, with:
- 🔒 **100% Air-Gapped Privacy:** Video, audio, and chat never touch the cloud, YouTube, or external servers.
- ⚡ **Ultra-Low Latency:** Real-time playback with $< 300\text{ms}$ delay.
- 📶 **Zero-Internet Operability:** Works even on completely offline Wi-Fi routers (e.g. secure boardrooms, remote field camps, airplanes, exam halls).
- 🚪 **Host Gatekeeping (Knock & Approve):** No PIN codes; host accepts, denies, and can kick out viewers at any time.
- 📲 **Shareable QR Code:** Instantly shareable to WhatsApp, Slack, or Telegram for seamless 1-tap local joining.

---

## 2. Network Boundary & Local Isolation Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       LOCAL WI-FI (Subnet: 192.168.1.x)                     │
│                                                                             │
│   ┌────────────────────────────────┐                                        │
│   │   Broadcaster's Phone          │                                        │
│   │   • Embedded RTSP/HTTP Server  │                                        │
│   │   • Embedded WebSocket Server  │                                        │
│   │     (Port 8554 & 8080)         │                                        │
│   └───────────────┬────────────────┘                                        │
│                   │                                                         │
│                   │ 1. mDNS Local Multicast: "_streamer-lan._tcp"           │
│                   │    (Carries Host Name, Meeting Title, Avatar)           │
│                   │                                                         │
│                   ▼                                                         │
│   ┌────────────────────────────────┐                                        │
│   │   Local Audience Devices       │                                        │
│   │   • Background mDNS Listener   │                                        │
│   │   • Shows "📶 Local Meeting"   │                                        │
│   │     card on Discovery          │                                        │
│   └────────────────────────────────┘                                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                  ✕  (ZERO Data Sent to Cloud)
┌─────────────────────────────────────────────────────────────────────────────┐
│   PUBLIC INTERNET / 4G CELLULAR                                             │
│   • Global Supabase Database & External Viewers                             │
│   • Broadcaster profile remains strictly "OFFLINE" (Completely Hidden)      │
└─────────────────────────────────────────────────────────────────────────────┘
```

1. **Invisible to the Outside World:** When the broadcaster starts a local stream, the app does **NOT** update Supabase or any public API. External users on 4G or outside the Wi-Fi network see the broadcaster as offline.
2. **Local mDNS Auto-Discovery:** The broadcaster's phone announces an encrypted multicast DNS service record (`_streamer-lan._tcp`) on the local Wi-Fi router.
3. **Audience Feed Banner:** Any audience member opening the app on the same Wi-Fi immediately sees a dedicated top card:
   $$\text{"📶 Live on this Wi-Fi: Q3 Confidential Financial Review"}$$

---

## 3. Access Control, Knocking & Host Gatekeeping (Zero PINs)

```
[Viewer Taps "Join Meeting"]
            │
            ▼
Sends Local "Knock Request" via WebSocket
            │
            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Broadcaster Host Screen: Interactive Top Notification Banner            │
│                                                                         │
│  👤  Dr. Sarah Al-Otaibi wants to join                                 │
│      "Meeting: Q3 Financial Review"                                     │
│                                                                         │
│      [ ✕ Deny ]                            [ ✓ Accept & Admit ]         │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │
                 ┌───────────────────┴───────────────────┐
                 ▼                                       ▼
        Host Taps [ ✕ Deny ]                   Host Taps [ ✓ Accept ]
                 │                                       │
                 ▼                                       ▼
    Viewer Screen shows:                    Ephemeral Token Granted ──►
    "Request was declined by host"          Video, Audio & Chat Unlocked!
```

### Key Host Controls:
1. **Interactive Knocking Banner:**
   * When a viewer requests entry, an interactive slide-down banner appears on the streamer's camera screen.
   * Features direct, single-tap action buttons: `[ ✕ Deny ]` and `[ ✓ Accept ]`.
   * Broadcaster can swipe up to dismiss or let it queue in the participant drawer.
2. **Host Live Participant Drawer:**
   * Floating attendee counter `[ 👥 8 Active ]` on the host screen.
   * Tapping opens a sleek sliding panel listing all connected members.
   * Each member has a `[ 🚫 Kick Out ]` button. Tapping it instantly revokes their session token, closes their socket, and returns their device to Discovery.
3. **Shareable QR Code & Deep Link:**
   * Broadcaster can tap `[ 📲 Share Room QR ]` to display a large high-contrast QR code on screen.
   * Broadcaster can tap **"Share Link / QR"** to trigger the native OS share sheet (sending a direct join link to WhatsApp, Slack, or Email).

---

## 4. 100% Local Air-Gapped Chat & Video Engine

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                 Broadcaster Phone (Host Micro-Services)                     │
│                                                                             │
│  1. Video/Audio Engine:                                                     │
│     • RootEncoder `RtspServerCamera2` or Embedded HTTP MJPEG/AAC stream     │
│     • Streams on `rtsp://192.168.1.X:8554/live`                             │
│                                                                             │
│  2. Local WebSocket Hub:                                                    │
│     • Runs on `ws://192.168.1.X:8080/room`                                  │
│     • Handles: Knocking Handshake, Participant Auth Tokens, Local Chat      │
│                                                                             │
│  3. Ephemeral Storage:                                                      │
│     • All messages live in-memory only (Zero Database Storage)              │
│     • When host taps "End Meeting", all sockets close & chat vanishes       │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Local WebSocket Communication Protocol:
* `{"type": "knock", "userId": "...", "userName": "...", "avatarUrl": "..."}`
* `{"type": "knock_response", "approved": true, "token": "uuid-token"}`
* `{"type": "chat_message", "sender": "Ahmed", "text": "Can you zoom in on slide 2?"}`
* `{"type": "kick_user", "targetUserId": "...", "reason": "Host removed you"}`

---

## 5. UI / UX Design Specifications

### A. Broadcaster Studio Bottom Sheet (Setup Mode)
* In the **`[ ⚡ Local ]`** tab of the studio sheet:
  * Toggle: `[ 📱 From This Phone ]` vs `[ 💻 From Laptop Server ]`.
  * Meeting / Lecture Title text field.
  * Multiline Meeting Description / Agenda field.
  * Security Switch: **"Require Host Approval to Join (Knock)"** (Enabled by default).
  * Primary Action CTA: `[ ⚡ Start Local Stream ]`.

---

### B. Broadcaster Host HUD (In-Stream Screen)
```
┌─────────────────────────────────────────────────────────────────────────┐
│  [ 🔴 LOCAL PRIVATE ]   [ 📶 192.168.1.45 ]   [ ⏱️ 18:42 ]    [ ✕ End ]  │
│                                                                         │
│                                                                         │
│                                                                         │
│                    [ Live Camera Viewport / Preview ]                   │
│                                                                         │
│                                                                         │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ 👤 Dr. Sarah wants to join                [ ✕ Deny ]  [ ✓ Accept ]│  │  ◄── Interactive Knock Banner
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  [ 👥 12 Joined ]     [ 💬 Local Chat ]     [ 📲 Share QR ]  [ 🔄 Flip ] │  ◄── Host Action Toolbar
└─────────────────────────────────────────────────────────────────────────┘
```

---

### C. Viewer Player Screen (Audience View)
* **Pending Approval State:** Shows pulsing radar animation: *"Waiting for host to accept your request..."*
* **Active Stream State:** Full-screen low-latency video player with overlay local chat drawer and participant count.
* **Kicked State:** If host kicks viewer, player shows a gentle modal: *"You have been removed from this private meeting by the host"* and navigates back to Discovery.

---

## 6. Security, Compliance & Privacy Summary

1. **Saudi PDPL & Global Privacy Adherence:** No biometric, audio, video, or chat logs are ever uploaded to cloud servers. Zero data residency compliance concerns since data never leaves the room.
2. **Ephemeral Memory Model:** Video packets and chat text reside strictly in volatile device RAM and are purged instantly on stream termination.
3. **Subnet Firewalled:** Impossible for remote unauthorized parties to sniff or intercept unless physically connected to the encrypted Wi-Fi network.
