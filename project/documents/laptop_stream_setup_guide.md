# Step-by-Step Guide: Live RTMP Laptop Streaming Setup

This guide provides step-by-step instructions for broadcasting a live video stream directly from your laptop to the **Streamer App** without waiting 24 hours for YouTube live streaming verification.

---

## Architecture Overview

```
 [ Laptop Web Camera / Screen ]
               │
               ▼
        [ OBS Studio ]
               │
               ▼  (RTMP Protocol)
   [ Local RTMP Media Server ]  (e.g., MonaServer or Node-Media-Server)
               │
               ▼  (Wi-Fi / Local Network)
      [ Streamer App ]  (VLC Engine Adapter rendering rtmp://<LAPTOP_IP>/live/demo)
```

---

## Step 1: Install OBS Studio & Local RTMP Server

### Option A: MonaServer (Easiest - 1 Click, No Installation Required)
1. Download **MonaServer** (Lightweight portable Windows RTMP server zip):
   * Link: `https://sourceforge.net/projects/monaserver/`
2. Extract the ZIP file on your laptop.
3. Double-click **`MonaServer.exe`**.
4. A black console window will open displaying:
   `MonaServer is starting... RTMP server started on port 1935`.
5. Keep `MonaServer.exe` running in the background.

---

## Step 2: Configure & Start Broadcast in OBS Studio

1. Open **OBS Studio**.
2. Add your Video Input:
   * Under **Sources**, click `+` ➔ **Video Capture Device** (Select your integrated webcam).
   * Optionally add **Display Capture** to stream your laptop screen.
3. Open OBS Settings:
   * Go to **File** ➔ **Settings** ➔ **Stream**.
   * **Service:** Select `Custom...`
   * **Server:** `rtmp://127.0.0.1/live`
   * **Stream Key:** `demo`
   * Click **Apply** and **OK**.
4. Click **Start Streaming** in OBS Studio.
   * You are now broadcasting a live RTMP feed on your local network!

---

## Step 3: Find Your Laptop's Local Network IP Address

1. Open Command Prompt on Windows:
   * Press `Win + R`, type `cmd`, and press Enter.
2. Type `ipconfig` and press Enter.
3. Look for your Wi-Fi IPv4 Address:
   * Example: `192.168.1.105` or `192.168.0.12`.

---

## Step 4: Connect the Streamer App to Your Laptop Feed

1. Launch the **Streamer App** (`flutter run -d windows` or on mobile/web).
2. Tap the secret **Cell Tower icon** (`cell_tower`) located in the top bar or Settings menu.
3. Enter your laptop's IPv4 address (e.g., `192.168.1.105`).
4. Click **Save & Update Stream URL**.

---

## Step 5: Test the 3 Live Stream Entry Points in the App

### Entry Point 1: Simulated Live Notification
1. Triple-tap anywhere on the screen (or long-press to activate Director Mode).
2. A banner will pop up: *"🔴 LIVE BROADCAST IN AL KHOBAR! Amir Al-Hatemi is going live..."*
3. **Tap the notification banner** ➔ Launches your live stream instantly!

### Entry Point 2: Spatial Map Card
1. Navigate to the **Spatial Map** tab.
2. Tap **Amir Al-Hatemi's pin** in Al Khobar.
3. When Live, the card displays a pulsing **LIVE NOW • Watch Live** button.
4. **Tap "Watch Live"** ➔ Opens your live stream!

### Entry Point 3: Discovery Feed
1. Navigate to the **Discovery Feed** tab.
2. Tap **Amir Al-Hatemi's channel card**.
3. **Tap the card** ➔ Opens your live stream!

---

## Step 6: Interactive Live Chat & Profile Navigation

* **Send Live Messages:** Type text in the chat input bar at the bottom of the stream screen and press Send. Your message will post to the live chat feed instantly.
* **Return to Profile:** Click Amir Al-Hatemi's avatar or name at the top of the live stream screen to view your broadcaster profile page (`/profile/prof_alghamdi_01`).
