# YouTube public content on web and phones

Every build reads public YouTube data through the `/api/youtube` Vercel
function. The web calls its own origin (so preview deployments use their own
function); phones call the public site, `AppIdentity.websiteUrl`. Since
2026-10-26 no build reads a `YOUTUBE_API_KEY` Flutter setting: the Android APK
is downloadable by anyone, and a key inside it could be unpacked and used to
spend the project's quota. Delete `YOUTUBE_API_KEY` from
`project/dart_define.local.json`, and delete or restrict to nothing the old
phone key in Google Cloud. The app identifies itself to the function with no
key and no browser headers; the function's `sec-fetch-site` check only turns
away cross-site browser pages.

Set `YOUTUBE_API_KEY` as a sensitive **Production** environment variable on
Vercel project `stream-application`. Production builds refuse a missing value.
Preview deployments need their own explicitly scoped key to load YouTube data;
without one the endpoint returns a generic 503. Redeploy after changing settings.
Never put the value in source control, logs or browser defines.

Use a Google key restricted to **YouTube Data API v3**. A key restricted to
Android apps or browser HTTP referrers will not work from Vercel (Google checks
headers that a server request does not carry).
For IP restrictions Vercel needs configured static egress. Keep provider quota
limits/alerts and apply Vercel Firewall rate limits to `/api/youtube` if traffic
requires them; with phones on the same endpoint, all app traffic now counts
against Vercel's function invocations and bandwidth. The endpoint is public for
guest viewing; browser-origin checks are not authentication or a distributed
rate limiter.
CDN hits can serve the cached public data before the function runs, so the
function's origin check is not a cache access control. No cross-origin read
permission is granted by the endpoint.

The function permits GET only, fixed Google endpoints and validated bounded
public queries. It rejects client keys, OAuth tokens, unknown/duplicate parameters,
unbounded lists and arbitrary upstream URLs. The server key goes to Google in
`X-Goog-Api-Key`, keeping it out of request URLs. It forwards no user headers, follows
no redirects, has an eight-second upstream timeout, caches successful public
catalog reads for five minutes and live/statistics reads for 15 seconds, and
returns generic uncached errors without Google responses or credential URLs.

Verification: `node --test scripts/youtube_proxy.test.mjs`, `flutter analyze`,
and `flutter test` from `project/`. After deployment, open a known populated
channel, check Archive and Playlists and open a playlist. Browser requests must
use `/api/youtube` with no key; the downloaded bundle must contain no YouTube key.
