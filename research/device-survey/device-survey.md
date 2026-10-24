# Device survey (#12)

What each Portal model can actually do as a receiver, measured on real hardware with the old prototype build as the probe (`com.portal.receiver` 0.0.16, jqssun-based; a measuring instrument, not a base). One section per model. `collect.sh` in this folder gathers the non-interactive part from any Portal over adb; the interactive tests need a Sender and a person.

## Models

| Model | Codename | Android | Available | Status |
| --- | --- | --- | --- | --- |
| Portal 10" (Gen2) | `omni` | 10 (API 29) | yes, USB to the survey Mac | non-interactive part done |
| Portal+ (Gen1) | `aloha` | 9 (API 28) | yes, on another machine | not started |
| Portal TV | `ripley` | 9 (API 28) | yes, Wi-Fi adb, on another machine | not started |
| Portal+ (Gen2), Mini, Go | | 10 | not available | won't be surveyed |

A "Portal+" receiver is also advertising on the survey LAN (192.168.86.74, `Android-2.local`) running the probe; it has no adb over Wi-Fi.

## Portal 10" (Gen2, `omni`)

Measured 2026-10-24. Build `Facebook/omni_prod/omni:10/QKQ1.210213.001/3051355900018050:user/prod-keys`, Qualcomm `qcs605`, ABIs `arm64-v8a,armeabi-v7a,armeabi`.

### Decoders

From the vendor codec configs (`/vendor/etc/media_codecs*.xml`). Both the generic `media_codecs.xml` and the SoC-specific `media_codecs_qcs605_v0.xml` are present; which one the media server loads isn't visible without a probe app calling `MediaCodecList`, so both limits are given.

| Type | Hardware decoder | Max size | Max frame rate |
| --- | --- | --- | --- |
| HEVC | `OMX.qcom.video.decoder.hevc` (+ `.secure`) | 4096x2160 (generic) / 4096x2304 (qcs605) | 240 / 480 |
| AVC | `OMX.qcom.video.decoder.avc` (+ `.secure`) | 4096x2160 / 4096x2304 | 240 / 480 |
| VP9 | `OMX.qcom.video.decoder.vp9` | 4096x2160 / 4096x2304 | 240 / 480 |
| VP8 | `OMX.qcom.video.decoder.vp8` | 3840x2160 / 4096x2304 | 240 |

So **hardware HEVC is present**, well above anything a Sender will send this panel. Software fallbacks: `OMX.google.*` / `c2.android.*` for AVC, HEVC, VP8, VP9. Audio: Google AAC (`audio/mp4a-latm`), MP3, FLAC (plus `OMX.qti.audio.decoder.flac`), Opus, Vorbis, raw. **No ALAC decoder**, which confirms #6's FFmpeg ALAC fallback is needed.

### Display

Panel 800x1280 at 60 Hz, 160 dpi, one mode, `BUILT_IN`: natively **portrait**. As surveyed it stood landscape: `mCurrentRotation=ROTATION_90`, logical 1280x800, with auto-rotate on (`accelerometer_rotation=1`), so the logical size changes when someone turns the Portal. `dumpsys display`'s `mBaseDisplayInfo` (rotation 0, 800x1280) is the unrotated base and is the wrong number to advertise. See Test 2b.

### Start at boot

**Passes.** After `adb reboot`, `sys.boot_completed` came up at 14:51:25 and the receiver's process started in the same second, from `BootReceiver` (`am_proc_start ... broadcast, {com.portal.receiver/io.github.jqssun.airplay.BootReceiver}`), with no manual launch. The foreground service was running and both adverts were back within 14 s. (The app had been launched by hand before, as #4 says it must be.)

### Advertising

`NsdManager` registration works for **both** `_airplay._tcp` ("Portal") and `_raop._tcp` ("A40E2B56E4B0@Portal"), browsed from a Mac on the same LAN, before and after reboot.

### Volume

One `KEYCODE_VOLUME_UP` moved `STREAM_MUSIC`, `STREAM_NOTIFICATION`, `STREAM_RING`, `STREAM_SYSTEM`, `STREAM_SYSTEM_ENFORCED` and `STREAM_ACCESSIBILITY` together (speaker index 5 -> 6; accessibility 6 -> 7). Only `STREAM_ALARM` (15) stayed put. `mUseFixedVolume=false`. So the device volume is effectively one master volume: turning a Session down also turns down notifications and anything speaking on MUSIC or ACCESSIBILITY (TTS). Input for #15.

### Test 1: audio-only Session (iPhone 13, iOS 27.0.1, Apple Music)

Trace: [`traces/omni/audio-session-pause.log`](traces/omni/audio-session-pause.log) (receiver and Immortal lines only, times relative to connect, LAN addresses masked).

- **Audio end to end works.** ALAC (`ct=2 spf=352`), sound from the Portal; connect to first `Track:` metadata 2.6 s. The Session ended cleanly when the Sender switched output back to the iPhone (`Client disconnected (0)`, Immortal's now-playing cleared in the same millisecond).
- **Now-playing works.** The receiver's MediaSession was the only session, Immortal chose it (`chosen=com.portal.receiver state=3`) and showed artist and title. Volume keys during the Session went to the receiver's MediaSession, which plays locally, so they moved the Portal's own music volume.
- **Play/pause reaches the Sender** (the iPhone paused and resumed) **but the state flickers back.** The first press showed play -> pause -> play while the music had in fact paused. In the trace every pause that bounced back is followed about 300 ms later by a `Track:` metadata (and progress) update from the Sender, and the probe republishes `PLAYING`:

  ```
  21.922  now-playing: PAUSED
  22.214  AirPlayService: Track: Austin Wintory - Apotheosis
  22.234  now-playing: PLAYING
  ```

  The pauses with no update after them (35.8, 43.0) stayed paused. Cause in the probe: `onProgress` sets `_playing = true` unconditionally (`AirPlayService.kt:675` in the prototype), and `togglePlayPause` flips a local guess. **Lesson for the new Session (#6):** "playing" must come from the Sender's real transport state (RECORD/FLUSH and whether audio is flowing), never be inferred from progress or metadata, and a locally initiated play/pause is only optimistic until the Sender confirms it. This trace is the fixture for that.

### Test 2: mirroring with the probe as installed (nothing rendered)

The Session ran (`mirror running: 1`, hardware HEVC `OMX.qcom.video.decoder.hevc` started 0.7 s after connect, audio `ct=8` AAC-ELD alongside) but nothing appeared, because this probe build had `launch_on_connect=false`: it was built to wait for Immortal to raise its surface, and the Immortal on this Portal has no such integration. No activity start was attempted. A probe setting, not a platform result.

### Test 2b: mirroring with launch-on-connect on

Trace: [`traces/omni/mirroring-launch-rotation.log`](traces/omni/mirroring-launch-rotation.log).

- **The Receiver can raise its own surface from the background on Gen2, given the overlay permission.** 21 ms after connect: `Background activity start for com.portal.receiver allowed because SYSTEM_ALERT_WINDOW permission is granted.` The probe had `SYSTEM_ALERT_WINDOW` granted (`appops`: allow). Decoder started at 0.35 s; picture appeared quickly and was smooth and responsive. Input for #13, which asks about the route *without* that permission; this measures the route with it.
- **MediaCodec straight to the display Surface is enough** for portrait-shaped content: no extra rendering stage was needed for it.
- **Rotation: the Sender never sent a landscape stream.** Turning the iPhone sideways (portrait and landscape videos in Photos) didn't change the Portal's picture. The stream only alternated between 592x1280 (the phone's screen fitted to height) and 800x1280 (video playing), both portrait, because the probe advertised the **unrotated panel size, 800x1280**, while the Portal stood landscape at 1280x800. The Sender fits whatever it shows into the frame the receiver advertises. **Lesson:** advertise the display at its current logical size (rotation applied) at Session start. Because Gen2 auto-rotates, a rotation during a Session can't be renegotiated mid-stream. It needs either a fixed orientation for the Surface during a Session or a re-advertise on the next Session (to decide in the UI and Surface work).

### Tests 2c and 2d: what to advertise

The probe was switched off `auto_res` to a fixed advertised size, then mirrored again with the same steps. Traces: [`mirroring-advertised-1280x720.log`](traces/omni/mirroring-advertised-1280x720.log), [`mirroring-advertised-1280x800.log`](traces/omni/mirroring-advertised-1280x800.log).

| Advertised | Phone upright | Video playing | Codec the iPhone chose | What the Portal showed |
| --- | --- | --- | --- | --- |
| 800x1280 (2b, `auto_res`) | 592x1280 | 800x1280 | HEVC | portrait frame: landscape video tiny |
| 1280x720 (2c) | 334x720 | 1280x720 | H.264 | landscape video landscape; thin bars (16:9 on 16:10), portrait video softer |
| **1280x800 (2d)** | 370x800 | 1280x800 | H.264 | **landscape and portrait video both look great** |

- **The phone's own rotation never matters.** In every run the frame only changed when a video started or stopped, never when the phone was turned: the Sender fits whatever it shows into the advertised frame. With the right advertisement, no rotation or scaling stage is needed on Gen2, and MediaCodec straight to the Surface is enough (#6).
- **Advertise the exact logical display size at the current rotation**, here 1280x800.
- **Codec depends on the advertisement.** The iPhone sent HEVC only when the advertised frame was 1280 tall, and H.264 at 720 and 800 tall. Hypothesis: iOS uses HEVC only above 1080p. Either way the Receiver can't count on HEVC and must handle both (both have hardware decoders here).

The probe was left advertising 1280x800 with launch-on-connect on for the remaining tests.

### Test 3: YouTube Handover and ad breaks

Trace: [`traces/omni/youtube-handover-ads.log`](traces/omni/youtube-handover-ads.log) (times relative to connect). Probe advertising 1280x800.

- **The Handover works.** Mirroring stops (`mirror running: 0`, `video_reset 5` = `RESET_TYPE_RTP_TO_HLS_TEARDOWN`) and about 2.1 s later the Sender issues `video_play: http://localhost:7000/master.m3u8`, played through ExoPlayer (HLS). Skipping ads, pause and resume, and seeking all worked. **No ad-break decoder fault** was seen on this build.
- **Each ad and each video is its own play.** The Sender stops one HLS item, briefly returns to mirroring (`Mirror mode`, new mirror codec), and then sends the next `video_play`, 2.2-2.4 s between items. The "Session" spans all of them.
- **Bug: the Session drops if an item ends on the Portal before the Sender moves on.** The user let a video end and started a new one. Its first ad played to the end, and the connection dropped before the second ad loaded:

  ```
  68.259   video_play: http://localhost:7000/master.m3u8 @ 0.00s     <- first ad of the new video
  107.086  AirPlay Video stopped (player)                            <- ExoPlayer hit end-of-stream; probe stops the player
  107.496  video_reset 2                                             <- RESET_TYPE_HLS_SHUTDOWN
  107.497  Client disconnected (4) ... (3) ... (2) ... (1)           <- every connection closed
  ```

  In every transition that worked, the Sender stopped the item itself ("AirPlay Video stopped" without "(player)") and then sent the next one. Here the local player reached end-of-stream first. The probe's `onEnded` called `_endVideoPlayback` (`AirPlayService.kt:277`), which stops the player. The Sender's next `/playback-info` poll then got `duration == -1`, which UxPlay treats as "video has finished, reset": it marks the response to disconnect and resets with `RESET_TYPE_HLS_SHUTDOWN` (`lib/http_handlers.h:391-398` in UxPlay 1.73.7). That tears down the Sender's whole connection, so the queued second ad never arrives. **Lessons:**
  - For the Session (#6), the end of an HLS item on the Portal is not the end of the Session. The Sender owns the queue: on local end-of-stream the Receiver keeps reporting the finished item (position = duration, rate 0) and waits for the Sender's next `/play` or `/stop`, inside #6's grace window.
  - For the engine patch series, `/playback-info` must never answer `duration -1` while the Sender's item is still current. This is a candidate patch to `patches/uxplay/`, alongside the inherited 0001-0005, and is worth offering upstream.
  - This trace is the fixture for it.

### Still to do (needs a Sender)
- Whether stock Snapcast pauses on losing audio focus.
- First-connect delay to a sleeping Portal; discovery after a Wi-Fi reconnect.
- Rotation and scaling: portrait iPhone mirroring, landscape video.
- Device traces: YouTube Handover, YouTube ad break, Sender screen lock mid-Session, Sender out of Wi-Fi range, audio-only Session ending.
