# 05 — The Android APK from the website

Written 2026-10-26. While Google's review is pending, Android users download the
app from the website. The decision and its reasons are ADR-017 in
`Core_files/decisions.md`. This file is the how-to.

What exists after phase 1 (not yet on hosted or on the website):

| Piece | Where |
|---|---|
| Release table `app_releases` and the public bucket `app-releases` | `supabase/migrations/20261026120000_app_releases.sql` (local until you say yes) |
| Update check in the app: a dismissible prompt, the "update required" page, the Settings row | `AppUpdateController`, `AppUpdatePresenter`, `AppUpdateGate` |
| Build switch `DISTRIBUTION=apk` or `play` (release builds refuse anything else) | `project/android/app/build.gradle.kts` |
| Download page `/download` and the short link `/download/android` | `project/web/download.html`, `api/app-release.mjs`, `vercel.json` |
| YouTube through the website on phones (no key in the APK) | `YouTubeApiService`, `api/youtube.mjs` |

---

## 1. One-time setup (owner)

1. **Create the signing key.** In your own terminal, from the repo root:
   ```powershell
   powershell -ExecutionPolicy Bypass -File brief\launch\make_upload_key.ps1
   ```
   The script calls it an upload key. For the APK it is more than that: it
   becomes the **app signing key**, the key every APK install is tied to.
   - Back it up, with its password, in two places (a password manager and an
     encrypted USB drive). If it is lost, APK installs can never be updated;
     everyone would have to uninstall and reinstall.
   - In Play Console later (section 6), choose to **use your own app signing
     key** and upload this one. Do not let Google generate a new one.
2. **Supabase Storage limit.** Supabase dashboard → Storage → Settings → set the
   upload file size limit to at least **200 MB** (the default is 50 MB; a
   release APK is about 40–60 MB).
3. **Apply the migration.** Tell Claude "yes, apply app_releases". It goes
   through the Supabase connector and is renamed to the stamp it gets.
4. **Remove the old phone YouTube key.** Delete `YOUTUBE_API_KEY` from
   `project/dart_define.local.json`. In Google Cloud, delete the old phone key
   or restrict it to no API. Phones now use the website's `/api/youtube`.
5. **Push `master`.** Vercel then serves `/download` and `/api/app-release`.
   They read `SUPABASE_URL` and `SUPABASE_ANON_KEY` from the Production
   environment variables the web build already uses. Until a release is
   published, the page says "The download is not ready yet".

## 2. Build a release (Claude)

1. Bump `version:` in `project/pubspec.yaml`. The number after `+` (the version
   code) must be higher than every earlier release: `1.0.0+1`, then `1.0.1+2`...
2. From `project/`:
   ```powershell
   flutter build apk --release --dart-define-from-file=dart_define.local.json --dart-define=DISTRIBUTION=apk
   ```
   This is one APK for every phone type. The output is
   `build\app\outputs\flutter-apk\app-release.apk`; rename it
   `hadayah-live-<version>.apk`.
3. `node brief/tools/scan_build_secrets.mjs <apk>` must print
   `RESULT: clean`. It also fails on any Google API key other than the public
   Firebase one.
4. Record the size in bytes and the SHA-256:
   ```powershell
   Get-FileHash -Algorithm SHA256 build\app\outputs\flutter-apk\hadayah-live-1.0.0.apk
   ```
5. Install on an emulator and a phone. Smoke test: start, Discover, Map,
   Lessons, a live room, Settings → About shows the version.

## 3. Publish it (owner uploads, Claude writes the row after your yes)

1. Supabase → Storage → `app-releases` → upload the APK. Copy its public URL
   (`https://zkkmfjsjouqzibvnzkau.supabase.co/storage/v1/object/public/app-releases/hadayah-live-1.0.0.apk`).
2. Add the release as a draft, check it, then publish:
   ```sql
   insert into public.app_releases
     (channel, version_code, version_name, min_supported_code, download_url, sha256, size_bytes, notes_en, notes_ar)
   values ('apk', 1, '1.0.0', 0, '<public URL>', '<sha256, lower case>', <bytes>,
           'First release.', 'الإصدار الأول.');
   update public.app_releases set published_at = now()
    where channel = 'apk' and version_code = 1;
   ```
3. Open `https://<site>/download` on a phone: version, size, date and checksum
   show, and the button downloads the file.

Installed apps see a new release the next time they open or return to the
foreground (at most every six hours). They get one dialog with **Later** and
**Download**, on a main tab, never during a phone broadcast. Settings → About
keeps offering it until it is installed.

## 4. Require an update (rarely)

Only when old versions would break: a backend change they cannot handle, or a
security fix.
```sql
update public.app_releases set min_supported_code = <lowest version code still allowed>
 where channel = 'apk' and version_code = <newest version code>;
```
Older installs then show "Update required" over the app until they update. A
running phone broadcast is never interrupted; the page waits until it ends.
Lowering the number again lets them back in.

**Rule for backend changes:** add before you remove. A migration that removes a
table, column or function an older APK still uses must wait until
`min_supported_code` has moved past those versions.

## 5. Withdraw a release

```sql
update public.app_releases set published_at = null
 where channel = 'apk' and version_code = <code>;
```
The previous release becomes the newest again. Phones that already installed
the withdrawn one keep it (Android never installs an older version over a
newer one), so ship a fixed release with a higher version code instead.

## 6. Moving to Google Play

1. Play Console → your app → Test and release → App integrity → App signing:
   **use your own key**, export it with Google's PEPK tool, and upload it.
   Optionally make a separate upload key for future uploads.
2. Register the package name and this key for Android developer verification
   (Play Console), so the website APK keeps installing once Google enforces it
   worldwide in 2027.
3. Build the bundle with `--dart-define=DISTRIBUTION=play`
   (`flutter build appbundle --release ...`). A bundle built as `apk` is
   refused.
4. When the Play version is live, publish a `play` row whose `download_url` is
   the Play listing, and a last `apk` row with a higher version code that also
   points at the listing (notes such as "Hadayah Live is now on Google Play").
   The download page then shows **Get it on Google Play**. Because the key is
   the same, Play installs over the APK and keeps the sign-in.

## 7. Test the update path before the first public link

1. Build `1.0.0+1`, install it on phone A, sign in. Publish it (section 3).
2. Build `1.0.1+2`, upload and publish it with `min_supported_code = 0`.
   Phone A: reopen the app → the dialog appears → Download → install over the
   top → still signed in, Settings → About shows 1.0.1 (2).
3. Install `1.0.0+1` on phone B and set `min_supported_code = 2` → phone B
   shows "Update required" and cannot use the app until it updates.
4. Turn the network off on phone B and reopen: the app opens as before (a
   failed check never blocks).
