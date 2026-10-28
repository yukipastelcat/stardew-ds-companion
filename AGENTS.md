# AGENTS.md — stardew-ds-companion

Flutter (Dart `^3.13`, Flutter 3.47.0) Android app for StardewDS. It runs
on the same device as the game and redraws the HUD and extra screens
(clock, vitals, backpack/inventory, animals, skills, map) using data and
real game sprites served by the SMAPI mod
(`yukipastelcat/stardew-ds-mod`) on `localhost:8082`. It is a git
submodule (`companion/`) of the umbrella `yukipastelcat/stardew-ds` repo.

## Commands

```bash
flutter pub get
flutter analyze          # flutter_lints; android/ios/web/etc. are excluded
flutter test             # no tests exist yet; add under test/ if you write some
flutter run              # needs a device/emulator
flutter build apk --release
```

Release APK signing is only configured in CI
(`.github/workflows/release.yml`, secrets `ANDROID_KEYSTORE_*`); don't
commit keystores or `key.properties`. Releases are manual: bump
`version:` in `pubspec.yaml`, commit, then publish a GitHub Release — the
workflow only builds and attaches the APK.

## Architecture (`lib/`)

- `main.dart` — entry; immersive fullscreen, `MaterialApp`, Stardew theme.
- `services/game_connection_service.dart` — single `ChangeNotifier`
  owning the connection to the mod: WebSocket (`ws://<host>:8082/ws`)
  for state, HTTP for actions (`/select`, `/move`, `/organize`,
  `/open-journal`) and URL builders for image endpoints (`/sprite`,
  `/portrait`, `/icon`, `/world-map`, …). Handles reconnects.
- `models/` — `GameState`, `InventoryItem`, `AnimalSummary`: parse the
  mod's JSON. Mirror of the mod's `GameStateSnapshot.cs`.
- `screens/home_screen.dart` — top level; shows black `IdleScreen` while
  disconnected or the game is idle (cutscene/sleep/loading), otherwise
  `CompanionScreen`, cross-fading through black.
- `screens/companion_screen.dart` + `screens/companion/*` — tabs
  (backpack, map, animals, skills).
- `widgets/` — reusable pieces (vital bars, clock, inventory slots with
  drag-and-drop, nav bar, window box, buttons).
- `theme/` — `StardewColors`, Stardew Valley pixel font setup
  (`assets/fonts/StardewValley.ttf`, see its license folder).

## Conventions

- Follow `flutter_lints` (`analysis_options.yaml`); keep `flutter analyze`
  clean.
- Use real game art fetched from the mod rather than approximating
  visuals with Flutter drawing, and render pixel art unsmoothed
  (nearest-neighbour filtering) so it stays crisp.
- The mod and app are versioned separately but share a JSON contract.
  When changing `models/game_state.dart` or an endpoint URL, check the
  mod's `GameStateSnapshot.cs` / `CompanionServer.cs`; stay tolerant of
  missing fields and of older mod builds.
- Existing code is comment-heavy about *why* (hardware quirks,
  Flutter-web inspector workarounds, mod behaviour). Keep that style.
- Use `const` constructors and dispose controllers/listeners, as the
  existing widgets do.
- The README is a stub; this file and the code comments are the docs.
