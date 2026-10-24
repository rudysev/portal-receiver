# Which AirPlay receiver library should portal-airplay build on?

Research for [rudysev/portal-airplay#2](https://github.com/rudysev/portal-airplay/issues/2), part of
the map [#1](https://github.com/rudysev/portal-airplay/issues/1). Surveyed 2026-10-23 from primary
sources: the projects' own repositories (READMEs, source, releases, issues), AOSP source and kernel
documentation. Repository facts (stars, open issues, last commit) were read through the GitHub API on
that date; every other claim links to the file, release or issue it comes from.

---

## Answer

**Build on UxPlay's C core ([FDH2/UxPlay](https://github.com/FDH2/UxPlay)), consumed directly as a
pinned submodule, with portal-airplay's own Android layer (JNI, MediaCodec, AudioTrack/Oboe, media3
for HLS).** Use [jqssun/android-airplay-server](https://github.com/jqssun/android-airplay-server) and
[pgodlews/wormhole-display](https://github.com/pgodlews/wormhole-display) (both GPL-3.0, both UxPlay
on Android, the second built for Portal) as references to borrow from, not as the base.

- No open-source receiver, in any language, does both screen mirroring and true AirPlay 2 audio
  (buffered audio, PTP clock sync, multi-room) in one receiver. UxPlay is the only actively
  maintained project that does mirroring, AirPlay video (HLS), PIN pairing and DACP. Every Android
  receiver that mirrors, including the one portal-receiver vendored, is UxPlay underneath.
- **True AirPlay 2 multi-room is not viable on a stock Portal, with any library.** It needs a PTP
  listener on UDP ports 319 and 320. An Android app has no permission to bind ports below 1024, so
  it needs root. Even with root, it would have to run as a second, separate receiver alongside the
  mirroring one, because no implementation has made both work under one AirPlay identity. See
  [Multi-room and mirroring](#can-true-airplay-2-multi-room-coexist-with-mirroring).
- "The latest AirPlay 2 library" therefore splits in two. For mirroring and video it is UxPlay
  (1.73.7, plus the 1.74 work on master). For multi-room audio it is shairport-sync 5.6.1, which is
  audio-only and needs root on Android to do AirPlay 2.

---

## What "AirPlay 2" means in this comparison

Projects use "AirPlay 2" for two different things, and the difference decides this ticket.

- **AirPlay 2 by the "Legacy Protocol" (UxPlay's term).** UxPlay "supports Apple's AirPlay2 protocol
  using 'Legacy Protocol', but some features are missing"
  ([UxPlay README L228-237](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/README.md?plain=1#L228-L237)).
  It advertises the features word `0x5A7FFEE6,0x0`, so every bit from 32 to 63 is off
  ([lib/dnssdint.h](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/lib/dnssdint.h#L32-L34)).
  Clock timing uses NTP; the `timingProtocol` in a sender's SETUP plist reads `NTP`
  ([UxPlay #535 log](https://github.com/FDH2/UxPlay/issues/535)). This is the path that carries
  mirroring.
- **"Full" AirPlay 2 audio.** This uses feature bits 40 (SupportsBufferedAudio), 41 (SupportsPTP),
  46 (SupportsHKPairingAndAccessControl) and 48 (SupportsTransientPairing)
  ([openairplay feature-bit table](https://openairplay.github.io/airplay-spec/features.html)), with
  PTP timing on UDP 319 and 320. It is what lets an iPhone group a receiver with HomePods in sync
  ([shairport-sync AIRPLAY2.md L33, L61](https://github.com/mikebrady/shairport-sync/blob/b991d91350e537c1f50dac98d9a3c836eceddcfc/AIRPLAY2.md?plain=1#L33)).

UxPlay's maintainer puts it this way: "The Airplay 2 support is partial in both projects, different
parts!" (UxPlay and shairport-sync), and recommends shairport-sync for multi-room
([UxPlay #260](https://github.com/FDH2/UxPlay/issues/260)).

---

## Candidates at a glance

Key: Y = supported, N = not supported, P = partial, WIP = work in progress, - = not applicable.

| Project | Audio | Buffered AP2 audio / multi-room | Mirroring | AirPlay video (HLS) | PIN | DACP / now-playing | Licence | Health (2026-10-23) | Android arm64 |
|---|---|---|---|---|---|---|---|---|---|
| [UxPlay](https://github.com/FDH2/UxPlay) | Y (ALAC, AAC-ELD) | **N** | Y (H.264, H.265) | Y (YouTube app) | Y | Y | GPL-3.0 (lib/ mostly LGPL-2.1+, playfair GPL) | Very active: v1.73.7 on 2026-09-04, 78 commits in 3 months, 1 main maintainer | Proven through many ports, including a Gen-2 Portal |
| [jqssun/android-airplay-server](https://github.com/jqssun/android-airplay-server) | Y | **N** | Y | Y | Y | Y | GPL-3.0 | Active: v0.0.36 on 2026-10-19, 1 main maintainer, about 19 open PRs | It is the Android app (Android 7+) |
| [shairport-sync](https://github.com/mikebrady/shairport-sync) + [NQPTP](https://github.com/mikebrady/nqptp) | Y | **Y** (needs NQPTP on ports 319/320) | **N** | **N** | - (HomeKit pairing via the Home app) | Y (AP2 remote control new in 5.6) | MIT-style core; NQPTP GPL-2.0-only | Very active: 5.6.1 on 2026-10-21 | Classic AirPlay without root; AirPlay 2 needs root |
| [RPiPlay](https://github.com/FD-/RPiPlay) | Y | N | Y | N | N | N | GPL-3.0 | Dead: last commit 2022-01-11, 105 open issues | Superseded by UxPlay |
| [wormhole-display](https://github.com/pgodlews/wormhole-display) | Y (adds legacy RSA RAOP) | N | Y | **N** | **N** | Now-playing only | GPL-3.0 | New (created 2026-09-14), 1 maintainer | Built for Portal (API 28-29) |
| [shairplay-rust](https://github.com/metaneutrons/shairplay-rust) | Y | P (buffered audio Y, PTP **not wired**, so no sync) | WIP (legacy features only) | P (relays URL) | Y | AP1 only | LGPL-3.0 | Active, 1 maintainer, pre-1.0 | Unproven (pure Rust, should cross-compile) |
| [rairplay](https://github.com/r4v3n6101/rairplay) | Y (no decoding) | Not claimed | Y (no decoding) | Not claimed | Y (legacy + HomeKit) | Not claimed | GPL-3.0 | Slow: last commit 2026-07-20, 1 maintainer | Unproven; a protocol library only |
| [PhairPlay](https://github.com/mazer666/PhairPlay) / [iMirror](https://github.com/prat3ik/iMirror) | Y | **N** ("accepted but not played back yet") | Y (H.264) | Y | Y | Y | Labelled Apache-2.0 but bundles GPL playfair | Beta (v1.0.0-beta.3 on 2026-10-23) | Android TV app |
| [openairplay/airplay2-receiver](https://github.com/openairplay/airplay2-receiver) | Y | P (no PTP, no accurate sync) | N | N | P | N | **No licence** | Dormant: last commit 2023-10-02 | Python; not practical |

---

## Findings per project

### UxPlay (FDH2/UxPlay)

- **Features.** UxPlay is a mirroring server (H.264, with H.265 behind `-h265`) that also does
  audio-only ALAC streaming. It handles HLS video through `-hls`, and this is officially "only
  streaming from the YouTube iOS app"
  ([README L66-70](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/README.md?plain=1#L66-L70),
  [L84-88](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/README.md?plain=1#L84-L88)).
  Since 2026-08, master also plays direct `Content-Location` URLs
  ([UxPlay #555](https://github.com/FDH2/UxPlay/issues/555)). PIN pairing has worked since 1.67
  (`-pin`, `-reg`), and password access since 1.72 (`-pw`)
  ([README L1276-1336](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/README.md?plain=1#L1276-L1336)).
  `-dacp` exports the sender's DACP-ID and Active-Remote
  ([README L1663](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/README.md?plain=1#L1663)).
- **Multi-room: no.** The README says "AirPlay2 multi-room audio streaming is not supported: use
  shairport-sync for that"
  ([README L107](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/README.md?plain=1#L107)).
- **Licence.** UxPlay is GPLv3 as a whole. `lib/playfair` (FairPlay) is GPL, most of `lib/` is
  LGPLv2.1+, and `llhttp` is MIT
  ([README credits L2540-2576](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/README.md?plain=1#L2540-L2576)).
  OpenSSL 3 (Apache-2.0) is fine under GPLv3
  ([README L340-343](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/README.md?plain=1#L340-L343)).
  portal-airplay is GPL-3.0, so none of this is a problem.
- **Health.** The latest release is v1.73.7 (2026-09-04), and README version 1.74 (Experimental) is
  on master ([releases](https://github.com/FDH2/UxPlay/releases),
  [README L1-7](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/README.md?plain=1#L1-L7)).
  The repository has 78 commits since 2026-07-23, 68 of them by `fduncanh`, who has 1,452 commits
  overall; the next contributor has 59 (GitHub contributors API). That means a very active project
  with a bus factor of one. It has 35 open issues.
- **Android.** Upstream accepts Android-oriented changes, for example the merged
  [PR #574](https://github.com/FDH2/UxPlay/pull/574) (Android window handle). Version 1.74 adds an
  optional built-in mDNS responder, so UxPlay no longer depends on Avahi or Bonjour
  ([README L7-17](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/README.md?plain=1#L7-L17)).
  wormhole-display already uses this responder on Portal, because it says "Android's `NsdManager`
  cannot publish TXT records before API 31 (Portal devices run API 28-29)"
  ([wormhole architecture.md](https://github.com/pgodlews/wormhole-display/blob/2bc203e2ef4c3f672e64ea2173dbfb552552097e/docs/architecture.md)).
  The GStreamer renderers do not port to Android, and every Android port replaces them with
  MediaCodec and AudioTrack (see the two projects below).
- **Gaps that matter for Portal.**
  - UxPlay does not implement RSA `ANNOUNCE` audio, so PipeWire and Music Assistant senders fail
    against UxPlay-based receivers
    ([jqssun #44](https://github.com/jqssun/android-airplay-server/issues/44),
    [jqssun #42](https://github.com/jqssun/android-airplay-server/issues/42)).
    wormhole-display adds it as a local patch
    ([uxplay-patches.md](https://github.com/pgodlews/wormhole-display/blob/2bc203e2ef4c3f672e64ea2173dbfb552552097e/docs/uxplay-patches.md)).
  - Apple Music on macOS cannot play, because it uses FairPlay type 2, which is unfixable
    ([UxPlay #570](https://github.com/FDH2/UxPlay/issues/570)).

### jqssun/android-airplay-server (current state)

- **What it is now.** It is a full Android app, not a library: v0.0.36, released 2026-10-19, with
  36 releases since the repository was created on 2026-04-08. It is on Google Play and F-Droid.
  Its features cover mirroring (H.264/H.265), AAC-ELD/AAC-LC/ALAC audio, HLS video with downloads,
  track info and cover art, optional PIN, Android TV D-pad support, and a new USB-tethered
  secondary display ([README](https://github.com/jqssun/android-airplay-server/blob/a46cca0a6a1274e9e33c0e750f0f1c1eb1d881ea/README.md)).
  It has no multi-room support (no issue mentions it; GitHub issue search).
- **What it tracks.** The UxPlay submodule is pinned at `df67c21` ("prepations for 1.73.7",
  2026-09-04), which is **97 commits behind UxPlay master**. Nine local patches are applied at
  build time, `0001` to `0009`, among them HLS crash fixes, a PIN pairing proof-length fix and
  video-sender compatibility
  ([patches/UxPlay](https://github.com/jqssun/android-airplay-server/tree/a46cca0a6a1274e9e33c0e750f0f1c1eb1d881ea/app/src/main/cpp/patches/UxPlay)).
  The other submodules are unchanged since portal-receiver's pin: libplist `f41b1ea`,
  openssl-cmake `4edd36a`, ffmpeg `38b8833`
  ([.gitmodules and tree](https://github.com/jqssun/android-airplay-server/tree/a46cca0a6a1274e9e33c0e750f0f1c1eb1d881ea/app/src/main/cpp)).
  UxPlay fixes reach it as backports, for example
  [PR #71](https://github.com/jqssun/android-airplay-server/pull/71).
- **Since portal-receiver's pin `b9a590f`.** There are 19 commits. Their messages are one word
  ("volume", "api", "pin", "decoder") and add orientation detection, a USB-only mode, software
  AAC, ADB settings and a PIN change (`gh api compare b9a590f...main`).
- **Health.** `jqssun` wrote 46 of the commits; no one else has more than 5. About 19 community PRs
  are open and unmerged, including #15, #21 and #22, which portal-receiver was waiting on and which
  have been open since 2026-07-07
  ([open PRs](https://github.com/jqssun/android-airplay-server/pulls)).
- **Open bugs that matter here.**
  - HLS fails when the playlist URL has a query string
    ([#79](https://github.com/jqssun/android-airplay-server/issues/79)).
  - TikTok's handover from mirroring to video never sends `/play`
    ([#73](https://github.com/jqssun/android-airplay-server/issues/73)).
  - A/V micro-stutters on an Android 9 TV
    ([#72](https://github.com/jqssun/android-airplay-server/issues/72)).
  - SELinux denies `/dev/ashmem` on some devices
    ([#50](https://github.com/jqssun/android-airplay-server/issues/50)).
- **Lesson from portal-receiver.** To keep the vendored app syncable, portal-receiver had to leave
  the package name alone, push its options through SharedPreferences ("the indirection is the
  point"), and patch hard references to `MainActivity`
  ([portal-receiver IMMORTAL-PORT.md section 2](https://github.com/rudysev/portal-receiver/blob/main/IMMORTAL-PORT.md),
  [airplay/UPSTREAM.md](https://github.com/rudysev/portal-receiver/blob/main/airplay/UPSTREAM.md)).
  That cost comes from vendoring an app rather than a library.

### shairport-sync (+ NQPTP)

- **Features.** shairport-sync is the reference for open-source AirPlay 2 audio: realtime and
  buffered audio, lossless 24/48, 5.1/7.1, and "Audio synchronised with other AirPlay 2 devices"
  ([AIRPLAY2.md L32-48](https://github.com/mikebrady/shairport-sync/blob/b991d91350e537c1f50dac98d9a3c836eceddcfc/AIRPLAY2.md?plain=1#L32-L48)).
  It has **no video**: "Shairport Sync does not support AirPlay video or photo streaming"
  ([README L10](https://github.com/mikebrady/shairport-sync/blob/b991d91350e537c1f50dac98d9a3c836eceddcfc/README.md?plain=1#L10)).
  Version 5.6 adds remote control for AirPlay 2 players (play, pause, skip, volume) and richer
  now-playing metadata ([5.6 release](https://github.com/mikebrady/shairport-sync/releases/tag/5.6)).
- **The hard requirement.** "NQPTP must have exclusive access to ports `319` and `320`", and
  AirPlay 2 needs "low-port-number network access or `root` privileges"
  ([AIRPLAY2.md L61, L69](https://github.com/mikebrady/shairport-sync/blob/b991d91350e537c1f50dac98d9a3c836eceddcfc/AIRPLAY2.md?plain=1#L61-L69)).
  NQPTP shares its clock with shairport-sync through POSIX shared memory
  ([NQPTP README](https://github.com/mikebrady/nqptp)). Bionic does not provide `shm_open`
  ([bionic status.md](https://android.googlesource.com/platform/bionic/+/refs/heads/main/docs/status.md)),
  so an Android port has to replace that interface.
- **Licence.** The core is MIT-style
  ([shairport.c header](https://github.com/mikebrady/shairport-sync/blob/b991d91350e537c1f50dac98d9a3c836eceddcfc/shairport.c)),
  with per-file licences listed in
  [LICENSES](https://github.com/mikebrady/shairport-sync/blob/b991d91350e537c1f50dac98d9a3c836eceddcfc/LICENSES).
  **NQPTP is GPL "version 2" only**
  ([nqptp.c header](https://github.com/mikebrady/nqptp/blob/ab8fb67483411640fd7f1e193889482f2421c37c/nqptp.c)).
  That is incompatible with linking into a GPL-3.0 binary, so NQPTP would have to ship as a
  separate executable.
- **Health.** Releases came quickly: 5.5 (2026-09-04, security), 5.5.2 (2026-09-14, OS 27 fix),
  5.6 (2026-10-14) and 5.6.1 (2026-10-21)
  ([releases](https://github.com/mikebrady/shairport-sync/releases)). There are 11 open issues and
  100 or more commits since 2026-07-23 (GitHub API).
- **Android.** Two independent 2026 ports agree that classic AirPlay works without root and
  AirPlay 2 does not:
  - [hkfuertes/shairport-android](https://github.com/hkfuertes/shairport-android) runs
    shairport-sync 5.6 as a JNI library. "Classic AirPlay needs no root; AirPlay 2 (multi-room)
    needs root for NQPTP". (Its author also contributes to jqssun's project.)
  - [capullo-tech/lib-shairport-android](https://github.com/capullo-tech/lib-shairport-android)
    says "AirPlay 2 is not possible without root: its NQPTP companion requires exclusive use of
    privileged UDP ports 319/320", and lists the bionic shims needed (`pthread_cancel`,
    `getifaddrs`).

### RPiPlay (FD-/RPiPlay)

- RPiPlay is dead and superseded. Its last commit was on 2022-01-11, and it has 105 open issues and
  no releases (GitHub API). UxPlay was "initially developed by antimof using code from OpenMAX-based
  RPiPlay"
  ([UxPlay README L205-211](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/README.md?plain=1#L205-L211)).
  It is not a candidate.

### Newer receivers (2025-2026)

- **[pgodlews/wormhole-display](https://github.com/pgodlews/wormhole-display)** (GPL-3.0, C/Kotlin,
  created 2026-09-14).
  - It is a UxPlay-core port made specifically for Meta Portal. It is tested on Portal+ Gen 2,
    Mini, Go and TV, needs no root, and supports D-pad navigation on Portal TV
    ([README](https://github.com/pgodlews/wormhole-display/blob/2bc203e2ef4c3f672e64ea2173dbfb552552097e/README.md)).
  - It does mirroring and extended display, plus ALAC audio-only with a now-playing screen.
  - It has **no HLS AirPlay video and no PIN**: "No PIN or password admission"
    ([architecture.md, Known limitations](https://github.com/pgodlews/wormhole-display/blob/2bc203e2ef4c3f672e64ea2173dbfb552552097e/docs/architecture.md)).
  - Its vendored UxPlay patches are worth taking: bounds checks, legacy RSA RAOP, and a unique mDNS
    hostname, needed because `gethostname()` returns "localhost" on Android
    ([uxplay-patches.md](https://github.com/pgodlews/wormhole-display/blob/2bc203e2ef4c3f672e64ea2173dbfb552552097e/docs/uxplay-patches.md)).
  - It has 18 commits from 1 maintainer. It is the closest prior art to portal-airplay, and it is a
    competitor on the same hardware.
- **[metaneutrons/shairplay-rust](https://github.com/metaneutrons/shairplay-rust)** (LGPL-3.0,
  clean-room safe Rust, pre-1.0).
  - It does AP1 and AP2 buffered audio, HomeKit pairing, and an HLS URL relay
    ([README](https://github.com/metaneutrons/shairplay-rust/blob/2fb72b30b658b33f106165a5b6fbd941919bdbe5/README.md)).
  - PTP is bound but "not connected to playout ... no true clock sync and no multi-room sync"
    ([AP2-STATUS.md L48-62](https://github.com/metaneutrons/shairplay-rust/blob/2fb72b30b658b33f106165a5b6fbd941919bdbe5/AP2-STATUS.md?plain=1#L48-L62)).
  - Mirroring is "work in progress", and "AP2 buffered audio is intentionally disabled while video
    is enabled"
    ([README L246-258](https://github.com/metaneutrons/shairplay-rust/blob/2fb72b30b658b33f106165a5b6fbd941919bdbe5/README.md?plain=1#L246-L258)).
  - It is the most interesting newcomer, but not ready for mirroring.
- **[r4v3n6101/rairplay](https://github.com/r4v3n6101/rairplay)** (GPL-3.0, Rust).
  - It is a protocol library only: RTSP, legacy and HomeKit pairing, and decrypted audio/video
    packets. It has no decoding, playback or HLS, and "Public API documentation is still sparse"
    ([README](https://github.com/r4v3n6101/rairplay/blob/7a0ec4036905afe0c8de16881d85d5846dc938a7/README.md)).
  - Its last commit was on 2026-07-20, from 1 main maintainer.
- **[mazer666/PhairPlay](https://github.com/mazer666/PhairPlay)** (Kotlin, beta) and its GPL fork
  **[prat3ik/iMirror](https://github.com/prat3ik/iMirror)**.
  - They are a from-scratch Kotlin stack that claims mirroring, AirPlay video URL mode, PIN and DACP
    ([PhairPlay README L23-41](https://github.com/mazer666/PhairPlay/blob/598eac6672028ae97400752d004fad1f514f58e0/README.md?plain=1#L23-L41)).
  - Buffered AirPlay 2 audio is "accepted but not played back yet"
    ([L60](https://github.com/mazer666/PhairPlay/blob/598eac6672028ae97400752d004fad1f514f58e0/README.md?plain=1#L60)).
  - The licence is unclear. PhairPlay says Apache-2.0
    ([L54](https://github.com/mazer666/PhairPlay/blob/598eac6672028ae97400752d004fad1f514f58e0/README.md?plain=1#L54)),
    yet it bundles `playfair`
    ([tree](https://github.com/mazer666/PhairPlay/tree/598eac6672028ae97400752d004fad1f514f58e0/app/src/main/cpp/playfair)),
    which is GPL. iMirror relicensed to GPL-3.0 for exactly that reason
    ([iMirror README, License](https://github.com/prat3ik/iMirror/blob/9b52ce6d8bedb80ee557a5114d3cdbee4ab84f00/README.md)).
  - It is still in beta and has little validation on real devices ("Real-device validation ... is
    ongoing", L23).
- **[openairplay/airplay2-receiver](https://github.com/openairplay/airplay2-receiver)** (Python).
  - This is the research implementation that shairport-sync's AP2 work drew on
    ([shairport-sync README](https://github.com/mikebrady/shairport-sync/blob/b991d91350e537c1f50dac98d9a3c836eceddcfc/README.md)).
  - It does not do "Accurate audio sync (with help of PTP and/or NTP)"
    ([README](https://github.com/openairplay/airplay2-receiver/blob/6c343d3679ddb561c61566985acaaf587d0a3bd3/README.md)).
  - It has no licence file (the API reports `license: null`), and its last commit was on
    2023-10-02.
- **Not candidates.**
  - [xfirefly/Airplay-SDK](https://github.com/xfirefly/Airplay-SDK) is proprietary; its source is
    for sale (README).
  - [warren-bank/Android-ExoPlayer-AirPlay-Receiver](https://github.com/warren-bank/Android-ExoPlayer-AirPlay-Receiver)
    is a GPL-2.0 receiver for AirPlay v1 video URLs only (README).
  - Many 2026 Android TV apps are jqssun forks, among them
    [FireIslandMan/airback](https://github.com/FireIslandMan/airback) and
    [bestinepayyappilly/tv-airplay](https://github.com/bestinepayyappilly/tv-airplay)
    (GitHub search).
  - Windows-only receivers such as [xenos1337/AirPlayServer](https://github.com/xenos1337/AirPlayServer)
    are out of scope.

---

## Can true AirPlay 2 multi-room coexist with mirroring?

**Not in one receiver today. And on a stock Portal, true multi-room is out even on its own.**

1. **No open-source implementation does both under one identity.** Every mirroring receiver
   advertises the legacy feature word, with bits 40, 41, 46 and 48 off:
   - UxPlay: `FEATURES_2 0x0`
     ([dnssdint.h](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/lib/dnssdint.h#L32-L34)).
   - wormhole-display: `0x5A7FFEE6,0x0`
     ([architecture.md, Protocol knobs](https://github.com/pgodlews/wormhole-display/blob/2bc203e2ef4c3f672e64ea2173dbfb552552097e/docs/architecture.md)).
   - shairplay-rust: it found that iOS 18 sends the mirroring key only with "No AP2 bits (40, 41,
     46, 48) - pure legacy protocol for video", and lists "No AP2 audio with video" as a current
     limitation
     ([AP2-STATUS.md L95, L154](https://github.com/metaneutrons/shairplay-rust/blob/2fb72b30b658b33f106165a5b6fbd941919bdbe5/AP2-STATUS.md?plain=1#L95)).
     Combining the two is an unchecked TODO
     ([L165](https://github.com/metaneutrons/shairplay-rust/blob/2fb72b30b658b33f106165a5b6fbd941919bdbe5/AP2-STATUS.md?plain=1#L165)).

   An Apple TV does both, but how mirroring keys are derived under the AP2 feature set is not
   public (same source). When a UxPlay user tried to explore advertising other device classes, the
   maintainer replied "we dont know if this is possible" and suspected FairPlay would block it
   ([UxPlay #463](https://github.com/FDH2/UxPlay/issues/463)).
2. **PTP needs privileged ports, and Android apps cannot bind them.**
   - The kernel default `ip_unprivileged_port_start` is 1024, and "Privileged ports require root or
     CAP_NET_BIND_SERVICE" ([kernel ip-sysctl](https://docs.kernel.org/networking/ip-sysctl.html)).
   - AOSP's Zygote grants `CAP_NET_BIND_SERVICE` only to the Bluetooth and network-stack UIDs, never
     to ordinary apps
     ([com_android_internal_os_Zygote.cpp, android10-release, `CalculateCapabilities`](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android10-release/core/jni/com_android_internal_os_Zygote.cpp)).
   - Both Android shairport-sync ports therefore need root for AirPlay 2 (see above). Portal devices
     are not rooted.
   - shairplay-rust measured what happens without a listener on 319/320: the sender gets ICMP
     port-unreachable, stalls 5-11 s, and then plays **without** sync
     ([AP2-STATUS.md, Known Issues](https://github.com/metaneutrons/shairplay-rust/blob/2fb72b30b658b33f106165a5b6fbd941919bdbe5/AP2-STATUS.md)).
3. **Cost if it were pursued anyway.** Every item below is required:
   - Root on every Portal.
   - A second receiver stack: shairport-sync, plus NQPTP as a separate GPL-2.0-only executable,
     with a shared-memory shim.
   - A second AirPlay identity in the sender's picker (for example "Portal" for mirroring and
     "Portal Speaker" for grouped audio), plus code to give the speakers to one of them.
   - The capability would be lost on any device without root.

   That is not "reasonable cost". Per the map's rule, **rule multi-room out**.

---

## iOS / macOS 18-27 compatibility record

iOS 27 shipped in September 2026, so the record runs past the 18-26 range the ticket asked about.

| Break | Affects | Status |
|---|---|---|
| macOS Sequoia 15.2 bug broke mirroring to UxPlay | UxPlay-based | Apple fixed it in 15.3 ([UxPlay #379](https://github.com/FDH2/UxPlay/issues/379)) |
| macOS 26 Tahoe as sender | UxPlay-based | Works ([UxPlay #458](https://github.com/FDH2/UxPlay/issues/458)) |
| iOS 26.6 mirroring never negotiated (one report) | UxPlay | Maintainer confirms 26.6 works; problem was specific to the reporter's system ([UxPlay #547](https://github.com/FDH2/UxPlay/issues/547)) |
| iOS 18: mirroring key (`ekey`) sent only with legacy features | Any receiver that advertises AP2 bits | Design constraint ([shairplay-rust AP2-STATUS.md](https://github.com/metaneutrons/shairplay-rust/blob/2fb72b30b658b33f106165a5b6fbd941919bdbe5/AP2-STATUS.md?plain=1#L80-L95)) |
| iOS 27: frozen last frame after a typeless TEARDOWN | UxPlay | Fixed ([UxPlay #540](https://github.com/FDH2/UxPlay/issues/540)) |
| iOS 27: mirror data connection never opens; fixed for one client with `-h265`; maintainer: "probably time to make -h265 on by default" | UxPlay | Open, probably fixed ([UxPlay #535](https://github.com/FDH2/UxPlay/issues/535)) |
| iOS 27: audio silent after pause and resume (same-codec re-SETUP) | UxPlay GStreamer path | Open ([UxPlay #539](https://github.com/FDH2/UxPlay/issues/539)); Android ports use their own renderers |
| OS 27: unrecognised blocks in the buffered audio stream | shairport-sync | Fixed in 5.5.2 ([release](https://github.com/mikebrady/shairport-sync/releases/tag/5.5.2)) |
| macOS 27 freeze with h265 | UxPlay | Closed as "No bad changes in macOS 27" ([UxPlay #607](https://github.com/FDH2/UxPlay/issues/607)) |
| macOS Music app (FairPlay type 2) | Every open-source receiver | Unfixable ([UxPlay #570](https://github.com/FDH2/UxPlay/issues/570)) |

UxPlay's README warns: "there is no guarantee that future iOS releases will keep supporting 'Legacy
Protocol'"
([L236-237](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/README.md?plain=1#L236-L237)).
This risk is shared by every mirroring receiver in the survey, and it is the main long-term risk of
the recommendation.

---

## Recommendation and trade-offs

**Base: the UxPlay C core (`lib/`), as a pinned submodule of `FDH2/UxPlay` itself.** On top of it,
portal-airplay's own native glue and Kotlin layer: MediaCodec video, AudioTrack/Oboe audio, media3
for HLS, and the Receiver's own UI and Contract.

Why this base:

- UxPlay is the only maintained engine that covers mirroring, the mirroring-to-video Handover
  (HLS), PIN and DACP. It is proven on a Gen-2 Portal through portal-receiver.
- Taking UxPlay directly instead of through jqssun removes a lagging middleman. jqssun is 97 commits
  behind and fixes reach it as backports. Taking UxPlay directly also avoids the friction
  portal-receiver documented from vendoring an app. Upstream has accepted Android-oriented PRs.
- GPL-3.0 matches the project's licence.

What to borrow (GPL-3.0, with attribution):

- From **jqssun**: its UxPlay patch series (HLS hardening, PIN proof length, video-sender
  compatibility) and its JNI/audio-engine approach.
- From **wormhole-display**: its bounds-check patches, legacy RSA RAOP and the mDNS hostname fix.
- Send each patch upstream to UxPlay before carrying it locally.

Trade-offs accepted:

- **No multi-room**, and no sync with HomePods. AirPlay audio plays on the Portal alone. Immortal's
  Snapcast multi-room stays the house's grouping mechanism, which IMMORTAL-PORT already treats as
  mutually exclusive with AirPlay.
- **Bus factor of one** on UxPlay (`fduncanh`). This is mitigated by GPL forkability and the number
  of downstream ports.
- **Dependence on Apple's "Legacy Protocol"**, the same risk every mirroring receiver carries.
- **More initial work** than forking jqssun's app, because the Android layer is written fresh. The
  map's fresh-start decision already accepts this.

Alternatives considered and rejected:

- **Fork jqssun's app.** Fastest start, but it is an app rather than a library, it is maintained by
  one person, its PR backlog is unmerged, and it repeats portal-receiver's sync friction.
- **shairport-sync.** No video, and AirPlay 2 needs root.
- **shairplay-rust or rairplay.** Mirroring is WIP or not decoded; no Android proof.
- **PhairPlay.** Beta, its licence is inconsistent, and it has no buffered audio.
- **RPiPlay and openairplay.** Dormant.
- **Revisit trigger.** If shairplay-rust (or anyone else) demonstrates AP2 features and mirroring
  together, multi-room would still be blocked on Portal by the port-319/320 rule, so the decision
  stands unless Portal gains root.

---

## Open questions this surfaced

1. **Portal hardware decoders under iOS 27.** UxPlay is moving to HEVC by default because some iOS 27
   clients mirror only in HEVC ([UxPlay #535](https://github.com/FDH2/UxPlay/issues/535)). Which
   Portal models (Gen-1 Portal+ on Android 9, Gen-2, TV) have a hardware `video/hevc` MediaCodec
   decoder, and what should the Receiver advertise per model?
2. **mDNS advertisement path on API 28-29.** wormhole-display says NsdManager cannot publish the TXT
   records AirPlay needs before API 31, and uses UxPlay's internal responder. portal-receiver's
   NsdManager-based discovery did register on a Gen-2 Portal. Which path does portal-airplay use,
   and does the Gen-1 Portal+ agree?
3. **Scope of AirPlay video beyond YouTube.** UxPlay's HLS is officially YouTube-app-only.
   jqssun's open issues show other apps failing (TikTok handover #73, playlist query strings #79).
   Which sender apps must the Handover support?
4. **Non-Apple senders.** Should legacy RSA RAOP (`ANNOUNCE`) be supported, so that Music
   Assistant and PipeWire senders work as with wormhole's patch, or ruled out?
5. (Cheap to confirm, low priority.) Read `/proc/sys/net/ipv4/ip_unprivileged_port_start` on each
   Portal model to confirm the expected 1024 before closing the multi-room question for good.
