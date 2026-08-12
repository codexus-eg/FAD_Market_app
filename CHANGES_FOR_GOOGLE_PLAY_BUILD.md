# Scope of this Google Play/GitHub preparation

The active Dart application code, UI, API URLs, assets, Android manifest, permissions, and network configuration are unchanged from the supplied FAD Market app.

Only build and delivery preparation was performed:

- Target and compile SDK set to API 36.
- Android Gradle Plugin set to 8.9.1.
- Gradle distribution set to 8.11.1.
- Kotlin Gradle Plugin set to 2.1.0.
- Java/Kotlin JVM target set to 17.
- GitHub Actions AAB workflow added.
- Keystore and passwords removed from the GitHub-safe package.
- Private signing backup created as a separate file.
- Outdated build-info and `.bak` delivery files removed from the GitHub-safe package.
- Google Play listing/checklist documents and the existing 512×512 icon were added.

No product, cart, login, customer settings, image display, order, invoice, chat, maintenance, or employee logic was changed.
