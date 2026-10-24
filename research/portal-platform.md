# Portal platform constraints for an always-on AirPlay receiver

Research for [rudysev/portal-receiver#4](https://github.com/rudysev/portal-receiver/issues/4):
*What Portal platform constraints shape an always-on, third-party AirPlay receiver app?*

The Receiver is a standalone GPL-3.0 app (Kotlin + NDK, arm64). It runs on Portal+ Gen1, the Gen2
family and Portal TV, has no Google services, and integrates with Immortal (MIT) only through a
Contract. This file collects what is known about the platform, and where each fact comes from.

## How to read this

Every claim carries one evidence tag and the devices it applies to.

| Tag | Meaning |
|---|---|
| **[V]** | Verified on device, per the cited source (a log, a measurement, or an explicit "verified on ..."). |
| **[R]** | Reported working by a source, with no log or detail to back it. |
| **[D]** | Android platform behaviour, from developer.android.com or AOSP source. It applies to the API level named. |
| **[I]** | Inferred or unverified. Treat it as a hypothesis to test on device. |

Device shorthand:

| Short | Device | Android / API | Codename (`Build.DEVICE`) |
|---|---|---|---|
| **G1** | Portal+ Gen1 (also the original 2018 Portal) | 9 / 28 | `aloha` |
| **G2** | Portal 10" Gen2, Portal+ Gen2, Portal Mini, Portal Go | 10 / 29 | `omni` (Portal 10" Gen2, the only Gen2 model verified); `cipher` is named as "gen 2" in Immortal's camera doc; the others are unknown |
| **TV** | Portal TV (remote only, HDMI) | 9 / 28 | `ripley` |

Codename sources: `aloha` and `cipher` in `immortal/docs/design/camera-streaming.md:75`;
`omni` in `portal-receiver-prototype/IMMORTAL-PORT.md:271`; `ripley` in
`immortal/app/src/main/java/com/immortal/launcher/settings/SettingsDomains.kt:64-66`. API levels:
`immortal/SUBMISSIONS.md:68-71`.

### Sources and pins

| Short name | What | Pin |
|---|---|---|
| `immortal/...` | Immortal launcher, read-only local checkout. Kotlin paths below are relative to `app/src/main/java/com/immortal/launcher/` unless the path says otherwise. | `640ed8b` |
| `PR170/...` | [starbrightlab/immortal#170](https://github.com/starbrightlab/immortal/pull/170), the in-process prototype | head `30cb3ca` |
| `receiver/...` | `rudysev/portal-receiver-prototype` (private), the standalone staging app | `42694bb` |
| upstream | [jqssun/android-airplay-server](https://github.com/jqssun/android-airplay-server), which `receiver` vendors at `b9a590f` | checked 2026-10-23 |
| AOSP Q | `frameworks/base` `android10-release` branch, `services/core/java/com/android/server/wm/` | branch head, 2026-10-23 |

---

## 1. The answer: constraints that shape the design

1. **Starting at boot needs one manual launch first.** A store-installed app is in Android's
   "stopped state" until something launches it. Until then it gets no `BOOT_COMPLETED`, so the
   first run must come from the user or from Immortal. After that, `BOOT_COMPLETED` ->
   `startForegroundService` works on G2 [V]. Expect a missed boot if the device reboots while
   the package is still being dexopted [V G2]. (Sections 2.1-2.3)
2. **Raising a full-screen surface from the background is free on G1 and TV but restricted on
   G2.** Android 10 blocks background Activity starts unless an exemption applies. Immortal gets
   its exemption from the `SYSTEM_ALERT_WINDOW` app-op, which the provisioning kit grants over
   ADB. A store-installed Receiver gets no such grant. The Receiver therefore needs an exemption
   of its own, or must ask Immortal (which holds one) to start its Activity. This is the biggest
   constraint on the Contract. (Section 3)
3. **Immortal's screensaver and sleep features will fight a third-party full-screen session.**
   They include the dream-stop "REDREAM" relaunch of the photo frame, the idle and overnight
   `lockNow()`, and the media-pause on sleep. The prototype hid this with an in-process flag
   (`DreamPolicy.suppressFrame`), which an out-of-process Receiver cannot set. The Contract has
   to carry a "full-screen session active" signal, and Immortal has to act on it. (Section 8)
4. **Volume on touch Portals is one linked group.** Music, notification, system and TTS share
   one slider; alarm and voice-call are the only independent streams [V G2]. On Portal TV,
   `STREAM_MUSIC` is inaudible: HDMI plays at full scale, and app-side volume adjustments are
   dropped [V TV]. The pinned receiver starts every session at software gain 1.0 and requests no
   audio focus [V code]. Upstream has since added sender<->device volume sync. (Section 6)
5. **Speaker ownership with Snapcast has no device-level control today.** Immortal never talks
   to the Snapcast app. Stopping `MultiRoomService` stops only the now-playing relay, not the
   audio. Whether audio focus makes the stock Snapcast player yield is unverified. (Sections 6.4
   and 7)
6. **Now-playing is close to free.** Immortal reads any app's `MediaSession` through its
   notification listener (`MediaSessionReader` -> `NowPlayingHub`), so the Receiver only has to
   publish a well-formed session. Not yet verified end to end with the Receiver. (Section 7.1)
7. **Video decode works on G2 but has a known fault.** The G2 decoders are Qualcomm OMX AVC and
   HEVC. They fault under rapid restart, for example during YouTube ads, and recover after a
   codec reset [V G2]. Codec lists for G1 and TV are unknown. (Section 5)
8. **Portal TV needs Leanback packaging and D-pad UI.** That means a `LEANBACK_LAUNCHER` entry
   with a 320x180 banner, and D-pad focus everywhere. The remote's PROG_RED/GREEN/BLUE and
   SEARCH keys may be claimed by Immortal's accessibility remapper. Nothing about the Receiver
   has been verified on a TV. (Section 9)
9. **The store install path is strict about packaging.** The store installs one `base.apk` per
   PackageInstaller session, so the Receiver must be a single universal arm64 APK (no splits).
   Updates go through `versionUrl` and must be signed with the same key every time. Ship a PNG
   icon and `minSdk` <= 28. (Section 10)

---

## 2. Starting at boot and staying alive

### 2.1 Stopped state blocks the first boot

- **[D all]** A freshly installed app that has never been launched is in the *stopped state*.
  The system adds `FLAG_EXCLUDE_STOPPED_PACKAGES` to all broadcasts, so its `BOOT_COMPLETED`
  receiver does not fire until something launches the app once. The same applies after a user
  "Force stop". Source: [Android 3.1 platform highlights, "Launch controls on stopped applications"](https://developer.android.com/about/versions/android-3.1).
- **[I]** A Store install (one tap from Immortal) never launches the Receiver. Until the user
  opens it, it will not come back after a reboot. Two fallbacks are already available in
  Immortal:
  - Immortal can launch it. `BootLaunch` relaunches packages listed in `boot_apps.txt` 5 s after
    boot, then brings home back at 9 s (`immortal/BootLaunch.kt:24-63`,
    `immortal/BootReceiver.kt:33-53`).
  - A broadcast sent with `FLAG_INCLUDE_STOPPED_PACKAGES` to an explicit component also reaches
    a stopped app. Source: the Android 3.1 page above.

### 2.2 Boot receiver -> foreground service

- **[V G2]** `BOOT_COMPLETED` -> `AirPlayEngine.start()` -> `startForegroundService` with
  `ACTION_START_SERVER` brings the receiver back after a reboot. Tested on a Gen2 Portal 10"
  (`omni`). Source: `receiver/IMMORTAL-PORT.md:271-274`;
  `receiver/app/src/main/kotlin/io/github/jqssun/airplay/BootReceiver.kt:18-27`.
- **[R G1]** PR #170 reports testing on "Portal Gen2 and Portal+ Gen1" (PR body). The older
  `IMMORTAL-PORT.md:280-283` says G1 was untested, so G1 boot behaviour has no logged evidence.
- **[V code]** The upstream service ignores any start Intent without `ACTION_START_SERVER`. A
  bare `startForegroundService` therefore never reaches `startForeground`, and the system kills
  the process. Source: `receiver/airplay/.../service/AirPlayService.kt:296-303`;
  `receiver/IMMORTAL-PORT.md:74-80`.
- **[V G2]** The dexopt trap: install, then reboot within a few seconds, and the package is still
  being dexopted when `BOOT_COMPLETED` goes out. The receiver never fires. A second reboot works.
  Source: `receiver/IMMORTAL-PORT.md:276-278`; `PR170/docs/features/airplay.md:72-74`.
- **[V G1 G2 TV]** Immortal's own pattern uses the same hooks: `ImmortalApp.onCreate` plus
  `BootReceiver` call `FleetAgentService.ensureRunning`. That service calls `startForeground` in
  `onCreate` and returns `START_STICKY`. The docs describe it as reboot-proof on the non-root
  Android 9/10 Portals. Source: `immortal/FleetAgentService.kt:21-33,40-44,75`;
  `immortal/BootReceiver.kt:28-30`.
- **[V code]** The pinned receiver returns `START_NOT_STICKY`
  (`receiver/.../AirPlayService.kt:303`), so a low-memory kill is not restarted by the system.
  **[I]** The Receiver should use `START_STICKY`, or a watchdog as planned for the Snapcast
  companion (`immortal/docs/design/multi-room-audio.md:135-137`).

### 2.3 Foreground-service rules on API 28/29

- **[D API 28+]** `FOREGROUND_SERVICE` must be declared; it is a normal permission.
  `android:foregroundServiceType` exists from API 29. Declaring a type, and holding the matching
  `FOREGROUND_SERVICE_*` permission, is only required on Android 14+. Source:
  [Foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types).
  On Portal these are forward-compatibility only. Immortal's manifest says the same
  (`immortal/app/src/main/AndroidManifest.xml:61-64`).
- **[D API 35+ only]** Apps targeting Android 15+ may not start a `mediaPlayback` FGS from
  `BOOT_COMPLETED` (same page). This does not apply on Portal, but a `targetSdk` of 35 or higher
  would carry that rule to any newer device.
- **[V code]** The pinned module declares `connectedDevice|mediaPlayback` and starts with
  `FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE`. Source:
  `receiver/airplay/src/main/AndroidManifest.xml:21-30`; `receiver/.../AirPlayService.kt:879-886`.
- **[V code]** It holds a `PARTIAL_WAKE_LOCK` and a non-reference-counted Wi-Fi multicast lock
  for the server's lifetime. Source: `receiver/.../AirPlayService.kt:314-317`;
  `receiver/.../discovery/NsdServiceManager.kt:16-22`.

### 2.4 Wi-Fi power save

- **[V G1/G2, per code comment]** An idle, screen-off Portal power-saves its Wi-Fi radio, so the
  first incoming request can be dropped or delayed. Immortal's fleet agent holds a
  `WIFI_MODE_FULL_HIGH_PERF` lock to prevent this. Source: `immortal/FleetAgentService.kt:57-73`.
  The pinned receiver holds no Wi-Fi lock. **[I]** The Receiver needs one, or the first AirPlay
  connect to a sleeping Portal may stall.
- **[I G2 Go]** The Portal Go has a battery. Doze, which suspends network access while the
  device is unplugged and idle, could affect it. Mains-powered models never enter Doze.
  Untested.

---

## 3. Background Activity starts and waking the screen

### 3.1 The platform rule

- **[D API 29]** Background Activity-start restrictions began in Android 10 and do not exist on
  Android 9. Source: [Restrictions on starting activities from the background](https://developer.android.com/guide/components/activities/background-starts).
  **G1 and TV (API 28) have no restriction. Only G2 is affected.** Immortal's code says the same
  (`immortal/BootLaunch.kt:48-52`).
- **[D API 29]** The exemptions that exist in the Android 10 source
  (`ActivityStarter.shouldAbortBackgroundActivityStart`, AOSP Q `ActivityStarter.java:939-1062`):
  - The calling UID has a visible window, or is a persistent system process.
  - For a `PendingIntent`, the *sender* (`realCallingUid`) has a visible window, or is an
    associated companion app.
  - The caller holds `START_ACTIVITIES_FROM_BACKGROUND` (privileged), is the recents component,
    the device owner, or a companion app.
  - The caller process is allowed per `WindowProcessController.areBackgroundActivityStartsAllowed`
    (AOSP Q `WindowProcessController.java`). That covers: an explicit allow flag (set for
    system-sent PendingIntents such as notification taps); an activity of its own started or
    finished in the last 10 s (`ACTIVITY_BG_START_GRACE_PERIOD_MS`,
    `ActivityTaskManagerService.java:316`); an activity in a visible task; or being **bound by a
    UID that is currently foreground**.
  - The **calling** UID holds `SYSTEM_ALERT_WINDOW` (the last check, `ActivityStarter.java:1043-1048`).

### 3.2 What that means on Portal

- **[V G2]** Immortal depends on the `SYSTEM_ALERT_WINDOW` exemption for its frame relaunch,
  boot launches and the headless installer dialog. The provisioning kit grants it with
  `appops set <pkg> SYSTEM_ALERT_WINDOW allow`. Source: `immortal/provisioning/provision.sh:319-323`;
  `immortal/app/src/main/AndroidManifest.xml:65-69`; `immortal/HeadlessInstaller.kt:24-27`.
  portal-receiver-prototype's `setup.sh` grants the same op to itself over ADB
  (`receiver/setup.sh:26-28`).
- **[I G2]** A Receiver installed from the Store has no ADB step, so it gets no
  `SYSTEM_ALERT_WINDOW` grant. Portal's on-device "install unknown apps" toggle is non-functional
  (`immortal/docs/first-gen-portals.md:23-25`). Whether Portal Settings exposes a working
  "Display over other apps" toggle is **unknown**.
- **[I G2]** Ways a Receiver can bring its surface forward on G2 without its own grant (all
  derived from the AOSP Q rules above, none tested on a Portal):
  1. **Immortal starts the Activity itself.** Immortal calls `startActivity` with an explicit
     Intent to the Receiver's exported Activity. The check runs against the *caller's* UID, and
     Immortal holds `SYSTEM_ALERT_WINDOW`, so the start is allowed. A `PendingIntent` created by
     the Receiver and sent by Immortal does *not* help: the `SYSTEM_ALERT_WINDOW` check applies
     to the creator's UID, and the sender only counts if it has a visible window.
  2. **Immortal binds the Receiver's service.** If Immortal binds while its own UID is
     foreground, the Receiver process passes `isBoundByForegroundUid`. Immortal's UID is
     foreground whenever the home screen or the photo frame is showing. Fragile, and it depends
     on Immortal's state.
  3. **A full-screen-intent notification.** The PendingIntent is sent by the system, so the
     start is exempt, but the system decides whether to launch it or show a heads-up. Portal's
     SystemUI behaviour is untested.
  4. **The user grants "Display over other apps"**, if Portal Settings offers it.
- **[V G2]** In the in-process prototype, the service started `AirPlayActivity` with
  `FLAG_ACTIVITY_NEW_TASK | FLAG_ACTIVITY_REORDER_TO_FRONT` after `ScreenControl.wake`. The
  manifest added `showWhenLocked`, `turnScreenOn`, `singleTask` and `configChanges`. Source:
  `PR170/app/.../AirPlayControl.kt:269-279`; PR #170 diff, `app/src/main/AndroidManifest.xml`
  hunk `@@ -189,6 +189,31 @@`.

### 3.3 Waking the screen

- **[V G1/G2, per code comment]** A normal app cannot call `PowerManager.wakeUp`, but a
  `FULL_WAKE_LOCK | ACQUIRE_CAUSES_WAKEUP | ON_AFTER_RELEASE` wake lock turns the panel on. This
  is described as "the working wake path on API 28/29 Portals", and it needs only `WAKE_LOCK`.
  Source: `immortal/ScreenControl.kt:49-70`. Any app can do this, including the Receiver.
- **[V G1/G2]** Turning the screen *off* needs device-admin `lockNow()`, and only Immortal is a
  device admin (`immortal/ScreenControl.kt:16-24,72-81`). The Receiver cannot blank the screen,
  and should not need to.
- **[V G1/G2]** Meta's power manager honours an Activity that holds the screen on.
  `DreamPolicy`'s permanent frame relies on this (`immortal/DreamPolicy.kt:28-36`). The
  prototype's cast surface used `FLAG_KEEP_SCREEN_ON` (`PR170/app/.../AirPlayActivity.kt:94-100`).
  The Portal has no keyguard (`immortal/ScreenControl.kt:16-19`).

---

## 4. mDNS via NsdManager

- **[V G2]** The pinned receiver registers `_airplay._tcp` and `_raop._tcp` through
  `NsdManager`, with TXT records set by `NsdServiceInfo.setAttribute`. Both registered under the
  advertised name on a Gen2 Portal 10". Source:
  `receiver/airplay/.../discovery/NsdServiceManager.kt:24-72`; `receiver/IMMORTAL-PORT.md:271-273`.
  The native UxPlay `dnssd` layer is a shim that only stores TXT records; Kotlin does the actual
  registration (`receiver/airplay/src/main/cpp/android_dnssd_shim.c:1-5`).
- **[V code, per comment]** mDNS does not receive on Android 9/10 without a held
  `WifiManager.MulticastLock` (`CHANGE_WIFI_MULTICAST_STATE`, a normal permission). Source:
  `receiver/airplay/src/main/AndroidManifest.xml:18-19`.
- **[V G1/G2]** Immortal already uses `NsdManager` on Portals to advertise and browse
  `_immortal-remote._tcp` for the multi-device phone remote. It creates a new `ResolveListener`
  for each resolve, because `NsdManager` rejects a reused one. Source:
  `immortal/RemoteDiscovery.kt:19-31,121-124`; `immortal/docs/features/remote.md:28-30`. There
  is no evidence of Portal-specific NSD quirks beyond the multicast lock.
- **[V G2]** The advertised name must not be hardcoded. The old fork baked in "Portal Plus", so
  every device on a LAN advertised the same name. portal-receiver-prototype seeds it from `Build.MODEL`
  instead (`receiver/app/.../AirPlayApp.kt:29-44`). Immortal's device name is
  `FleetConfig.name`, which defaults to `Build.MODEL` (`immortal/FleetConfig.kt:51`). PR #170
  re-registered mDNS on rename (`PR170/docs/features/airplay.md:24-28`).
- **[R]** The sender and the Portal must be on the same subnet, because mDNS does not cross
  subnets (`receiver/README.md`, "Known limits"). Some routers have multicast quirks, so allow a
  manual fallback where possible (`immortal/docs/design/multi-room-audio.md:343-344`).
- **[I]** Untested: NSD re-announcement after a Wi-Fi reconnect or a DHCP address change, and
  name-collision renaming (NsdManager appends " (2)"). Both matter for a receiver that runs for
  days.
- **Ports [V code]:** the receiver listens on 7000 by default
  (`PR170/docs/features/airplay.md:71`). Immortal's fleet agent uses 8723
  (`immortal/FleetConfig.kt:37`), so they do not clash.

---

## 5. MediaCodec H.264 / H.265 decoders

| Device | AVC | HEVC | Evidence |
|---|---|---|---|
| G2 (`omni`) | `OMX.qcom.video.decoder.avc` | `OMX.qcom.video.decoder.hevc` | **[V]** from a decoder-fault log, `PR170/docs/features/airplay.md:40-58` |
| G1 (`aloha`) | expected | unknown | **[R]** mirroring reported working (PR #170 body); "has not shown" the G2 fault (`airplay.md:56`); no codec list recorded |
| TV (`ripley`) | unknown | unknown | nothing recorded |

- **[V G2]** Under rapid decoder restarts (YouTube pre-roll ads cycle mirror -> video -> mirror)
  the Qualcomm decoder faults: `OMX_COMPONENT_GENERATE_HARDWARE_ERROR`, `ACodec ERROR(0x80001009)`.
  `VideoRenderer` catches it and resets, and the picture comes back. This happens with H.264 too,
  so turning H.265 off does not avoid it. Source: `PR170/docs/features/airplay.md:40-58`.
- **[V code]** The receiver picks HEVC only if some decoder lists `video/hevc`. It caps the
  advertised resolution at the smallest decoder limit, assuming 1920x1080 when the limit is
  unknown. If the hardware decoder rejects the configuration, it falls back to a software
  decoder. Source: `receiver/airplay/.../renderer/VideoRenderer.kt:184-193,289-310`;
  `receiver/.../AirPlayService.kt:345,378-384`.
- **[D/V code]** On Portal API levels: `KEY_LOW_LATENCY` needs API 30, so it is never set.
  `KEY_ALLOW_FRAME_DROP` needs API 29, so it is G2 only. Source:
  `receiver/.../VideoRenderer.kt:176-181`.
- **[V G1/G2/TV, per comment]** No Portal has a hardware `audio/alac` decoder. ALAC is decoded in
  software by a minimal static FFmpeg. Source: `receiver/airplay/UPSTREAM.md:99-103`.
- **[V G2]** DRM content (Apple TV app, Netflix) will not mirror. That is a protocol decision,
  not a decoder limit (`receiver/README.md`, "Known limits").
- **[R G1]** G1 is memory-constrained: a full-resolution decode of a 4K image runs out of memory
  (`immortal/NotificationOverlay.kt:299-303`). **[I]** Keep the advertised mirroring resolution
  conservative on G1.
- Hardware *encode* (not needed here) is confirmed on a Portal Go, for reference:
  `immortal/docs/design/camera-streaming.md:224-228`.

---

## 6. Audio output, volume and focus

### 6.1 Output path

- **[V code]** Audio goes out through Oboe in shared mode with `ContentType::Music`. The default
  is `PowerSaving` + `Usage::Media`. The low-latency option switches to `Usage::Game` (off by
  default). Source: `receiver/airplay/src/main/cpp/audio_output.h:130-148`;
  `receiver/airplay/.../Prefs.kt` (`DEF_LOW_LATENCY = false`).
- **[D]** AAudio is available from API 27, so Oboe uses AAudio on every Portal (comment in PR #170
  diff, `gradle/libs.versions.toml`).

### 6.2 The Portal volume quirk

- **[V G2, Portal+ / Android 10]** On touch Portals the "media volume" slider drives one linked
  group of seven streams: SYSTEM, RING, MUSIC, NOTIFICATION, SYSTEM_ENFORCED, DTMF and TTS. Only
  `STREAM_VOICE_CALL` and `STREAM_ALARM` are independent. Source:
  `immortal/docs/design/mqtt-notifications.md:155-168`; `immortal/SoundPlayer.kt:24-29,70-75`.
- **[V TV]** On Portal TV, `isVolumeFixed()` returns false, and `setStreamVolume(STREAM_MUSIC)`
  moves and reads back the index. But HDMI plays at full scale whatever the index is, and
  `adjustStreamVolume` from an app is silently dropped (the same call from `adb shell` works).
  The audible volume path is the IR blaster to the TV, which only system key events reach.
  Immortal therefore treats any device with an HDMI output as fixed-volume. Source:
  `immortal/MqttPublisher.kt:605-622,701-705`.
  **[I]** On TV, the sender's AirPlay volume can only work as software gain inside the Receiver.

### 6.3 Initial volume

- **[V code]** The pinned receiver applies the sender's volume as software gain
  (`10^(dB/20)`, mute at -144) and starts at gain 1.0. It never touches `STREAM_MUSIC`. Source:
  `receiver/airplay/.../renderer/AudioRenderer.kt:12,91-101`.
- **[R]** "Every time I connect via AirPlay, the receiver volume is set to the maximum"
  ([upstream issue #36](https://github.com/jqssun/android-airplay-server/issues/36)). Upstream
  closed it on 2026-10-19 with two-way sync between the sender volume and the device volume.
  The commits are `85338d9` (2026-08-03, a `VOLUME_CHANGED_ACTION` listener plus UxPlay patch
  0006, "deliver volume while audio stream paused") and `779c822` (2026-10-19, a
  `sync_client_volume` preference and an `initialVolume` reported in `/info`). Both postdate the
  `b9a590f` pin.
- **[I]** On touch Portals, syncing the AirPlay volume to `STREAM_MUSIC` also moves system, TTS
  and notification volume (see 6.2), which Immortal's spoken-time TTS uses. On TV it does nothing
  audible. The design needs a per-device-class policy.

### 6.4 Audio focus and other audio on the device

- **[V code]** The pinned receiver requests no audio focus. `AirPlayService` never calls
  `requestAudioFocus`, and `ExoPlayer.Builder(context).build()` is created without audio
  attributes, so ExoPlayer's focus handling is off. Source: `receiver/.../AirPlayService.kt`
  (no matches for "focus"); `receiver/.../renderer/AirPlayVideoPlayer.kt:74-77`.
- **[V code]** In PR #170, Immortal took focus on the Receiver's behalf (`AUDIOFOCUS_GAIN`,
  ignoring changes) and stopped `MultiRoomService` while any session had audio. It handed both
  back after a 5 s grace period so the mirroring -> video handover would not cause an audible
  gap. Source: `PR170/app/.../AirPlayControl.kt:281-335`;
  `PR170/airplay/.../AirPlaySession.kt:31-39`.
- **[V code]** `MultiRoomService` is only the now-playing relay. The synced audio is played by
  the separate stock Snapcast app (`de.badaix.snapcast`). Stopping the relay does not stop the
  audio. Source: `immortal/MultiRoomService.kt:26-37,311`;
  `immortal/docs/design/multi-room-audio.md:107-110,350-366`.
- **[I]** Whether the stock Snapcast app pauses on `AUDIOFOCUS_LOSS` is unverified. The multi-room
  design lists audio-focus handling as companion work still to be built
  (`multi-room-audio.md:119-123,382-386`).
- **[V code]** Immortal's MQTT notification sounds request `AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK`
  on the alarm stream, so music ducks (`immortal/SoundPlayer.kt:136-152`). A Receiver that holds
  no focus will not be ducked by that request (**[I]**).
- **[I]** Calls: the Portal's calling apps take `STREAM_VOICE_CALL`. How they claim the output
  ("politely or seizing") is listed as a test in `multi-room-audio.md:121-123`; no result is
  recorded.

---

## 7. How Immortal finds out about and controls other apps today

These are the precedents the Contract can build on.

### 7.1 Inbound: Immortal observing other apps

| Mechanism | What it does | Source |
|---|---|---|
| **MediaSession via notification listener** | `MediaSessionReader` reads every active session (`getActiveSessions`, gated on being an enabled notification listener, which provisioning grants with `cmd notification allow_listener`). It prefers a PLAYING session from another app over Immortal's own relay and publishes it to `NowPlayingHub`. That feeds the home mini-player, the screensaver card and the phone remote. Transport goes back through `MediaController.transportControls`. | `immortal/MediaSessionReader.kt:22-35,70-84,102-112,160-166`; `immortal/NowPlayingHub.kt:13-63`; `immortal/MediaNotificationListenerService.kt:12-22`; `immortal/RemoteMedia.kt:11-17`; `immortal/provisioning/provision.sh:341-346` |
| **Package presence** | `QUERY_ALL_PACKAGES` plus `getPackageInfo` checks, for example showing the multi-room row only when Snapcast is installed, or finding Millennium. | `immortal/app/src/main/AndroidManifest.xml:17-25`; `immortal/ImmortalSettingsActivity.kt:241-247`; `immortal/HomeActivity.kt:1830-1839` |
| **Network protocols, not app IPC** | Snapcast metadata comes from snapserver JSON-RPC, and transport goes to Music Assistant's WebSocket. Immortal never talks to the Snapcast *app*. | `immortal/MultiRoomService.kt:26-37`; `immortal/docs/design/multi-room-audio.md:350-366` |
| **System broadcasts** | The DREAMING_STARTED/STOPPED, SCREEN_OFF, USER_PRESENT and POWER receivers drive `PresenceHub` and `DreamPolicy`. | `immortal/ImmortalApp.kt:35-57`; `immortal/PresenceState.kt:180-205` |

- **[R]** "NowPlaying is free": the Receiver's `MediaSessionCompat` should appear in Immortal
  with no extra code (`receiver/IMMORTAL-PORT.md:209-211`). This is listed as "verify rather than
  build" and was never recorded as verified. Note that the pinned receiver activates its session
  only in audio-only or video-playback modes, not during plain mirroring
  (`receiver/.../AirPlayService.kt:545-556,679-697`).

### 7.2 Outbound: Immortal sending to other apps

| Mechanism | Shape | Source |
|---|---|---|
| **`com.immortal.launcher.PRESENCE`** | An implicit, unprotected broadcast with extras `presence`, `screen`, `confident`, `sinceMs` and `source`. Written for the GPL Snapcast companion, and explicitly described as the "intent-only" licensing boundary. | `immortal/PresenceState.kt:127-141,298-311`; `immortal/docs/design/multi-room-audio.md:298-300` |
| **`com.millennium.TRIGGER_ASSISTANT`** | An explicit-package broadcast protected by a `signature` permission that **the sender (Immortal) defines**, so only Immortal-signed apps can fire it at Millennium, which is signed with a different key. | `immortal/HomeActivity.kt:1827-1843`; `immortal/app/src/main/AndroidManifest.xml:90-98` |
| **Launch intents** | `getLaunchIntentForPackage` + `NEW_TASK` for boot launches, and the MQTT/fleet "open app" commands. | `immortal/BootLaunch.kt:53-63` |
| **Media key dispatch** | `dispatchMediaKeyEvent(KEYCODE_MEDIA_PAUSE)` to whatever session is active, when "Sleep" fires with pause-audio on. | `immortal/SleepScheduler.kt:315-319,364-381` |
| **Accessibility key filter** | `RemoteKeyService` swallows the TV remote's PROG_* and SEARCH keys when the user maps them. | `immortal/RemoteKeyService.kt:18-46,59-81` |

- **[V code]** Immortal exports no receiver or service that accepts commands from third-party
  apps. Its only exported receivers are `BootReceiver` and the device-admin receiver
  (`immortal/app/src/main/AndroidManifest.xml:427-460`). **The Contract needs a new exported
  entry point on the Immortal side**, for example to receive "session started" and "raise me".
  It will need a protection scheme, such as the sender-defined signature permission above or an
  explicit-package check.

---

## 8. Screensaver, sleep and chimes vs a third-party full-screen session

- **[V G1/G2]** Meta's power manager force-wakes a running dream after a set time, and
  `DreamPolicy` reacts to `ACTION_DREAMING_STOPPED`. If the screen is still interactive and
  neither a recent user tap nor a Calls handoff explains the stop, the verdict is **REDREAM**,
  and Immortal relaunches `PhotoFramePreviewActivity` with `NEW_TASK | SINGLE_TOP` over
  whatever is in front. Source: `immortal/DreamPolicy.kt:17-37,161-193`;
  `immortal/PresenceState.kt:85-123`.
- **[V G2, per PR rationale]** A cast Activity coming forward stops the dream. That reads as
  REDREAM, so the frame would land on top of the cast. The prototype added the in-memory flag
  `DreamPolicy.suppressFrame`, set by `AirPlayActivity`, to skip the relaunch. Source: PR #170
  diff, `DreamPolicy.kt` hunks `@@ -68` and `@@ -177`; `PR170/app/.../AirPlayActivity.kt:94-99,290-291`.
  **An out-of-process Receiver cannot set this flag.** Immortal has to learn about the session
  over the Contract.
- **[V code]** The existing suppression precedent is the Calls handoff (`markBridge` /
  `inStockHandoff`). It is persisted with `commit()` so that a freshly spawned Immortal process
  still suppresses the relaunch. Source: `immortal/DreamPolicy.kt:47-111`. **[I]** A Contract
  signal should survive an Immortal process restart in the same way.
- **[V code]** Other Immortal behaviour that would cut into a cast:
  - **Idle sleep:** an alarm armed when the screensaver starts (`SleepScheduler.kt:113-120`)
    calls `lockNow()` when it fires (`:162-165`). It is cancelled only when the user returns to
    Immortal's launcher (`:127-133`). **[I]** A cast started from the screensaver leaves this
    alarm armed and could blank the screen mid-session.
  - **Overnight window:** at the window start Immortal blanks the screen or launches the night
    clock (`SleepScheduler.kt:353-362`).
  - **Sleep now** (from MQTT, the remote or a tile) dispatches MEDIA_PAUSE, which the Receiver's
    MediaSession would turn into a DACP pause to the sender. It also sends a "close current app"
    intent and runs `lockNow()` (`SleepScheduler.kt:315-319,364-392`).
- **[V code]** Chimes play on `USAGE_ALARM` with `MediaPlayer` and request no focus. They are
  audible over media, use their own volume, and respect quiet hours, but they do not check
  whether media is playing. Source: `immortal/ChimePlayer.kt:21-35`;
  `immortal/ChimeReceiver.kt:16-39`. **[I]** An hourly chime will sound over a mirroring
  session or music unless Immortal suppresses it while a session is active.
- **Design intent [R]:** audio-only sessions stay headless, the screensaver keeps running, and
  the track appears on the now-playing card (`receiver/IMMORTAL-PORT.md:207-208`;
  `PR170/docs/features/airplay.md:13`).

---

## 9. Portal TV specifics

- **[V TV]** The stock TV home (`ripleyhome`) lists only apps with a `LEANBACK_LAUNCHER`
  category, and shows them with a 320x180 banner. It *hides* apps that also carry
  `CATEGORY_HOME`. Source: `immortal/app/src/main/AndroidManifest.xml:113-156`. portal-receiver-prototype
  already declares `LEANBACK_LAUNCHER` and a banner, with `leanback`/`touchscreen`/`faketouch`
  marked not required (`receiver/app/src/main/AndroidManifest.xml:16-18,33,44-48`).
- **[V TV]** The remote is a Bluetooth HID device (vendor 0x1915, product 0xeeee). Netflix sends
  `KEYCODE_PROG_RED`, Prime `PROG_GREEN`, Watch `PROG_BLUE`, and Voice `KEYCODE_SEARCH` (Meta's
  layout crosses green and blue). Immortal can remap these through `RemoteKeyService` (an
  accessibility key filter, opt-in, default "Nothing"). Source: `immortal/RemoteKeyService.kt:18-46`;
  `immortal/docs/features/portal-tv.md:11-58`. D-pad, Back and Home are standard. **[I]** Media
  transport keys on the remote are not documented.
- **[V TV]** No touch. Every interactive element needs D-pad focus with a visible ring. Immortal's
  `TvFocus` (`tvFocusable`, `rememberInitialFocus`) is its pattern (`immortal/TvFocus.kt:33-119`;
  `immortal/docs/features/portal-tv.md:7-9`). portal-receiver-prototype ships its own `ui/TvFocus.kt` and
  `ui/Tv.kt` (file list at `42694bb`). Neither has been verified on a TV.
- **[V TV]** Chrome renders blank on the TV and cannot be driven by the remote
  (`immortal/Curation.kt:40-48`). **[I]** Avoid WebView-based UI in the Receiver.
- **[V TV]** Volume: see 6.2. Only software gain is audible.
- **[R TV]** Store listings can be restricted with `devices: ["tv"|"touch"]`
  (`immortal/SUBMISSIONS.md:56`). A Receiver for every Portal omits the field.
- **[I TV]** Unknown: the HDMI output mode (720p, 1080p or 4K) that `Display.mode` reports, which
  sets the advertised mirroring resolution (`receiver/airplay/.../Display.kt:7-13`); the decoder
  list; and whether the Receiver has *ever* run on a Portal TV. No source records a TV test.

---

## 10. Install and update through Immortal's Store

| Requirement | Detail | Source |
|---|---|---|
| Single APK | The store and headless installer write one `base.apk` per PackageInstaller session, so split APKs cannot install. Ship one universal arm64 APK. | `immortal/PackageInstallSessions.kt:29`; `immortal/HeadlessInstaller.kt:74-76` |
| `minSdk` <= 28 | The store disables install and shows "Needs Android X+" below `minSdk`. G1 and TV are API 28. | `immortal/StoreCatalog.kt:133-143`; `immortal/SUBMISSIONS.md:68-71` |
| arm64 | Every Portal is arm64. Pin `versionCode` if publishing per-ABI builds. | `immortal/SUBMISSIONS.md:73-74` |
| Catalog entry | `name`, `packageName`, `source: "url"`, `apkUrl` (https, stable `releases/latest/download/...`), `versionUrl` (a JSON file with `versionCode`, read live, so no catalog edit per release), `minSdk`, `description` (under 120 chars), optional `longDescription`, `iconUrl`, `author`, `homepage`, `submittedBy`, `devices`. CI checks schema and URLs with `scripts/validate_catalog.py --network`. Example: PortalSnap under "Portal Originals". | `immortal/SUBMISSIONS.md:36-66`; `immortal/StoreCatalog.kt:173-199`; `immortal/catalog.json:357-370`; `immortal/scripts/validate_catalog.py:23-24,92-138` |
| PNG icon | Portal's launcher cannot render adaptive-icon XML, so an app with only `mipmap-anydpi-v26` shows a blank icon. Keep `mipmap-*dpi` PNGs (at least xxxhdpi). The catalog `iconUrl` should be an https PNG. | `receiver/CLAUDE.md` ("Invariants easy to break"); `receiver/IMMORTAL-PORT.md:132-133`; `immortal/SUBMISSIONS.md:50-52` |
| Same signing key | Android only updates in place when the signature matches. Pick the release key once. (Immortal states the same rule for itself.) | `immortal/AGENTS.md:197-199`; `immortal/UpdateManager.kt:35` |
| G1 installer | The G1 stock installer dialog is unreadable (white on white) unless the provisioning kit's overlay fix is applied. Without the fix the store shows "installs paused". | `immortal/docs/first-gen-portals.md:6-25`; `immortal/InstallDaemon.kt:15-31,51-58` |
| Cleartext HTTP | AirPlay video serves HLS over plain http from the native server on localhost, so the app must set `android:usesCleartextTraffic="true"`. | `receiver/airplay/src/main/AndroidManifest.xml:9-11`; `receiver/IMMORTAL-PORT.md:87-91` |
| First launch | A one-tap install leaves the app stopped, with no boot start (2.1). | Android 3.1 docs |

---

## 11. Known traps

| Trap | Status for a standalone Receiver | Devices | Source |
|---|---|---|---|
| **Dexopt at boot**: install then reboot within seconds, and `BOOT_COMPLETED` is missed. | Still applies. | **[V G2]** | `receiver/IMMORTAL-PORT.md:276-278` |
| **media3 version clash**: Immortal pins media3 1.5.1 for `VideoTranscoder`; the module needed 1.11.0-beta01; Gradle resolves one version per APK. Two Transformer defaults changed along the way (HDR metadata in 1.6.0, the muxer in 1.10.0). | **Gone.** It only existed because of in-process bundling; separate APKs carry their own media3. | build | `receiver/IMMORTAL-PORT.md:117-120`; PR #170 diff, `gradle/libs.versions.toml` |
| **ProGuard / JNI names**: native code resolves callbacks by name (`GetMethodID`) and `Java_io_github_jqssun_airplay_bridge_NativeBridge_*` symbols. R8 renaming gives a library that loads and then fails silently (black screen, no audio). Renaming the package breaks loading (`UnsatisfiedLinkError`). | Still applies to the Receiver's own release build. Upstream keeps adding callbacks (for example `onClientVolume`, `onClientVolumeQuery` in `779c822`), so keep rules must cover whole interfaces. | build | `receiver/airplay/consumer-rules.pro:1-17`; `receiver/airplay/UPSTREAM.md:22-25` |
| **Unstripped `.so`**: without `ndkVersion` in the *app* module, AGP cannot find `llvm-strip` and ships unstripped libraries (19 MB instead of 8 MB). | Still applies. | build | PR #170 diff, `app/build.gradle.kts` hunk `@@ -28` |
| **NDK in CI**: AGP resolves the NDK while *configuring* a module with `externalNativeBuild`, so even JVM unit tests need it installed. (This contradicts `IMMORTAL-PORT.md:134-137`; PR #170 verified the failure.) | Still applies. | build | PR #170 diff, `.github/workflows/tests.yml` |
| **`c++_shared` STL**: Oboe's prefab refuses a static STL (`CXX1212`). | Still applies if Oboe is kept. | build | `receiver/IMMORTAL-PORT.md:121-122` |
| **UxPlay must be a git checkout**: patches are applied with `git -C` at configure time. | Applies if UxPlay is kept (the library choice is open). | build | `receiver/airplay/UPSTREAM.md:79-83` |
| **Mirroring -> AirPlay-video handover**: YouTube starts as mirroring (`Video size 370x800`), then mirroring stops, `video_reset 5`, and `AirPlay Video play: http://localhost:7000/master.m3u8`. The gap is about 1 s, and all the "video" flags are false during it. A surface or speaker-ownership teardown on "video ended" breaks the session; the prototype waits 5 s. | Still applies, and now crosses the Contract: any Immortal reaction to a session ending must be debounced too. | **[V G2]** | `receiver/IMMORTAL-PORT.md:193-205`; `PR170/airplay/.../AirPlaySession.kt:14-39` |
| **One Surface for two producers**: sharing a Surface between MediaCodec (mirror) and ExoPlayer (HLS) left the old producer's frames composited under the new one. Use a fresh `SurfaceView` for each. Resizing the `SurfaceView` forces a decoder rebuild, so letterbox by scaling the view instead. | Still applies. | **[V G2]** | `PR170/app/.../AirPlayActivity.kt:179-240` |
| **Session-end detection**: senders can abandon a session without signalling. Upstream PR #22 (watchdog) is **still open** as of 2026-10-23; local UxPlay patch 0005 covers abandoned play connections. | Still applies. | **[R]** | `receiver/airplay/UPSTREAM.md:123-125`; `gh pr view 22 -R jqssun/android-airplay-server` |
| **Start without `ACTION_START_SERVER`**: the process is killed for never calling `startForeground`. | Applies only if the upstream service is reused. | **[V code]** | `receiver/IMMORTAL-PORT.md:74-80` |
| **Codec churn fault on G2** | See section 5. | **[V G2]** | `PR170/docs/features/airplay.md:40-58` |
| **Upstream drift**: since the `b9a590f` pin, upstream has added volume sync, codec reset with session (`c7056cd`), decoder changes (`a54a4fb`, `a46cca0`), orientation detection and resolution changes. | Matters for the library-choice ticket. | n/a | `gh api repos/jqssun/android-airplay-server/commits` |

---

## 12. Gaps that need on-device testing

1. **G1 (`aloha`) end to end.** PR #170 reports it works, but nothing is logged. Needed: boot
   start, NSD registration, the codec list (`MediaCodecList` dump), HEVC, mirroring and the
   handover.
2. **Portal TV (`ripley`) end to end.** There is no record the Receiver has ever run on a TV.
   Needed: the Leanback tile, D-pad UI, HDMI display mode and advertised resolution, the codec
   list, volume as software gain, and remote keys during a session.
3. **G2 background start without a `SYSTEM_ALERT_WINDOW` grant.** Which of the four routes in 3.2
   actually raises the Receiver's surface on a Portal? Does Portal Settings expose "Display over
   other apps"?
4. **Stopped state after a Store install.** Confirm there is no boot start until the first
   launch. Decide who does that first launch.
5. **Snapcast and audio focus.** Does the stock Snapcast app pause on focus loss, or does the
   Contract need another means of Speaker ownership?
6. **NowPlaying through Immortal.** Does the Receiver's session reach `NowPlayingHub` for audio,
   mirroring and AirPlay video? Does transport round-trip through DACP?
7. **Immortal interference.** Check the idle-sleep alarm, overnight window and chimes during a
   cast, and REDREAM after a cast ends.
8. **Wi-Fi.** First-connect latency with the screen off and no Wi-Fi lock, NSD after a
   reconnect, and Doze on a Portal Go on battery.
9. **Codec lists for the other G2 models** (Portal+ Gen2, Mini, Go), plus the decoder-churn fault
   on each.
