## Widgets target

These rules cover `ChromahoraWidgets/`, the widget extension: its bundle, each widget's configuration, the timeline provider, the location source, and its plist, entitlements and privacy manifest. What the widgets show, and how it loads, lives in `Chromahora/Widgets/`.

- The extension compiles the files it shares from `Chromahora/` through the exception set in `project.pbxproj` on the `Chromahora` group whose target is `ChromahoraWidgets`. List files, never folders, which would bring their `AGENTS.md` along, and add a file whenever a shared one starts using a type it defines.
- Create a file before listing it. Xcode, while it has the project open, drops an entry whose file doesn't exist when it next saves, and the build then fails on the missing type.
- Keep the extension's Swift settings the app's, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` above all, since the shared files mean something else without it. Its versions come from the project level, since App Store validation wants them equal to the app's.
- Keep `SkyTimelineProvider` nonisolated, since WidgetKit doesn't say which thread calls it. It hands the loading to the main actor in a task and passes back only Sendable values.
- Never change a widget's `kind`. Home Screens store it, and a new one drops the widget from every screen that shows it.
- Locate through `WidgetLocationSource`, never the app's `CoreLocationSource`: a widget can't show the permission prompt, so it reads location only once the app has When In Use permission and the person allows the widgets', which iOS asks once a widget is added. Report denied only for the app's own denial, which forgets the last fix, so widgets that aren't allowed keep the app's.
- Before a device build, register the App Group `group.com.afollestad.Chromahora` on both App IDs, and enable WeatherKit for `com.afollestad.Chromahora.Widgets` under both Capabilities and App Services. Simulator builds and CI need neither, but until WeatherKit is enabled the widgets' own forecast requests fail.
- Check widgets on the simulator's Home Screen, since `simctl` can't add one: terminate the app to reach it, then with `axe touch` long-press the wallpaper for 1.5 s, tap the top-left edit button, Add Widget, then Chromahora. The same edit button's Customize switches to the tinted and clear appearances, which take the sky away.
