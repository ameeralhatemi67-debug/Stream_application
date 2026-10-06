# YouTube public content on web

Web uses the same-origin `/api/youtube` Vercel function. Native uses its existing
`YOUTUBE_API_KEY` Flutter build setting. The web never compiles that key, even
when a local define file contains it.

Set `YOUTUBE_API_KEY` as a sensitive **Production** environment variable on
Vercel project `stream-application`. Production builds refuse a missing value.
Preview deployments need their own explicitly scoped key to load YouTube data;
without one the endpoint returns a generic 503. Redeploy after changing settings.
Never put the value in source control, logs or browser defines.

Use a Google key restricted to **YouTube Data API v3**. Prefer a separate server
key so native application restrictions and rotations remain independent. A key
restricted to Android apps or browser HTTP referrers will not work from Vercel;
do not remove protections from an existing native key to make the server work.
For IP restrictions Vercel needs configured static egress. Keep provider quota
limits/alerts and apply Vercel Firewall rate limits to `/api/youtube` if traffic
requires them. The endpoint is public for guest viewing; browser-origin checks
are not authentication or a distributed rate limiter.
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
