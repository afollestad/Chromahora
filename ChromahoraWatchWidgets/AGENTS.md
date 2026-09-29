## Watch widgets target

These rules cover `ChromahoraWatchWidgets/`, the watch's complications: their bundle, configuration, location source, and plist, entitlements and privacy manifest. What they show lives in `Chromahora/Widgets/`, and how they load is the phone widgets' `SkyLoader`, so `Chromahora/Widgets/AGENTS.md` and `ChromahoraWidgets/AGENTS.md` apply here too, but for location, weather and credits.

- The extension compiles the files it shares from `Chromahora/` and `ChromahoraWidgets/` through the exception sets in `project.pbxproj` on those groups whose target is `ChromahoraWatchWidgets`. List files, never folders, and create a file before listing it.
- Place the watch through `AppFixSource`, which answers no fix, so complications follow the watch app's last fix, then the zone's city. watchOS has no `isAuthorizedForWidgetUpdates`, so `WidgetLocationSource` can't compile here.
- Keep weather out: `SkyLoader.live` here has none, since a complication has no room for Apple Weather's credit. The watch app reloads the complications when it stops being active, as the phone's app does its widgets.
- Never change `PhaseComplication.kind`. Faces store it, and a new one drops the complication from every face that shows it.
- Before a device build, register `com.afollestad.Chromahora.watchkitapp.Widgets` with the App Group `group.com.afollestad.Chromahora`. Simulator builds and CI don't need it.
- Check complications on a face, since `simctl` can't add one: terminate the app to reach the face, then with `axe touch` long-press it for 1.6 s, tap Edit, swipe left to Complications, tap a slot, and pick Chromahora under All Apps. Modular's slots take the circular and rectangular layouts, and Utility's the corner and inline ones.
- `axe button home` doesn't press the Crown, so leave the face editor by restarting the simulator with `xcrun simctl shutdown` and `boot`, which keeps the face. If `axe describe-ui` stops answering there, restart it the same way.
