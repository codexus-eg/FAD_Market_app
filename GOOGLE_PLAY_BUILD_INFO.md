# FAD Market — Google Play build information

- App name: FAD Market
- Android application ID / package name: `fadmarket.app`
- Version name: `1.0.2`
- Version code: `45`
- Target API level: Android 16 / API 36
- Compile API level: Android 16 / API 36
- Release artifact: `build/app/outputs/bundle/release/app-release.aab`
- Signing: GitHub Actions secrets; the signing key is intentionally not included in this repository package.
- GitHub Actions workflow: `.github/workflows/build-aab.yml`

Do not change the package name after creating the app in Google Play Console. Every future update must use a version code greater than 45 and the same upload key.

## Upload certificate fingerprints

- Key alias: `upload`
- Certificate valid from: 2 July 2026
- Certificate valid until: 17 November 2053
- SHA-1: `CA:76:E3:E9:92:EA:D2:0C:2B:30:47:DD:C0:B8:59:10:70:2B:C3:A9`
- SHA-256: `54:62:20:4B:35:3E:26:A3:30:FA:CE:5A:D7:AB:45:B6:58:AB:CB:3D:35:E0:BD:49:0B:0B:EA:95:30:EC:5B:D0`
