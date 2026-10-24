# Licence obligations of the portal-airplay APK, and what keeps Immortal at arm's length

Research for [rudysev/portal-airplay#3](https://github.com/rudysev/portal-airplay/issues/3).
Researched 2026-10-23 against primary sources (licence texts, the FSF GPL FAQ, each
dependency's own licence files at the commits named below, Android developer docs, Apple's
trademark guidelines, 17 U.S.C. 1201).

I am not a lawyer and this is not legal advice. The conclusions below are still stated
concretely, because the project needs decisions; where the law is genuinely open, it says so.

## Answer in brief

1. **The receiver APK is GPL-3.0 as a whole.** UxPlay's FairPlay code (`lib/playfair/`) and
   `lib/crypto.c` are GPL-3.0 and are not optional for mirroring, so any build that links them is
   a GPL-3.0 work (GPL-3.0 s.5(c)). Every other likely dependency is compatible, with one
   exception: **nqptp is GPL-2.0-only and cannot be combined into the same program** (see
   section 2).
2. **Each GitHub Release must carry a complete source tarball as a release asset**, built from
   the tag *with submodule contents and the OpenSSL source tarball inside it*. GitHub's automatic
   "Source code" archives are not enough: they leave submodule directories empty (verified below).
   Keep each release's source asset for as long as its APK is downloadable (GPL-3.0 s.6(d)).
3. **Immortal stays MIT if it only talks to the receiver across the process boundary** with
   simple messages: explicit intents, broadcasts, a bound AIDL/Messenger service, or a
   ContentProvider are all IPC between separate Linux processes. The red lines are: putting
   receiver code (Java/Kotlin or `.so`) into immortal.apk, loading it into Immortal's process
   (`createPackageContext(CONTEXT_INCLUDE_CODE)`, `sharedUserId`), or exchanging complex
   internal data structures (e.g. raw native structs over shared memory).
4. **The contract file (AIDL, action/extra constants) should be MIT-licensed**, written fresh
   by its copyright holder and not derived from any GPL code, and copied into both repos. MIT is
   GPL-compatible, so the receiver can include it, and it stays MIT inside immortal.apk.
5. **Listing and one-tap-installing the APK creates no licence obligation on Immortal's code.**
   An installer and the programs it installs are separate works (FSF FAQ), and the APK is
   downloaded from portal-airplay's own release page, where the source sits next to it. The
   catalog already lists GPL apps (AntennaPod, Snapcast, VLC).
6. **Two non-copyright risk flags.** (a) FairPlay: `playfair` is reverse-engineered,
   anonymously authored code that UxPlay itself calls of "unclear" legal status; a DMCA
   s.1201 interoperability defence exists but is untested for it. It has shipped openly since
   2015, including in Debian main and F-Droid. (b) Trademark: **"portal-airplay" puts Apple's
   AirPlay mark in the product name, which Apple's guidelines forbid.** Rename the app, and use
   AirPlay only in a referential phrase ("a receiver for AirPlay") with an attribution notice.

---

## 1. What a GPL-3.0 APK release must ship or offer

### 1.1 What "Corresponding Source" covers

GPL-3.0 s.1 defines Corresponding Source as "all the source code needed to generate, install,
and (for an executable work) run the object code and to modify the work, including scripts to
control those activities", including "interface definition files associated with source files"
and the source of libraries "that the work is specifically designed to require"
([GPL-3.0 s.1](../LICENSE)). It excludes the work's System Libraries and "general-purpose tools
or generally available free programs which are used unmodified" in building it (same section).

For portal-airplay that means the source tarball must contain:

| Item | Why it is in scope |
|---|---|
| All Kotlin/Java, resources, `AndroidManifest.xml`, Gradle files and the Gradle wrapper | "scripts to control those activities" ([GPL-3.0 s.1](../LICENSE)) |
| The native tree: UxPlay, libplist, FFmpeg, OpenSSL, Oboe (if built from source) at their exact pinned commits | They are linked into `libairplay_native.so`; source must "correspond exactly to the binaries" ([FSF FAQ #AnonFTPAndSendSources](https://www.gnu.org/licenses/gpl-faq.html#AnonFTPAndSendSources)) |
| The UxPlay patch files and the task that applies them (the prototype applied them at configure time with `git apply`) | Build scripts; upstream does this in `applyUxplayPatches` ([android-airplay-server `app/build.gradle.kts` @a46cca0](https://github.com/jqssun/android-airplay-server/blob/a46cca0a6a1274e9e33c0e750f0f1c1eb1d881ea/app/build.gradle.kts)) |
| The FFmpeg configure line | Already in a CMake file upstream (`--disable-all ... --enable-decoder=alac,aac --enable-static`, [`BuildFFmpeg.cmake` @a46cca0](https://github.com/jqssun/android-airplay-server/blob/a46cca0a6a1274e9e33c0e750f0f1c1eb1d881ea/app/src/main/cpp/cmake/BuildFFmpeg.cmake)); FFmpeg's own checklist also asks for it ([ffmpeg.org/legal](https://ffmpeg.org/legal.html)) |
| **The OpenSSL source tarball itself** | The upstream build downloads it at build time from a third-party mirror (`URL https://mirror.viaduck.org/openssl/openssl-${OPENSSL_BUILD_VERSION}.tar.gz`, [openssl-cmake `cmake/BuildOpenSSL.cmake`](https://github.com/viaduck/openssl-cmake/blob/v3/cmake/BuildOpenSSL.cmake)). s.6(d) lets source sit on a third-party server, but "you remain obligated to ensure that it is available" ([GPL-3.0 s.6(d)](../LICENSE)); a mirror you do not control does not meet that, so ship the tarball. |
| NDK/CMake versions used (a note, not the tools) | The NDK and Android platform libraries are tools and System Libraries, excluded from Corresponding Source ([GPL-3.0 s.1](../LICENSE)), but naming the versions is how a user rebuilds it |

Never use openssl-cmake's default mode, which "Defaults to prebuilt binaries" downloaded from
viaduck's build server ([openssl-cmake README](https://github.com/viaduck/openssl-cmake#prebuilt-openssl));
you would ship object code whose source you do not have. Upstream sets `BUILD_OPENSSL ON`
([`CMakeLists.txt` @a46cca0](https://github.com/jqssun/android-airplay-server/blob/a46cca0a6a1274e9e33c0e750f0f1c1eb1d881ea/app/src/main/cpp/CMakeLists.txt)); keep that.

Reproducible byte-identical builds are not required: "that does not imply your tools must be able
to make a binary that is an exact hash of the binary you are distributing"
([FSF FAQ #MustSourceBuildToMatchExactHashOfBinary](https://www.gnu.org/licenses/gpl-faq.html#MustSourceBuildToMatchExactHashOfBinary)).

### 1.2 How to satisfy it on GitHub Releases

GPL-3.0 s.6(d) allows conveying object code "by offering access from a designated place ... and
offer equivalent access to the Corresponding Source in the same way through the same place at no
further charge", and requires "clear directions next to the object code saying where to find the
Corresponding Source" when it is elsewhere ([GPL-3.0 s.6(d)](../LICENSE)). The FSF adds that the
source "should be just as easy to access as the object code" and must be for "the same version of
the program - not an older version and not a newer version"
([FSF FAQ #AnonFTPAndSendSources](https://www.gnu.org/licenses/gpl-faq.html#AnonFTPAndSendSources)),
and that a VCS link is acceptable only with "clear and convenient instructions for how to get the
source for the exact object code they downloaded"
([FSF FAQ #SourceInCVS](https://www.gnu.org/licenses/gpl-faq.html#SourceInCVS)).

**GitHub's automatic "Source code (tar.gz/zip)" archives do not include submodule contents.**
Checked on 2026-10-23: the tarball of `jqssun/android-airplay-server` at `a46cca0`
(`gh api repos/jqssun/android-airplay-server/tarball/main`) contains
`app/src/main/cpp/third_party/UxPlay/` as an empty directory, as are `ffmpeg/`, `libplist/` and
`openssl-cmake/`, although all four are submodules in its
[`.gitmodules`](https://github.com/jqssun/android-airplay-server/blob/a46cca0a6a1274e9e33c0e750f0f1c1eb1d881ea/.gitmodules).
GitHub also documents that these archives "are generated on request, cached for a while, and then
deleted" ([GitHub Docs: downloading source code archives](https://docs.github.com/en/repositories/working-with-files/using-files/downloading-source-code-archives)).

**Recommended release recipe** (each item traces to the citations above):

1. Tag the release. CI builds the APK from that tag.
2. CI also builds `portal-airplay-<version>-source.tar.gz`: the tagged tree plus every submodule's
   files at its pinned commit, the downloaded OpenSSL source tarball, and the patch files. Attach
   it to the same Release as the APK.
3. The release notes say, next to the APK: "Complete corresponding source:
   `portal-airplay-<version>-source.tar.gz` (this release)." That is the s.6(d) "clear directions".
4. Never delete a release's source asset while its APK asset is still downloadable. The catalog
   entry's `releases/latest/download/...` URL always resolves to the newest APK, whose release
   carries the matching source.

Installation Information (signing keys, etc.) is **not** required: GPL-3.0 only demands it when
object code is conveyed "in, or with, or specifically for use in, a User Product" as part of a
transaction that transfers "the right of possession and use of the User Product"
([GPL-3.0 s.6](../LICENSE)). Publishing an APK for Portals people already own is not such a
transaction, so the release signing key stays private.

### 1.3 Notices the app and source must carry

- Keep every upstream licence notice intact and ship the GPL text
  ([GPL-3.0 s.4](../LICENSE)).
- Files we modify (e.g. patched UxPlay sources) must "carry prominent notices stating that you
  modified it, and giving a relevant date" ([GPL-3.0 s.5(a)](../LICENSE)). A header line in each
  patch, and the patch file's own header, does this.
- The app's UI must display "Appropriate Legal Notices": copyright, no-warranty statement, that
  it may be conveyed under the GPL, and how to view the licence; "a prominent item" in a menu
  satisfies it ([GPL-3.0 s.0 and s.5(d)](../LICENSE)). An "About / Licences" screen, reachable by
  D-pad, does it.
- Apache-2.0 components (OpenSSL, Oboe) require a copy of the Apache licence and any NOTICE file
  contents to go with the binary ([Apache-2.0 s.4](https://www.apache.org/licenses/LICENSE-2.0)).
  MIT components (llhttp, `srp.c`) require their notice in "all copies or substantial portions"
  ([`lib/srp.c` header](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/lib/srp.c)).
  FFmpeg asks for an "about box" mention of FFmpeg under the LGPLv2.1
  ([ffmpeg.org/legal](https://ffmpeg.org/legal.html)). Put all of these on the same licences
  screen.

---

## 2. Compatibility of each likely dependency

GPL-3.0 can absorb code under a licence the FSF calls compatible
([FSF FAQ #WhatDoesCompatMean](https://www.gnu.org/licenses/gpl-faq.html#WhatDoesCompatMean)).
GPLv2-only code cannot: "if you tried to combine code released under GPLv2 with code under GPLv3,
you would violate section 6 of GPLv2", while "version 2 or later" is fine
([FSF FAQ #v2v3Compatibility](https://www.gnu.org/licenses/gpl-faq.html#v2v3Compatibility)).

UxPlay files below were read at FDH2/UxPlay `95a0e49`; shairport-sync at `b991d91`; nqptp at
`ab8fb67`; libplist at `fe3dc34`; FFmpeg at `9d2d5b1`.

| Component | Licence (source) | With GPL-3.0 | Notes |
|---|---|---|---|
| UxPlay overall, `lib/crypto.c` | GPL-3.0-or-later ([`crypto.c` header](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/lib/crypto.c); [README "GPLv3, open source"](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/README.md)) | Yes | This is what makes the APK GPL-3.0. |
| UxPlay `lib/playfair/` (FairPlay) | GPL-3.0 text in [`lib/playfair/LICENSE.md`](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/lib/playfair/LICENSE.md); the `.c` files carry no copyright or licence header ([e.g. `playfair.c`](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/lib/playfair/playfair.c)); README credits "EstebanKubata ... License: GNU GPL" | Yes | No named copyright holder; Debian records its copyright only as the FSF's licence-text copyright ([Debian `uxplay` copyright](https://sources.debian.org/src/uxplay/1.73.7-1/debian/copyright/)). See section 5. |
| UxPlay `lib/` (raop, http, mirror buffer, `fairplay_playfair.c`) | LGPL-2.1-or-later ([`raop.c`](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/lib/raop.c), [`fairplay_playfair.c`](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/lib/fairplay_playfair.c) headers) | Yes | LGPLv2.1 "is compatible with GPLv2 and GPLv3" ([FSF licence list](https://www.gnu.org/licenses/license-list.html#LGPLv2.1)). |
| UxPlay `lib/llhttp`, `lib/srp.c` | MIT ([`lib/llhttp/LICENSE-MIT`](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/lib/llhttp/LICENSE-MIT), [`srp.c` header](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/lib/srp.c)) | Yes | Expat is "compatible with the GNU GPL" ([FSF licence list](https://www.gnu.org/licenses/license-list.html#Expat)). Keep the notices. |
| OpenSSL 3.x and later | Apache-2.0 ([`LICENSE.txt`](https://github.com/openssl/openssl/blob/master/LICENSE.txt)) | **Yes (GPL-3.0 only)** | FSF: Apache-2.0 is "compatible with version 3 of the GNU GPL", "not compatible with GPL version 2" ([licence list](https://www.gnu.org/licenses/license-list.html#apache2)); the ASF agrees ([apache.org GPL compatibility](https://www.apache.org/licenses/GPL-compatibility.html)). FFmpeg's LICENSE.md calling OpenSSL GPL-incompatible refers to the pre-3.0 licence ([FSF list: "from 3.0.0 on ... Apache License 2.0"](https://www.gnu.org/licenses/license-list.html#OpenSSL); [UxPlay README "Note to packagers"](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/README.md)). Never pin an OpenSSL below 3.0. |
| FFmpeg, default configure | LGPL-2.1-or-later ([`LICENSE.md`](https://github.com/FFmpeg/FFmpeg/blob/9d2d5b1aa39a714ad92cd3dd0253bd3aa7ee8be7/LICENSE.md)) | Yes | Static linking is fine here: the whole APK is GPL with full source, so a user can relink. |
| FFmpeg `--enable-gpl` / `--enable-version3` | GPL-2.0+ / (L)GPL-3.0 ([`LICENSE.md`](https://github.com/FFmpeg/FFmpeg/blob/9d2d5b1aa39a714ad92cd3dd0253bd3aa7ee8be7/LICENSE.md)) | Yes | "or later" makes GPL-2.0+ compatible ([FAQ #v2v3Compatibility](https://www.gnu.org/licenses/gpl-faq.html#v2v3Compatibility)). |
| FFmpeg `--enable-nonfree` | "unredistributable" ([`LICENSE.md`](https://github.com/FFmpeg/FFmpeg/blob/9d2d5b1aa39a714ad92cd3dd0253bd3aa7ee8be7/LICENSE.md)) | **No** | Never use it (e.g. for fdk-aac). |
| libplist | LGPL-2.1-or-later ([`src/plist.c` header](https://github.com/libimobiledevice/libplist/blob/fe3dc34dc3484006e12b403f7ceb06f0ad40b6f4/src/plist.c), [README](https://github.com/libimobiledevice/libplist/blob/fe3dc34dc3484006e12b403f7ceb06f0ad40b6f4/README.md#license)) | Yes | The repo also ships a GPL-2 `COPYING` beside `COPYING.LESSER`, but the library sources carry LGPL-2.1+ headers. |
| Oboe | Apache-2.0 ([repo licence](https://github.com/google/oboe/blob/main/LICENSE)) | Yes | As OpenSSL. |
| openssl-cmake (build script) | MIT ([repo metadata](https://github.com/viaduck/openssl-cmake)) | Yes | Build tooling; ships in the source tarball. |
| jqssun/android-airplay-server (reference or source of copied code) | GPL-3.0 ([repo](https://github.com/jqssun/android-airplay-server)); F-Droid records it as `GPL-3.0-only` ([fdroiddata metadata](https://gitlab.com/fdroid/fdroiddata/-/blob/master/metadata/io.github.jqssun.airplay.yml)) | Yes | If code is copied from it, the combined work cannot be offered as "or later". Our own new files can still say GPL-3.0-or-later. |
| shairport-sync | MIT-style for Shairport Sync itself; per-file BSD-3 (`pair_ap/evrtsp`), ISC (`audio_sndio.c`), MIT (FFTConvolver, `alac.c`) ([`LICENSES`](https://github.com/mikebrady/shairport-sync/blob/b991d91350e537c1f50dac98d9a3c836eceddcfc/LICENSES); `COPYING`: "refer to the individual source files") | Yes | All lax licences the FSF lists as compatible ([Modified BSD](https://www.gnu.org/licenses/license-list.html#ModifiedBSD), [ISC](https://www.gnu.org/licenses/license-list.html#ISC)). See section 5 for an embedded key. |
| shairport-sync AirPlay 2 deps: libsodium, libgcrypt | ISC ([`LICENSE`](https://github.com/jedisct1/libsodium/blob/master/LICENSE)); LGPL for the library ([libgcrypt README](https://github.com/gpg/libgcrypt/blob/master/README)) | Yes | Build deps listed in [shairport-sync BUILD.md](https://github.com/mikebrady/shairport-sync/blob/b991d91350e537c1f50dac98d9a3c836eceddcfc/BUILD.md). |
| Apple ALAC decoder | Apache-2.0 ([macosforge/alac `LICENSE`](https://github.com/macosforge/alac/blob/master/LICENSE)) | Yes | |
| **nqptp** | **GPL-2.0-only** ("version 2.", no "or later"; "Commercial licensing is also available") ([`nqptp.c` header](https://github.com/mikebrady/nqptp/blob/ab8fb67483411640fd7f1e193889482f2421c37c/nqptp.c), [`LICENSE`](https://github.com/mikebrady/nqptp/blob/ab8fb67483411640fd7f1e193889482f2421c37c/LICENSE)) | **No, if combined** | Must not be linked into the GPL-3.0 native library. Run as a separate executable it is an aggregate, but shairport-sync talks to it through shared memory ([`nqptp-shm-structures.h`](https://github.com/mikebrady/shairport-sync/blob/b991d91350e537c1f50dac98d9a3c836eceddcfc/nqptp-shm-structures.h)), and "Using shared memory to communicate with complex data structures is pretty much equivalent to dynamic linking" ([FSF FAQ #GPLPlugins](https://www.gnu.org/licenses/gpl-faq.html#GPLPlugins)). Options: reimplement PTP timing, keep nqptp as a separate binary with a deliberately thin interface, or ask the author for a GPL-2.0-or-later grant. Only matters if the library ticket picks shairport-sync AirPlay 2. |

---

## 3. Where the line sits for Immortal's integration

### 3.1 The test the FSF applies

The FSF says the line between "two separate programs, and one program with two parts" is "a legal
question, which ultimately judges will decide", and its criterion "depends both on the mechanism
of communication (exec, pipes, rpc, function calls within a shared address space, etc.) and the
semantics of the communication (what kinds of information are interchanged)". Modules "in the same
executable file" are "definitely combined"; modules "linked together in a shared address space"
almost surely are; "pipes, sockets and command-line arguments" normally mean separate programs,
unless "the semantics of the communication are intimate enough, exchanging complex internal data
structures" ([FSF FAQ #MereAggregation](https://www.gnu.org/licenses/gpl-faq.html#MereAggregation)).
A non-GPL program may use a GPL program if "they are separate works", in which case "the license of
the plug-in makes no requirements about the main program"
([FSF FAQ #NFUseGPLPlugins](https://www.gnu.org/licenses/gpl-faq.html#NFUseGPLPlugins)); to
distribute them side by side "you must make sure that the free and nonfree programs communicate at
arms length" ([FSF FAQ #GPLInProprietarySystem](https://www.gnu.org/licenses/gpl-faq.html#GPLInProprietarySystem)).
(Immortal is MIT, which is free and GPL-compatible, but the same test decides whether immortal.apk
becomes part of a GPL combined work, which is what its maintainer wants to avoid:
[immortal#170 comment](https://github.com/starbrightlab/immortal/pull/170#issuecomment-5184326847).)

On Android the mechanism side is clear-cut: "every app runs in its own Linux process", "Each
process has its own virtual machine (VM), so an app's code runs in isolation from other apps"
([Android: Application fundamentals](https://developer.android.com/guide/components/fundamentals)).
Two separately installed APKs signed with different keys cannot share a process: sharing one
requires the same Linux user ID and that "the apps must also be signed with the same certificate"
(same page).

### 3.2 Each integration mechanism

| Mechanism | Process boundary | Verdict | Why |
|---|---|---|---|
| Explicit intents / broadcasts with simple extras (strings, ints, booleans, URIs) | Separate processes | **Arm's length** | Message passing between separate programs, the "pipes, sockets" class ([FAQ #MereAggregation](https://www.gnu.org/licenses/gpl-faq.html#MereAggregation)); content is commands and status, not internal data structures. |
| Bound service via AIDL or `Messenger` | Separate processes, Binder IPC | **Arm's length, if the interface stays simple** | AIDL is for communication "using interprocess communication (IPC)" ([Android AIDL](https://developer.android.com/develop/background-work/services/aidl)), i.e. RPC, which the FSF lists as a mechanism, not as linking. Keep parameters to primitives, strings, `Bundle`s and small purpose-made `Parcelable`s; do not mirror the receiver's internal state objects. |
| ContentProvider | Separate processes | **Arm's length** | "the standard interface that connects data in one process with code running in another process" ([Android content providers](https://developer.android.com/guide/topics/providers/content-providers)). |
| Shared memory / `SharedMemory` / ashmem carrying native structs | Separate processes, shared data | **Avoid** | "pretty much equivalent to dynamic linking" when it carries complex data structures ([FAQ #GPLPlugins](https://www.gnu.org/licenses/gpl-faq.html#GPLPlugins)). Passing a `Surface` or a `ParcelFileDescriptor` as an opaque handle is different: no internal structure is shared. |
| `createPackageContext(..., CONTEXT_INCLUDE_CODE)` then `getClassLoader()` | **Same process** | **Combined work - never** | The flag means "loading code into the caller's process, so that getClassLoader() can be used to instantiate the application's classes" ([Android `Context` reference](https://developer.android.com/reference/android/content/Context#CONTEXT_INCLUDE_CODE)): the FAQ's "shared address space" case. |
| `sharedUserId` / same signing key to share a process | Same process possible | **Never** | Same process and VM ([Application fundamentals](https://developer.android.com/guide/components/fundamentals)). |
| Bundling the receiver APK or its `.so` inside immortal.apk | Same file | **Never** | "If the modules are included in the same executable file, they are definitely combined" ([FAQ #MereAggregation](https://www.gnu.org/licenses/gpl-faq.html#MereAggregation)); even as an embedded asset it would make immortal.apk a distributor of GPL object code with s.6 duties. |
| Immortal code derived from receiver or jqssun GPL sources | n/a | **Never** | A copy of GPL code is a work based on it ([FAQ #GPLInProprietarySystem](https://www.gnu.org/licenses/gpl-faq.html#GPLInProprietarySystem)). The MIT side must be written fresh. |

Form matters too: the FSF asks that the GPL program not be described as "part of" the other
system, so "users know ... what they have received is a free program plus another program, side by
side" ([FAQ #GPLInProprietarySystem](https://www.gnu.org/licenses/gpl-faq.html#GPLInProprietarySystem)).
Immortal's UI and docs should present the receiver as a separate app it works with.

### 3.3 The contract file and its licence

AIDL needs the same `.aidl` file "in the source code, in the `src/` directory, of both the
application hosting the service and any other application that binds to the service", and any
custom `Parcelable`'s code must be "available to the other side of the IPC channel"
([Android AIDL](https://developer.android.com/develop/background-work/services/aidl)). Intent
contracts likewise need shared action and extra-key constants. So something is copied into both
repos, and its licence decides whether Immortal stays clean:

- **License the contract files MIT (Expat), with an SPDX header**, authored by the person who
  writes them (rudysev or starbrightlab) and not derived from GPL code. The copyright holder can
  choose any licence for their own new file. MIT is GPL-compatible
  ([FSF licence list](https://www.gnu.org/licenses/license-list.html#Expat)), so the receiver can
  include it in its GPL-3.0 work; a module added to a GPL program only has to be "available for
  use under the GPL", and "you can, if you wish, release your module under a license which is more
  lax than the GPL but compatible with the GPL" ([FAQ #GPLModuleLicense](https://www.gnu.org/licenses/gpl-faq.html#GPLModuleLicense)).
  Immortal's copy stays MIT.
- **Do not make the contract file GPL.** GPL-3.0 s.1 counts "interface definition files associated
  with source files" as Corresponding Source ([GPL-3.0 s.1](../LICENSE)), and a GPL `.aidl` compiled
  into immortal.apk would put GPL code into it.
- Keep a per-file licence notice so a copied file never loses its licence
  ([FAQ #NoticeInSourceFile](https://www.gnu.org/licenses/gpl-faq.html#NoticeInSourceFile)).
- Reimplementing an interface on the other side of it is also on firm ground in US law: the
  Supreme Court held Google's reimplementation of the Java API declarations to be fair use
  ([Google LLC v. Oracle America, 593 U.S. 1 (2021)](https://www.supremecourt.gov/opinions/20pdf/18-956_d18f.pdf)).
  An MIT contract written by the parties makes this moot.

A GPL "linking exception for the contract interface" (the FAQ's controlled-interface template,
[#LinkingOverControlledInterface](https://www.gnu.org/licenses/gpl-faq.html#LinkingOverControlledInterface))
is not needed, and could not be granted anyway for UxPlay's code: "Only the copyright holders for
the program can legally authorize this exception" (same entry).

---

## 4. Listing and one-tap install from Immortal's catalog

- **Immortal's code takes on no GPL obligation.** "The installer and the files it installs are
  separate works. As a result, the terms of the GPL do not apply to the installation software"
  ([FSF FAQ #GPLCompatInstaller](https://www.gnu.org/licenses/gpl-faq.html#GPLCompatInstaller)).
  Putting programs side by side is an aggregate, and "Inclusion of a covered work in an aggregate
  does not cause this License to apply to the other parts" ([GPL-3.0 s.5](../LICENSE)).
- **Immortal does not host the APK.** A `url` catalog entry points at the app's own release
  (`apkUrl: https://github.com/<you>/<app>/releases/latest/download/<app>.apk`), and installs go
  "through Android's standard `PackageInstaller`"
  ([Immortal SUBMISSIONS.md](https://github.com/starbrightlab/immortal/blob/640ed8b43e3c6f34b0de80dd62bd795171cc668d/SUBMISSIONS.md),
  [docs/features/app-store.md](https://github.com/starbrightlab/immortal/blob/640ed8b43e3c6f34b0de80dd62bd795171cc668d/docs/features/app-store.md)).
  The bundled offline catalog is JSON metadata, not APKs. The device downloads the APK from
  portal-airplay's GitHub Release, which carries the source tarball, so s.6(d) is satisfied at the
  place the copy actually comes from.
- **Even on the broadest reading** ("convey" means "any kind of propagation that enables other
  parties to make or receive copies", [GPL-3.0 s.0](../LICENSE)), anyone pointing users at the APK
  can rely on the same designated place offering the source (s.6(d)). Belt and braces: set the
  catalog entry's `homepage` to the portal-airplay repo.
- **Precedent:** the catalog already lists GPL apps: AntennaPod (GPL-3.0), Snapcast (snapdroid,
  GPL-3.0), VLC (GPL-2.0) ([catalog.json @640ed8b](https://github.com/starbrightlab/immortal/blob/640ed8b43e3c6f34b0de80dd62bd795171cc668d/catalog.json);
  licences per GitHub metadata of [AntennaPod](https://github.com/AntennaPod/AntennaPod),
  [snapdroid](https://github.com/snapcast/snapdroid), [vlc-android](https://github.com/videolan/vlc-android)).
- What would change this: Immortal mirroring the APK on its own release assets (then Immortal
  would also have to offer the source there), or the bundling cases in section 3.2.

---

## 5. Legal-risk flags

### 5.1 The reverse-engineered FairPlay code

- **What it is.** `lib/playfair/` is a FairPlay implementation credited to "EstebanKubata ... a
  FairPlay library called PlayFair" ([UxPlay README, authors](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/README.md));
  that repo was created and last pushed on 2015-04-22 ([EstebanKubata/playfair](https://github.com/EstebanKubata/playfair)).
  Its files carry no author or copyright line (section 2), so there is no identifiable licensor to
  ask for anything, and file names such as `omg_hax.c` and `hand_garble.c` suggest a reverse-engineered,
  not documented, origin ([`lib/playfair/`](https://github.com/FDH2/UxPlay/tree/95a0e49561a52e4b52ef59c8e17cdd701509d35a/lib/playfair)).
  UxPlay also embeds four canned FairPlay reply messages ([`fairplay_playfair.c`](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/lib/fairplay_playfair.c));
  shairport-sync carries the same bytes in its `/fp-setup` handler ([`rtsp.c` `handle_fp_setup`](https://github.com/mikebrady/shairport-sync/blob/b991d91350e537c1f50dac98d9a3c836eceddcfc/rtsp.c)).
- **UxPlay's own disclaimer:** "This project makes use of a third-party GPL library for handling
  FairPlay. The legal status of that library is unclear. Should you be a representative of Apple
  and have any objections ... please contact the developers"
  ([UxPlay README, Disclaimer](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/README.md#disclaimer)).
- **The legal hook is anti-circumvention, not copyright licensing.** US law bans trafficking in
  technology "primarily designed or produced for the purpose of circumventing a technological
  measure" ([17 U.S.C. 1201(a)(2), (b)(1)](https://www.law.cornell.edu/uscode/text/17/1201)).
  There is an interoperability exception: the means may be made available to others "solely for the
  purpose of enabling interoperability of an independently created computer program"
  ([17 U.S.C. 1201(f)(3)](https://www.law.cornell.edu/uscode/text/17/1201)). An independent
  receiver that interoperates with Apple senders fits the words of (f); whether a court would
  apply it to this code is untested. (The EU analogue is the decompilation-for-interoperability
  rule in [Directive 2009/24/EC Art. 6](https://eur-lex.europa.eu/eli/dir/2009/24/oj).)
- **Mitigating facts.** The handshake does not unlock Apple's content DRM: "Apple video-DRM (as
  found in "Apple TV app" content on the client) cannot be decrypted by UxPlay"
  ([UxPlay README](https://github.com/FDH2/UxPlay/blob/95a0e49561a52e4b52ef59c8e17cdd701509d35a/README.md)).
  The code has been public since 2015 and ships in Debian main (`uxplay` 1.62 in bookworm,
  1.71.1 in trixie, 1.73.7 in sid: [sources.debian.org](https://sources.debian.org/src/uxplay/))
  and in F-Droid, built from source with submodules ([fdroiddata metadata](https://gitlab.com/fdroid/fdroiddata/-/blob/master/metadata/io.github.jqssun.airplay.yml)).
  That is evidence of tolerance, not a licence.
- **What this means in practice.** The realistic worst case is a takedown request against the repo
  or release, not a claim against users. It is the same exposure every open AirPlay mirroring
  receiver has. Keep the FairPlay code byte-identical to upstream (no portal-airplay authorship of
  circumvention logic), don't market the app around DRM or protected content, and carry a
  disclaimer and contact line like UxPlay's. Because Immortal never contains or distributes the
  receiver (sections 3-4), a takedown would hit portal-airplay, not immortal.apk; the catalog entry
  would simply be removed.
- **If shairport-sync is chosen:** it also contains a hard-coded RSA private key
  (`super_secret_key` in [`common.c`](https://github.com/mikebrady/shairport-sync/blob/b991d91350e537c1f50dac98d9a3c836eceddcfc/common.c))
  used to answer senders' `Apple-Challenge` header ([`rtsp.c`](https://github.com/mikebrady/shairport-sync/blob/b991d91350e537c1f50dac98d9a3c836eceddcfc/rtsp.c)).
  It is the same kind of risk as `playfair` (authentication material taken from Apple's ecosystem),
  and the same mitigations apply. UxPlay does not answer `Apple-Challenge` (no occurrence of
  `Apple-Challenge` or an embedded RSA private key in its tree at `95a0e49`, checked by grep).

### 5.2 Apple's AirPlay trademark and the name "portal-airplay"

- AirPlay(R) and FairPlay(R) are on Apple's trademark list
  ([Apple trademark list](https://www.apple.com/legal/intellectual-property/trademark/appletmlist.html)).
- Apple's guidelines: "You may not use or register, in whole or in part, ... any other Apple
  trademark ... as or as part of a company name, trade name, product name, or service name"; and
  "Do not make up names that contain Apple trademarks"
  ([Apple trademark guidelines](https://www.apple.com/legal/intellectual-property/guidelinesfor3rdparties.html)).
- Allowed instead: an Apple word mark "in a referential phrase ... to describe that the third
  party product is compatible", provided "The Apple word mark is not part of the product name",
  the phrase is like "runs on", "for use with", "for" or "compatible with", the mark "appears less
  prominent than the product name", and nothing implies endorsement (same page, "Compatibility").
  Add the attribution "AirPlay is a trademark of Apple Inc., registered in the U.S. and other
  countries" (same page, "Proper Trademark Notice and Attribution").
- **Conclusion: rename before the first release.** "portal-airplay" as the app name, launcher label,
  repo name or package name puts the mark in the product name. The other open receivers avoid it
  (UxPlay, RPiPlay, shairport-sync); jqssun's F-Droid app is labelled "AirPlay Server"
  ([fdroiddata metadata](https://gitlab.com/fdroid/fdroiddata/-/blob/master/metadata/io.github.jqssun.airplay.yml)),
  but that is a risk taken, not a permission. Renaming now costs a repo rename and nothing else;
  after release it also costs a package-name migration. Apple's logo and AirPlay icon must not be
  used at all (same guidelines, "Apple Logo and Apple-owned Graphic Symbols").
- Lower stakes: Immortal's internal identifiers (`airplay` settings domain, `AirPlayControl`) are
  not product names, and user-facing labels such as "Receive from AirPlay" are referential. Keep
  the GPL off this question: GPL-3.0 grants no trademark rights and allows "Declining to grant
  rights under trademark law" as an additional term ([GPL-3.0 s.7(e)](../LICENSE)).
- "Portal": Meta's published trademark list does not include Portal names, and states that absence
  "does not mean that we have waived our rights" ([Meta trademarks](https://www.meta.com/brand/resources/meta/our-trademarks/)).
  The Immortal catalog already carries several "Portal ..." community apps (catalog.json above), so
  a "Portal" prefix is the ecosystem norm. Low risk; not pursued further.

### 5.3 Codec patents (note only)

The FFmpeg build decodes ALAC and AAC ([`BuildFFmpeg.cmake`](https://github.com/jqssun/android-airplay-server/blob/a46cca0a6a1274e9e33c0e750f0f1c1eb1d881ea/app/src/main/cpp/cmake/BuildFFmpeg.cmake)).
FFmpeg's own patent FAQ says private, non-commercial use gives "remarkably little reason to be
concerned" ([ffmpeg.org/legal](https://ffmpeg.org/legal.html)). A free GitHub release is in that
territory. Prefer the platform's MediaCodec AAC decoder where it exists.

---

## Open questions surfaced for the map

1. **App name.** "portal-airplay" conflicts with Apple's trademark guidelines. Needs a new name
   (repo, app label, package name) before any release. Probably a small grilling ticket; it also
   touches GLOSSARY.md and the catalog entry.
2. **Release pipeline as a spec item.** The complete-source tarball (submodules + OpenSSL tarball +
   patches) and the release-notes wording should be specified in the build/release part of the
   spec. GitHub's auto-archives are not compliant on their own.
3. **nqptp**, only if the library ticket picks shairport-sync for AirPlay 2: GPL-2.0-only, so it
   needs a decision (reimplement, separate binary with a thin interface, or ask for relicensing).
4. **Contract repository and licence header.** Where the MIT contract files live (in portal-airplay,
   in Immortal, or a tiny third repo) and who holds the copyright: belongs to the contract ticket.
