# A dedicated release key, owned by the maintainer and used by CI

Every Portal that installs the Receiver from the Immortal Store can only take updates signed with the same key, and the Store neither checks certificates nor explains the failure: a key change shows up as a bare "Failed (status=N)" on every device, with uninstall-and-reinstall as the only way out. So the release key is a dedicated keystore (RSA 4096, validity 30+ years), owned by the maintainer (rudysev), with the master copy and its passwords in a password manager plus a second offline backup. starbrightlab never holds it, and the debug key, which other Portal Originals sign with, is never used for a release.

We chose to let GitHub Actions sign releases over signing only on the maintainer's machine. Signing locally would keep the key off GitHub, but it would make releases depend on one laptop's toolchain and on the GPL source tarball matching a build nobody else can reproduce. Instead CI holds a copy as four secrets (`RELEASE_KEYSTORE_B64`, `RELEASE_KEYSTORE_PASSWORD`, `RELEASE_KEY_ALIAS`, `RELEASE_KEY_PASSWORD`) in a `release` Environment that only `v*` tags can deploy to and that requires the maintainer's approval, so pull requests (including from forks) never reach them. The certificate's SHA-256 fingerprint is committed to the repo, and the release workflow fails if `apksigner` reports any other.

## Consequences

- Losing every copy of the key strands every installed Receiver on its last version. The backups are the only defence; GitHub secrets can't be read back out.
- A leaked key lets anyone ship an update Portals will accept. APK Signature Scheme v3 (API 28+) can rotate to a new key with a proof-of-rotation, but it is untested on Portal, so a rotation needs a device test before it ships.
- Revisit if the project gains other maintainers who need to cut releases.
