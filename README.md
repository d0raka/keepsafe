# KeepSafe

[![CI](https://github.com/d0raka/keepsafe/actions/workflows/ci.yml/badge.svg)](https://github.com/d0raka/keepsafe/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)

A local-first, end-to-end encrypted password manager built with Flutter — for macOS and iOS.

All data is encrypted on-device using AES-256-GCM with Argon2id key derivation. Nothing ever leaves your device unless you explicitly export it.

## Demo

KeepSafe is a macOS and iOS app, so there is no public web demo and no screenshot in the repository. After setup, `flutter run -d macos` opens the app.

---

## Features

- **Multiple vaults** — organize credentials into separate encrypted vaults
- **AES-256-GCM encryption** with Argon2id key derivation (via the `cryptography` package)
- **Biometric unlock** — Face ID / Touch ID support via `local_auth`
- **TOTP (2FA)** — built-in authenticator codes for any TOTP-compatible service
- **Password generator** — configurable length, character sets
- **Security analyzer** — flags weak, reused, and 2FA-less credentials
- **Import / Export** — portable encrypted vault files
- **Recovery key** — reset master password without losing your data

---

## Tech Stack

| Layer | Library |
|---|---|
| UI / Framework | Flutter + Material 3 |
| State management | Riverpod |
| Encryption | `cryptography` (AES-256-GCM, Argon2id) |
| Secure storage | `flutter_secure_storage` |
| Biometrics | `local_auth` |
| File I/O | `path_provider`, `file_selector` |

---

## Getting Started

**Requirements:** Flutter 3.x, Xcode 15+ (macOS/iOS)

```bash
git clone https://github.com/d0raka/keepsafe.git
cd keepsafe
flutter pub get
flutter run -d macos   # or -d ios
```

> iOS requires a provisioning profile. Run on a physical device for biometric features.

---

## Security Notes

- Master password is never stored — only a derived key verifier
- Encryption keys are held in memory only during an active session
- Vault files are opaque blobs; without the master password (or recovery key) they are unreadable
- Biometric auth unlocks the in-memory key; it does not replace the master password

---

## License

MIT — see [LICENSE](LICENSE)
