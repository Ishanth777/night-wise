# maplibre_gl_web stub

NightWise targets Android and iOS with the real MapLibre GL plugin.

The upstream `maplibre_gl_web` 0.21 backend calls `ui.platformViewRegistry`,
which no longer exists in the current Flutter web engine (it moved to
`dart:ui_web`), so a web build fails at compile time. Because the web target is
a secondary preview, `lib/widgets/night_map_stub.dart` draws the routes on a
canvas instead, and this no-op plugin prevents the broken web implementation
from being registered.

Remove the `dependency_overrides` entry in `../../pubspec.yaml` once
`maplibre_gl_web` supports the installed Flutter version; the canvas preview
can then be replaced by the native map implementation on web too.
