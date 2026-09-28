## Screen

These rules cover `Chromahora/Screen/`: the screen around the timeline, its toolbar and placeholders.

### Design

- The title's glass is tinted with `SkyGradient.color(at:in:)` behind its center, and the navigation bar's color scheme follows that color's luminance, not the phase, since phases blend into each other.
- Keep one toolbar, on `DayScreen`. Per-state toolbars double up while the placeholder leaves and close an open popover.
- Give the timeline the day panel's footprint as `panelInset` and the placeholder as `safeAreaPadding`, both zero without a panel. Never branch around them for it, which rebuilds them and loses the scroll and the glow.
- Align anything to the screen's edges, like the panel, on `DayScreen`'s `Color.clear` base rather than inside its layers. The loading glow is wider than the screen, and widens any stack that holds it past both edges.
- Give anything presented from the toolbar `.foregroundStyle(Color.primary)`, not `.primary`, and `.tint(.accentColor)`. Once a drag turns the bar dark, its items pass white down.
- Start looping animations with `withAnimation` from `.task`, never `.animation(_:value:)`, so the snapshot harness's transaction can stop them on their end state.
- SwiftUI keeps the transition a view was inserted with, so turn a removal effect on or off through the animation that drives it, as `DayScreen` does for the reveal.
- A mask inside a transition lays out in the safe area. Give its content `.ignoresSafeArea()`, or it uncovers the system background under the bar and home indicator.

### Verifying

- Check the wide layout on the iPad mini (A17 Pro) in portrait, the narrowest regular width, and on the iPhone 18 Pro Max in landscape, whose size class flips as an unfolding phone's does; no foldable simulator exists. Check the panel in both appearances, over daylight and night.
- Check anything in the navigation bar over three backdrops: around 3 AM (night), mid afternoon (daylight), and with `now` near 11:35 AM, which puts the title over the sunrise blend where the bar's scheme flips.
- Check anything the toolbar presents after a real drag that leaves the title over the night sky and daylight below it; launch-time checks and a programmatic `scrollTo` don't make the bar pass its colors down. `simctl` can't drag, so drag with `axe drag`.
- Check transitions in a recording, since screenshots land about 250 ms apart: `xcrun simctl io <udid> recordVideo --codec=h264 <file>`, stopped with `SIGINT`. `-DebugProviderMode slow` delays a load long enough to watch the reveal.
