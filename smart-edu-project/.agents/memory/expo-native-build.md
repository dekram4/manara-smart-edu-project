---
name: Expo Native Web Build Quirks
description: Lessons from building Expo web bundles in Replit sandbox environment
---

## `expo export -p web` fails silently (empty dist)

The `expo export` command can exit with code 0 but produce an empty `dist/` folder when `react-dom` is missing from the dependency tree, even though `react-native-web` is present. Always verify `react-dom` is installed alongside `react`.

## `xdg-open` kills the Expo dev server on Linux headless

`expo start --web` automatically tries to open a browser via `xdg-open`. In a headless Linux container, this fails with "exited with non-zero code: 1" and the entire Metro bundler crashes. The `EXPO_NO_OPEN=1` env var does not prevent the crash.

**Fix:** Override `xdg-open` in PATH with a no-op shell script:
```sh
mkdir -p /tmp/fakebin
echo '#!/bin/sh\nexit 0' > /tmp/fakebin/xdg-open
chmod +x /tmp/fakebin/xdg-open
export PATH="/tmp/fakebin:$PATH"
```

## `expo-router` v57 + `@react-navigation` conflict

Expo SDK 57 (expo-router 57.x) is incompatible with direct `@react-navigation` imports. The bundler throws:
> "As of SDK 56, expo-router is no longer compatible with react-navigation"

**Fix:** Remove `expo-router` from the project entirely if using `@react-navigation/native` + stack directly. `npm uninstall expo-router`.

## Metro bundler hangs at ~83% on web export

The bundler can stall indefinitely without error when building for web. This is usually because of the missing `react-dom` dependency (web render needs `react-dom/client`).

**Fix:** `npm install react-dom@matching-react-version`.

## Static web preview vs. native build

For web preview in Replit's preview pane, export a static bundle with `expo export -p web`, then serve the `dist/` folder via a simple Node.js HTTP server. The `expo start --web` dev server is unreliable in headless containers.
