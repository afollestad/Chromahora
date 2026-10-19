---
name: update-app-version
description: Bump Chromahora's version (major or minor) or build number for every target at once. Use when asked to bump, raise or set the app version or build number, or to prepare a release or App Store upload.
argument-hint: "major | minor | build"
---

`MARKETING_VERSION` (the version, `M.m`) and `CURRENT_PROJECT_VERSION` (the build number) live only in the project's own Debug and Release build settings, which the app, widgets, watch app and watch widgets all inherit. Never set either on a target, including through a target's General tab in Xcode: that bundle then keeps its own value and drifts from the rest, which App Store Connect flags.

## Pick the bump

- `major`: `M.m` becomes `M+1.0`.
- `minor`: `M.m` becomes `M.m+1`.
- `build`: the version stays, for a new upload of the same version.

Use the argument, or the user's words when they name one. Otherwise, list the commits since the version last changed, running this and the commands below from the repo root:

```bash
git log --oneline "$(git log -1 --format=%H -G 'MARKETING_VERSION = ' -- Chromahora.xcodeproj/project.pbxproj)"..HEAD
```

Suggest `major` when they reshape the app (a redesign, a new platform, dropped features) and `minor` otherwise, with the resulting version and build number, then wait for the user to confirm before editing.

## Check

```bash
grep -n 'configuration for PBX.* = {\|MARKETING_VERSION\|CURRENT_PROJECT_VERSION' Chromahora.xcodeproj/project.pbxproj
```

Each setting is owned by the configuration header above it. Expect exactly four settings, all under the two `configuration for PBXProject` headers, with Debug and Release agreeing. If the project lacks a setting, its Debug and Release disagree, or a `PBXNativeTarget` header holds a higher value than the project's, ask the user which value is current before changing anything. Otherwise, delete any setting under a `PBXNativeTarget` header so that target inherits the project's value again.

## Bump

Edit only those four lines. Every mode raises `CURRENT_PROJECT_VERSION` by 1, and `major` and `minor` also set `MARKETING_VERSION`.

## Verify

Run `./scripts/build.sh`, then print what each built bundle reports:

```bash
find .build/xcode/Build/Products/Debug-iphonesimulator/Chromahora.app \( -path '*.app/Info.plist' -o -path '*.appex/Info.plist' \) | while read -r plist; do
  echo "$(plutil -extract CFBundleShortVersionString raw "$plist") ($(plutil -extract CFBundleVersion raw "$plist")) ${plist#*Debug-iphonesimulator/}"
done
```

All four bundles (`Chromahora.app`, `ChromahoraWidgets.appex`, `ChromahoraWatch.app`, `ChromahoraWatchWidgets.appex`) must show the new version and build number. A bundle showing anything else sets its own, in its target's build settings or its `Info.plist`.

## Commit

Only when asked. Use the subject `Bump the version to M.m`, or `Bump the build number to N` for `build`.
