# Private & Restricted Streaming (Access Control & Waiting Room) — Feature Specification

This document details the architecture, access control policies, UI wireframes, and database models for **Private & Restricted Broadcasting** across all stream types (OBS, Phone Camera, Local).

---

## 1. Privacy Tier Architecture

```
                               ┌─────────────────────────────┐
                               │     STREAM PRIVACY TIER     │
                               └──────────────┬──────────────┘
                                              │
                    ┌─────────────────────────┴─────────────────────────┐
                    ▼                                                   ▼
       ┌─────────────────────────┐                         ┌─────────────────────────┐
       │   🌐 PUBLIC (Default)   │                         │       🔒 PRIVATE        │
       │                         │                         │                         │
       │ • Open to all users     │                         │ • YouTube set to        │
       │ • Appears in Discovery  │                         │   "Unlisted"            │
       │ • Plotted on Public Map │                         │ • Gated in-app access   │
       └─────────────────────────┘                         └────────────┬────────────┘
                                                                        │
                                       ┌────────────────────────────────┼────────────────────────────────┐
                                       ▼                                ▼                                ▼
                        ┌──────────────────────────────┐ ┌──────────────────────────────┐ ┌──────────────────────────────┐
                        │   1. Pre-Approved Roster     │ │   2. Knock & Approval        │ │   3. Secret Invite Link      │
                        │                              │ │                              │ │                              │
                        │ • Cohort / Student list      │ │ • Waiting Room gatekeeper    │ │ • Direct 1-tap invite to     │
                        │ • Specific user handles      │ │ • Host admits in real time   │ │   WhatsApp, Slack, Telegram  │
                        │ • Instant access for members │ │ • Accept / Deny controls     │ │ • Ephemeral signed token     │
                        └──────────────────────────────┘ └──────────────────────────────┘ └──────────────────────────────┘
```

---

## 2. Pre-Stream Configuration (Studio Sheet)

In the Broadcaster Studio Bottom Sheet, streamers configure:
1. **Access Selector:** `[ 🌐 Public (Default) ]` vs. `[ 🔒 Private ]`.
2. **When "Private" is selected:**
   - **Pre-Approved Roster (Whitelist):** Select pre-saved cohorts, class groups, or search specific user handles (`@sarah`, `@khalid`).
   - **Waiting Room Gatekeeper:** Toggle *"Require Host Knock Approval for new guests"* (enabled by default).
   - **Invite Link Sharing:** `[ 📲 Share Private Invite Link / QR ]`.

---

## 3. In-Stream Host Management HUD

During a private broadcast:
1. **Interactive Knocking Banner:**
   * When an unapproved guest taps the invite link, a slide-down banner appears on the host screen:
     $$\text{"👤 Khalid Al-Dossary wants to join"} \quad \mathbf{[ \text{✕ Deny} ]} \quad \mathbf{[ \text{✓ Admit} ]}$$
   * Host can tap **`[ Admit All ]`** to batch-admit waiting attendees.
2. **Live Room Director Panel (`[ 🔒 18 Attendees ]`):**
   * View full participant list.
   * Search and add `@username` live.
   * Promote to Co-Host or tap **`[ 🚫 Kick Out ]`** to immediately disconnect a user and revoke their token.

---

## 4. Viewer States

1. **Pre-Approved User:** Directly joins live stream with gold **"🔒 VIP / Private Invited"** badge.
2. **Knocking Guest:** Enters dark waiting room with animated radar: *"Waiting for host to admit you..."*.
3. **Unauthorized / Kicked:** Displayed clear notice: *"This broadcast is private. Contact host for access."*

---

## 5. Security & Realtime Enforcement

- **YouTube Ingestion:** Private streams automatically configure `privacyStatus: 'unlisted'` on YouTube Live API.
- **Supabase RLS:** Chat messages and player stream metadata are readable only by users with `status = 'approved'` in `stream_attendees`.
- **Force Disconnect:** If host kicks a user, a Realtime event forces the viewer's player to terminate immediately.
