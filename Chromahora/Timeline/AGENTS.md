## Timeline

These rules cover `Chromahora/Timeline/` and its tests in `ChromahoraTests/Timeline/`.

### Design

- Vertical position is proportional to time of day. Never compress or stretch phases to make them more visible; zoom (`pointsPerHour`) and scrolling are the only tools.
- All positions come from `SolarDay.fraction(of:)`, and every time or duration from the model. Never hard-code hours or minutes in views.
- The sky gradient interpolates in perceptual color space, holds color across night and daylight, and crosses a mauve stop between blue and golden hours, which are near-complementary and blend to mud otherwise. Blue and golden hours hold their color over `DaySegment.heldColorRange`, which narrows to the midpoint for normal-length ones.
- Emit exactly two gradient stops per segment, plus a bridge between blue and golden, so the stop count depends only on the phase sequence. Gliding between days animates stop locations, which needs matching counts.
- The timeline draws edge to edge, so its content sees zero safe-area insets. Inset labels by the per-edge `safeAreaInsets` that `DayTimeline` measures outside `ignoresSafeArea`, never by a fixed padding alone.
- Keep `labelSpacing` in `DayTimelineOverlay` larger than the glass container's merge distance so stacked capsules never fuse.

### Verifying

- Check label changes with `SIMULATOR="iPhone 17e"` at `xcrun simctl ui <udid> content_size accessibility-medium`, then reset it to `large`. The 17e is the narrowest iPhone simulator at 390pt and AX1 is the labels' size cap, so labels collide there first.
- Check edge-hugging changes in landscape too: call `requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))` on the window scene from a temporary `.task`, and capture with `--mask=black` to see the Dynamic Island.
