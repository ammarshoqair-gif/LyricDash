# LyricDash

Shows synced lyrics on CarPlay for whatever's playing in Apple Music.
Built for personal use. No Mac needed.

## What you need
- An iPhone on **iOS 26 or later** (older versions can't show this on CarPlay)
- A car with CarPlay (wired or wireless)
- A Windows PC and your iPhone cable
- A free GitHub account (github.com)
- Your Apple ID

## Part 1: Build the app (free, in the cloud)
1. Unzip this folder on your PC.
2. On github.com, click **New repository**. Name it `LyricDash`. Private or Public both work. Click **Create repository**.
3. Click **uploading an existing file**. Open the unzipped `LyricDash` folder, select everything inside it (including the `.github` folder), and drag it all in. Click **Commit changes**.
4. Open the **Actions** tab. The build starts by itself. (If it asks, click **Enable workflows**, then **Build LyricDash → Run workflow**.)
5. Wait about 5–10 minutes for a green check.
6. Open the finished run. Under **Artifacts**, download `LyricDash-ipa`. Unzip it to get `LyricDash.ipa`.

**Red X instead of a green check?** Open the run, download `build-log` under Artifacts (or screenshot the red lines), and send it to Claude.

## Part 2: Put it on your iPhone
1. Install **iTunes** and **iCloud** from apple.com (the web versions, not the Microsoft Store ones).
2. Install **Sideloadly** from sideloadly.io.
3. Plug in your iPhone. Tap **Trust** on the phone if asked.
4. Open Sideloadly. Drag in `LyricDash.ipa`. Enter your Apple ID.
5. **Important:** in Advanced options, leave **Remove app extensions** OFF. The lyrics card lives in an extension. If it's removed, nothing shows on CarPlay.
6. Click **Start**.
7. On iPhone: **Settings → Privacy & Security → Developer Mode** → turn on (phone restarts).
8. On iPhone: **Settings → General → VPN & Device Management** → tap your Apple ID → **Trust**.

## Part 3: Test it at home first (2 minutes)
1. Open LyricDash. Tap **Start**. Allow Apple Music access.
2. Play a well-known song in Apple Music.
3. Lyrics should move in the app. Lock the phone: the lyrics card should be on the Lock Screen and keep moving.

If that works, the car is the easy part.

## Part 4: In the car
1. Connect to CarPlay.
2. Open LyricDash on the phone and tap **Start** (do this each drive).
3. Play music. The lyrics card appears on the CarPlay **Dashboard** (the split home view with the map and music tiles).
4. Lyrics early or late? Use the **Timing** buttons in the app. It remembers your setting.
5. Tap **Stop** when you're done. This saves battery.

## If something's off
- **No card on CarPlay:** on the car screen, open **Settings** and check **Live Activities** is on. On the phone, check **Settings → Apps → LyricDash → Live Activities** is on. Make sure you're looking at the Dashboard, not full-screen Maps.
- **Card says "Lyrics paused":** iOS put the app to sleep (this can happen after a long phone call). Open LyricDash once and it picks back up.
- **"No synced lyrics for this song":** the free database doesn't have that song. Try another.
- **Card disappeared:** iOS removes these cards after about 8 hours, or if you swipe it away. Open LyricDash to bring it back.

## Good to know
- With a free Apple ID, the app stops opening after 7 days. Plug in and run Sideloadly again to renew. Sideloadly can also refresh it automatically if you leave it running on your PC.
- Lyrics come from LRCLIB (lrclib.net), a free community database.
- Best for passengers or when stopped. Keep your eyes on the road.
