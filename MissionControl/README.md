# BUS210 Mission Control

BUS210 Mission Control is a native macOS control panel for safe, instructor-facing course operations. Lesson Visibility is the first feature module; additional course controls can be added through the feature, store, and service layers without duplicating course state.

## Source and save behavior

- `../course-map.json` remains the source of truth.
- The app reads lesson/module names and states from that file; it has no built-in duplicate lesson list.
- Every lesson card remains listed on the student homepage. The `visible` field controls student access: available lessons retain their functional links, while locked lessons render as accessible noninteractive coming-soon previews with no exposed lesson URL.
- Pending lesson-access changes are shown before save.
- A save checks that the source has not changed since load, preserves unknown JSON fields, changes only the selected lessons' `visible` boolean bytes, rebuilds `../index.html`, and validates the result.
- If generation or validation fails, the app restores the original source map and attempts to restore the generated homepage.

## Run locally

From the BUS210 repository root:

```sh
./script/build_and_run.sh
```

The script builds the Swift package and stages `MissionControl/dist/BUS210 Mission Control.app`. Use `--verify` to confirm that the bundled app launches.

The app icon is generated from the editable vector master at `MissionControl/Assets/AppIcon.svg`. `script/build_app_icon.sh` renders the complete macOS iconset and `.icns`; `build_and_run.sh` embeds that resource and writes `CFBundleIconFile` before signing the app.

Run the framework-free source-data safety checks with:

```sh
./script/test_mission_control_core.sh
```

The checks use a temporary copy of the actual BUS210 course map; they do not alter the maintained source.

## Publish to Main

Publishing is a separate, explicit feature module; saving lesson visibility never commits or pushes. **Run Publishing Preflight** fetches `origin/main`, verifies that the checkout is synchronized on `main`, checks GitHub authentication with a dry-run push, validates the course-map/homepage/welcome-page sources and generated outputs, and lists every file that would be included.

Publishing remains blocked when the branch is not synchronized `main`, conflicts or pre-staged work exist, a required source/build file is missing, validation is stale, authentication fails, or any changed path is outside the reviewed BUS210 implementation scope. After a successful preflight, the app requires a confirmation dialog. It then rebuilds and validates again, verifies that the reviewed files have not changed, stages only the listed paths with an explicit path list (never `git add -A`), creates the user-labeled commit, and pushes `main`.

The result view distinguishes staging, commit, and push results. A successful push does not mean GitHub Pages is already live; Pages deployment is separate and asynchronous, so the app links to GitHub Actions for deployment status.

For a moved app bundle, use **Change Repository…** in the sidebar to select and remember a complete BUS210 source checkout. `BUS210_REPO_ROOT` remains available as an environment override. The bundled Node runtime used by Codex is discovered automatically; `BUS210_NODE_PATH` is also supported.
