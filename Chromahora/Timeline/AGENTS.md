## Timeline

These rules cover `Chromahora/Timeline/` and its tests in `ChromahoraTests/Timeline/`.

### Design

- Vertical position is proportional to time of day, every position comes from `SolarDay.fraction(of:)`, and every time or duration from the model. Never compress or stretch phases or hard-code hours in views; zoom (`pointsPerHour`) and scrolling are the only tools.
- The sky gradient interpolates in perceptual color space, holds color across night and daylight, and crosses a mauve stop between blue and golden hours, which are near-complementary and blend to mud otherwise. Blue and golden hours hold their color over `DaySegment.heldColorRange`, which narrows to the midpoint for normal-length ones.
- Emit exactly two gradient stops per segment, plus a bridge between blue and golden, so the stop count depends only on the phase sequence. Gliding between days animates stop locations, which needs matching counts.
- The timeline draws edge to edge, so its content sees zero safe-area insets; inset labels by the per-edge `safeAreaInsets` that `DayPager` measures where the push never moves them, never by a fixed padding alone. The day panel's `panelInset` adds to the trailing one, and lines and `SourcesButton` stop short of it too, since its glass would show a line through its text.
- Pad the scroll content by the safe area plus `edgeClearance` at both ends, so midnight at either end scrolls clear of the bars. Use padding, not `contentMargins`, which would also move where the timeline centers on its focus.
- The bars take their soft edge effect from `DayPager`'s sideways scroll view, not the timeline's: hidden there, nothing blurs, and its default style lays a flat band. It fades toward the copy of the sky and ruler scrim behind the pages, which follow the timeline's scroll, so paint anything new onto that copy too, or the bars tint what's under them.
- Each label takes the color scheme of the sky behind it from `SkyGradient.labelScheme(over:)`, since white text on daylight contrasts at 1.5:1. Keep labels out of a `GlassEffectContainer`, which renders every capsule in the container's scheme.
- Weather spells are markers in the leading column, so the overlay's spacing keeps them off every label; never position them separately. Only precipitation draws a line, since sky lines would stripe the whole day.
- Keep `SourcesButton`'s `safeAreaBar` on `DayPager`, outside its pages and the `onGeometryChange` that measures `safeAreaInsets`, so the bottom inset clears it and it stays put as pages push past. It takes its scheme through `prefersDarkBar(over:wasDark:)`, like the bar, not `labelScheme(over:)`, and `PageDots` hang from it in an overlay, since height added to the bar widens the band the edge effect blurs.
- Page between days by moving `DayPager`'s live pages with an animated `offset`, never a transition, and open an incoming page at its end with `defaultScrollAnchor`, not a scroll once it appears. Either one leaves the page's sky copy standing where the push ends, over the leaving page.

### Verifying

- Check label changes with `SIMULATOR="iPhone 17e"` at `xcrun simctl ui <udid> content_size accessibility-medium`, then reset it to `large`. The 17e is the narrowest iPhone simulator at 390pt and AX1 is the labels' size cap, so labels collide there first.
- Check edge-hugging changes in landscape too: call `requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))` on the window scene from a temporary `.task`, and capture with `--mask=black` to see the Dynamic Island.
