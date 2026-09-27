## Timeline

These rules cover `Chromahora/Timeline/` and its tests in `ChromahoraTests/Timeline/`.

### Design

- Vertical position is proportional to time of day. Never compress or stretch phases to make them more visible; zoom (`pointsPerHour`) and scrolling are the only tools.
- All positions come from `SolarDay.fraction(of:)`. Never hard-code hours or minutes in views.
- The sky gradient interpolates in perceptual color space, holds color across night and daylight, peaks at the midpoint of blue and golden hours, and crosses a mauve stop between them. Blue and golden are near-complementary and blend to mud otherwise.
- The title's glass is tinted with `SkyGradient.color(at:in:)` behind its center, and the navigation bar's color scheme follows that color's luminance, not the phase, since phases blend into each other.
- The timeline draws edge to edge, so its content sees zero safe-area insets. Inset labels by the per-edge `safeAreaInsets` that `DayTimeline` measures outside `ignoresSafeArea`, never by a fixed padding alone.
- Keep `labelSpacing` in `DayTimelineOverlay` larger than the glass container's merge distance so stacked capsules never fuse.

### Verifying

- Check anything in the navigation bar over three backdrops: around 3 AM (night), mid afternoon (daylight), and with `now` near 11:35 AM, which puts the title over the sunrise blend where the bar's scheme flips.
- Check label changes with `SIMULATOR="iPhone 17e"` at `xcrun simctl ui <udid> content_size accessibility-medium`, then reset it to `large`. The 17e is the narrowest iPhone simulator at 390pt and AX1 is the labels' size cap, so labels collide there first.
- Check edge-hugging changes in landscape too: call `requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))` on the window scene from a temporary `.task`, and capture with `--mask=black` to see the Dynamic Island.
