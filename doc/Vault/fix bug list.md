---
type: project
tags: [streaming, flutter, bugs, triage, map, youtube]
project: Streamer_app
updated: 2026-08-16
---

# 🪲 Bug Tracking & Triage Log

> **Defect Log & Root Cause Investigation for the Educational Cloud Streaming Platform (Streamer App)**  
> Links: [[Core_files/README.md|Core README]] | [[Core_files/STATUS.md|System Status]] | [[doc/roadmap to publishing.md|Publishing Roadmap]] | [[doc/new feature list.md|Feature Backlog]]

---

## 🐛 Bug 01: Gray Map Tile Canvas Glitch on Circular Profile Avatar Marker Render

### 📋 Severity & Impact
- **Severity:** High (Visual / Core UX)
- **Impact:** GIS spatial map becomes unusable when streamer profile markers are in viewport.

### 🔍 Detailed Bug Description
The GIS map tiles render properly when navigating the map without circular profile markers. However, as soon as a streamer's circular profile picture marker enters the visible screen area, the map canvas turns completely gray/blank. 

Key observations:
1. When the user pans/zooms the map away from the coordinates containing the circular avatar, the map tiles instantly recover and render normally.
2. The bug does **not** occur when there is no circular profile picture on the map.
3. The bug does **not** occur when the bottom profile summary card/sheet is displayed; it is triggered exclusively when the custom circular profile avatar widget is rendered within the map's marker layer on the active viewport.

### 🔬 Suspected Root Causes & Investigation Plan
* **Image Decoder / Shader Glitch:** Network image caching or `ClipOval` / `ClipRRect` inside `flutter_map` `MarkerLayer` causing a canvas clipping buffer overflow or rendering raster pipeline crash on the Flutter canvas.
* **Repaint Boundary Missing:** Absence of `RepaintBoundary` around custom circular avatar widgets causing continuous tile repainting failure.
* **HTTP / CORS / Tile Provider Conflict:** Image network loading within the tile rendering thread causing thread contention or tile cancellation.

### 🛠️ Remediation Steps & Resolution (✅ RESOLVED)
1. **Isolated Repaints:** Replaced outer `RepaintBoundary` on `MarkerLayer` with isolated `RepaintBoundary` inside [`SpatialStreamerMarker`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/lib/features/map/presentation/widgets/spatial_streamer_marker.dart).
2. **Removed Hazardous Shaders:** Completely eliminated `ColorFiltered(BlendMode.saturation)` and improper image providers.
3. **Resilient Asset / Network Pipeline:** Built `Image.asset` / `Image.network` with built-in `errorBuilder` fallback icons (`Icons.person_rounded` / `Icons.apartment_rounded`).
4. **Three Stream States:**
   - **Offline:** Static circular avatar with dark subtle border (0% CPU/GPU overhead).
   - **Live Video:** Pinkish-red accent border (`#FF8080`), active pink radar pulse, and live viewer pill.
   - **Live Audio:** Soft gray accent border (`#A1A1AA`), active atmospheric gray radar pulse, and audio headphone badge.
   - **Organizations:** Distinctive squircle border (`borderRadius: 12`) with building badge.

---

## 🐛 Bug 02: YouTube Live / RTMP Stream Reception Failure

### 📋 Severity & Impact
- **Severity:** High (Core Media Streaming)
- **Impact:** Live broadcasts hosted on YouTube cannot be received or viewed inside the app player.

### 🔍 Detailed Bug Description
Local network streams (e.g. streaming over the same local WiFi via RTSP/RTMP/HTTP) connect and play properly. However, when connecting to an open, live YouTube broadcast (configured via OBS with an active broadcast key and accessible to public viewers via YouTube share link `https://youtu.be/...` or `https://www.youtube.com/watch?v=...`), the application fails to receive the stream or start playback.

Key observations:
1. OBS successfully broadcasts to YouTube's ingest servers.
2. The live broadcast is accessible and playing in external web browsers via the YouTube share link.
3. The in-app player (`youtube_player_iframe` or media engine) fails to parse or receive the live video feed.

### 🛠️ Remediation Steps & Resolution (✅ RESOLVED & VERIFIED)
1. **Root Cause Analysis (Errors 150, 152, 153):** Identified that YouTube's mid-2025/2026 security updates enforce strict embedder identification via the HTTP `Referer` header and `Referrer-Policy`. When a WebView loads embeds with default settings or missing referrers, YouTube aborts with Error 153 / 152.
2. **Applied Strategy 1 (Cross-Origin Referrer Meta & Header):**
   - Configured `AndroidWebViewController.setMediaPlaybackRequiresUserGesture(false)` and `WebKitWebViewController.setAllowsInlineMediaPlayback(true)`.
   - Injected `<meta name="referrer" content="strict-origin-when-cross-origin">` and `iframe referrerpolicy="strict-origin-when-cross-origin"`.
   - Set base domain origin strictly to `baseUrl: 'https://www.youtube-nocookie.com'`.
3. **Restored Both Live Streams & Archived VODs:** Verified that both live broadcasts and recorded lecture archives load, buffer, and play smoothly without errors.
4. **Comprehensive Research Documented:** Authored full research paper at `research docs/YouTube Embedded Streaming & Mobile WebView Errors (150-152-153) - Comprehensive Research & Solutions.md` and ADR-006 in `Core_files/decisions.md`.

---------------
new Edits to work on:
- Do not use the outside window for the google sign-in, as it would auto assign you an email, but I want the user to have the ability to pick what email to inter with. please make this changes for both the sign-in and log-in. so the user has the ability to pick the email. 
- Dose the "Full Name" pull from the email that the user is signing in with, or is it hardcoded ?
- the addition of Channel banner dose not work, make it accept any ratio, then auto fit it with our logic, meaning the user should not be forced into uploading a 16:9 HD, he just uploaded, then we auto fit, if the user does not like it, we give the option to arrange it (like how whatsapp, Facebook and X does it).
- same goes for the Profile Avatar / Portrait. 
- the images must note be gray, if gray the system should flag what was the problem. 
- in the step 3: Professional & Channel Info, in the filed for "Primary Academic / Content Field" have an option to add one of your own, and give the option to add up to 6.
- the "YouTube Channel Handle or URL *" is a must, but we also need to prove it, simple add a reader that checks if what the user added has "https://www.youtube.com/@" or is a "@..."
- in the location picker, we need a map, to correctly have the user pin point his location. add this as a option to the right of "Campus, Hall or Venue Description" so he can either type it out, or point at it in the map, plus after the user points at it in the map, have the field "Campus, Hall or Venue Description" be auto filed with that pointed location info. 
- Have a checker for the phone number, we cant let the user add letters, and we can have the user add not enough numbers, in saudi it either: +966542994098 or 0542994098, so we accept 10 or 12 or 12 plus the +, and we auto delete any space in-between the numbers, anything else we do not except.
- in the "Step 5: Review & Final Submit" add at the vary bottom "terms and conditions for streamers" the streamers part must be changed to "Organizations" when its an Org. have both as a clickable text, that can open a sheet with all of the info on that terms and conditions. user must check the box of the terms and conditions to "Submit Application". 
- the Organization type when in "Step 3: Professional & Channel Info" should have more steps, as we need to add additional streamers that work in this Organization, so the next page should be, "Step 3.5: Managing your Organization" where the user is prompted to add in streamers, using a + button, when he clicks it, the same fields for the streamer opens, where he can file them all up, or just file up the first streamer "Public Broadcast Handle" if the streamer is in the system, the rest would auto fill, if no then the user should manually add all that info. 
- in the "Step 4: Location & Contact Details" if the user picked Organization before, he should now have a main location and a + button to add the other locations. 

- the "Valid YouTube Broadcast target verified" massage that appears after adding the info in "YouTube Channel Handle or URL" should only appear after we correctly check if it actually is valid, meaning if possible we build an automation that checks youtube for that URL or Handle, if not exits then we do not show "Valid YouTube Broadcast target verified" yet we still except as we would have a admin check for him self its correct. 
- the image added in the Step 3.5 for then added streamer should be given when adding a streamer. so only go to default if use did not upload.
- in step 4 when the user is adding info on the Main Campus as a Organization, we should have the name shown for this location, and the correct location for it, same as how we do it for the "Additional Campus Branches"
- edit the numbers the are shown when the user clicks the "Phone / WhatsApp Number (Saudi Format)" so we dont show a number that the users would call. 
- the image Arrange is not working good, please check how X does it, and fully copy there method. 
- in the phone view in Step 3, we have a 2 overflowed, the first is in the "Individual Broadcaster" where its right side overflowed by 9.9 pixels. and the second is in the "+ add Custom" that is used for "Primary Academic / Content Fields (1/6) *"  see the image , and terminal massage. 
