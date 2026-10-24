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

800x1280 at 60 Hz, 160 dpi, one mode, `BUILT_IN`, rotation 0 as reported. The panel is natively **portrait**; the landscape UI is a rotation on top. Whether video needs its own rotation or scaling stage is still to be checked with a mirroring Session.

### Start at boot

**Passes.** After `adb reboot`, `sys.boot_completed` came up at 14:51:25 and the receiver's process started in the same second, from `BootReceiver` (`am_proc_start ... broadcast, {com.portal.receiver/io.github.jqssun.airplay.BootReceiver}`), with no manual launch. The foreground service was running and both adverts were back within 14 s. (The app had been launched by hand before, as #4 says it must be.)

### Advertising

`NsdManager` registration works for **both** `_airplay._tcp` ("Portal") and `_raop._tcp` ("A40E2B56E4B0@Portal"), browsed from a Mac on the same LAN, before and after reboot.

### Volume

One `KEYCODE_VOLUME_UP` moved `STREAM_MUSIC`, `STREAM_NOTIFICATION`, `STREAM_RING`, `STREAM_SYSTEM`, `STREAM_SYSTEM_ENFORCED` and `STREAM_ACCESSIBILITY` together (speaker index 5 -> 6; accessibility 6 -> 7). Only `STREAM_ALARM` (15) stayed put. `mUseFixedVolume=false`. So the device volume is effectively one master volume: turning a Session down also turns down notifications and anything speaking on MUSIC or ACCESSIBILITY (TTS). Input for #15.

### Still to do (needs a Sender)

- Audio and mirroring end to end; the mirroring -> AirPlay video Handover with YouTube, including the ad-break decoder fault.
- Whether the receiver's MediaSession appears in Immortal's now-playing, and whether play/pause reaches the Sender.
- Whether stock Snapcast pauses on losing audio focus.
- First-connect delay to a sleeping Portal; discovery after a Wi-Fi reconnect.
- Rotation and scaling: portrait iPhone mirroring, landscape video.
- Device traces: YouTube Handover, YouTube ad break, Sender screen lock mid-Session, Sender out of Wi-Fi range, audio-only Session ending.
