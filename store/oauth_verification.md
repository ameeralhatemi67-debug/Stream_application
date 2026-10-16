# Google OAuth verification (YouTube scope)

Status: 2026-10-16, ready to paste. The owner submits it in Google Cloud Console > **Google Auth Platform**. Google does not guarantee a time; plan for about 2 to 8 weeks, and every question Google sends restarts part of the wait. Until it is approved, only accounts listed as **Test users** (maximum 100) can connect a YouTube channel, and they see an "unverified app" warning. Viewers and plain Google sign-in are not affected.

## 1. Facts to keep consistent everywhere

| Item | Value |
| --- | --- |
| App name | Hadayah Live (منصة هدايه) |
| Application home page | https://stream-application-ten.vercel.app |
| Privacy policy | https://stream-application-ten.vercel.app/privacy.html |
| Terms of service (optional field) | Leave empty until counsel approves terms; in-app terms exist (Settings > Governance). |
| Authorized domain | `stream-application-ten.vercel.app` is a shared `vercel.app` domain. Google may refuse to verify ownership of a domain you do not control. **Buy a domain** (for example `hadayah.app`), point the Vercel project at it, verify it in Google Search Console, and change `AppIdentity.websiteUrl` (one line) before submitting. |
| Support / developer contact email | the address in `AppIdentity.supportEmail` |
| Android package | `sa.hadayah.streamer_app` |
| Android sign-in return scheme | `sa.hadayah.streamerapp://login-callback` (note: no underscore; this differs from the package name on purpose) |
| YouTube consent callback | `https://zkkmfjsjouqzibvnzkau.supabase.co/functions/v1/channel-authorization` |
| Supabase sign-in callback | `https://zkkmfjsjouqzibvnzkau.supabase.co/auth/v1/callback` |

## 2. Every OAuth client and scope on the project

| Client | Used for | Scopes | Sensitive? |
| --- | --- | --- | --- |
| Google sign-in client (web client ID begins `990812869923-`) used through Supabase Auth | Signing in to the app | `openid`, `email`, `profile` | No |
| YouTube connection client (its ID is in Supabase secret `YOUTUBE_OAUTH_CLIENT_ID`; owner fills in here) | Connecting a broadcaster's channel | `https://www.googleapis.com/auth/youtube.force-ssl` | **Yes (sensitive)** |

Keep **only** these four scopes on the Data Access page. Do not add `youtube`, `youtube.readonly` or `youtube.upload` next to `force-ssl`: reviewers reject apps that request several overlapping YouTube scopes. Confirm in Google Cloud that both clients belong to the **same project** so one consent screen and one verification covers both. If they are in different projects, verify each.

## 3. Justification text (paste into "Scope justification")

> **Why Hadayah Live needs the YouTube scope**
>
> Hadayah Live is an educational live-streaming app. Approved broadcasters (individual lecturers and organizations) go live to their own YouTube channel from the app, from a phone or from OBS on a computer. To do this, our server must act on the broadcaster's channel after the broadcaster consents:
>
> 1. read the identity of the channel the broadcaster owns (channels.list, mine=true), to confirm which channel is being connected and to show its name;
> 2. create the live broadcast and its video stream and bind them (liveBroadcasts.insert and bind, liveStreams.insert), which returns the ingest address the phone or OBS sends video to;
> 3. start and end the broadcast (liveBroadcasts.transition), and read its status and the live stream's health (liveBroadcasts.list, liveStreams.list), so viewers see the true state and a broadcast that loses its feed is ended safely;
> 4. read the resulting video's status (videos.list) so the replay is shown only when YouTube has it ready.
>
> The Google methods that create, bind and transition live broadcasts accept only the `youtube` or `youtube.force-ssl` scope. `youtube.readonly` cannot create a broadcast, and `youtube.upload` does not cover live broadcasts. We request `youtube.force-ssl`, the narrower of the two that works. We do not request any other YouTube scope.
>
> How the data is handled: the broadcaster's access credentials are stored server-side in an encrypted secrets vault, are never sent to the app or to other users, and are used only for the actions above on the broadcaster's own channel. The broadcaster can disconnect in the app or revoke access in their Google Account at any time, and deleting the account destroys the credentials. We do not sell Google user data, use it for advertising, or let people read it except for support, security or legal reasons. Our use and transfer of information received from Google APIs adheres to the Google API Services User Data Policy, including the Limited Use requirements.

## 4. Demo video (record it, upload it as an **Unlisted** YouTube video)

Google requires one video that shows the whole OAuth flow in English (Arabic UI is fine if you add English captions). Record on a laptop browser with the real app and a test Google account that is in the Test users list.

| # | What to show | Need to be visible |
| --- | --- | --- |
| 1 | Open the app home page in a browser. Show the app name and the privacy policy link at the bottom of the welcome screen or in Settings. | App name and URL bar. |
| 2 | Sign in as the test broadcaster. Open Settings > **YouTube connections**. | The screen where connecting starts. |
| 3 | Tap **Connect YouTube**. On Google's page the **full consent screen** appears. Pause for 3 seconds on it. | URL bar showing `accounts.google.com`, the OAuth **client ID** in the URL (`client_id=`), the app name and the requested permission text. Zoom the address bar so the client ID is readable. |
| 4 | Click Allow. You return to the app, which shows the connected channel title. | "Connected" state and the channel name. |
| 5 | Start a broadcast (Go Live, phone camera or OBS). In YouTube Studio on a second tab show the new live broadcast appearing on the channel. | This proves create, bind and start (the scope in use). |
| 6 | End the broadcast in the app. Show YouTube Studio finishing it. | Proves transition to end. |
| 7 | Back in Settings tap **Disconnect**. Then open https://myaccount.google.com/permissions and show Google's list (the app disappears once you revoke). | Shows the user stays in control. |

Say out loud or add subtitles for each step. Keep it under 5 minutes. Do not show passwords or a stream key. The OAuth client ID must be readable in step 3.

## 5. Submission checklist

- [ ] Branding page: app name, logo (120x120 PNG, use the app icon), support email, home page, privacy policy, authorized domain (verified in Search Console).
- [ ] Data Access page: the four scopes above, each with a justification. For the three non-sensitive ones: "Sign-in and showing your name and picture."
- [ ] Audience: set to **External**, then **Publish app** (move from Testing to In production), then **Submit for verification** and paste section 3 and the video link.
- [ ] Add the reviewer broadcaster (and every pilot broadcaster) to **Test users** until approval.
- [ ] Reply to Google's emails the same day. Use the contact email on the Branding page and keep it monitored.
- [ ] Do not change scopes, app name or domain while verification is running.
- [ ] YouTube API Services: if you expect many broadcasts a day, request a quota extension and read the YouTube API Services Developer Policies first. The default is 10,000 units a day.
- [ ] Hadayah Live shows the YouTube player and states in its store listing and privacy policy that it uses YouTube API Services. Both are already in the drafts.
