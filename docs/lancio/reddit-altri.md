<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
## r/lastfm

**Titolo:** I made a free, open-source Last.fm + ListenBrainz scrobbler for macOS that works with any player

OpenTunes scrobbles from Apple Music, Spotify, browsers and anything that shows up in the system Now Playing.
Standard rules (half the track or 4 minutes, custom threshold), pausing doesn't reset the timer, one scrobble per
listen, offline queue with batch retries, optional clean-up of "(Remastered 2011)", "- Radio Edit", "feat." tags.
Love tracks from the menu bar, the notch, the widgets or a shortcut. Your recent scrobbles and top artists also
show up in the large macOS widget and the desktop widget. Source and DMG: https://github.com/Akiakizero/OpenTunes
(I'm the developer.)

## r/opensource

**Titolo:** OpenTunes: a GPL-licensed now-playing app and scrobbler for macOS

Released v0.3 of OpenTunes, a GPL-3.0 macOS app (Swift 6, SwiftUI) that shows the current track in the menu bar,
the notch, a desktop widget and WidgetKit widgets, and scrobbles to Last.fm/ListenBrainz. Every third-party piece
is credited with its licence in CREDITS.md; contributions are welcome ("good first issue" label, CONTRIBUTING.md
in Italian/English). https://github.com/Akiakizero/OpenTunes

## r/swift

**Titolo:** Reading Now Playing on macOS 15.4+, a notch player and interactive widgets in Swift 6 strict concurrency

Some technical notes from building OpenTunes (open source, GPL):

- Since macOS 15.4 MediaRemote is closed to third-party apps; the app streams it through mediaremote-adapter
  (`/usr/bin/perl` + a framework) and falls back to AppleScript, behind a `MediaSource` protocol whose
  `updates()` stream ends when the source dies.
- Widget buttons use `AudioPlaybackIntent`, so the system runs them in the app process — no IPC needed.
  The widget's progress bar is `ProgressView(timerInterval:)`, so it moves without spending the reload budget.
- The notch player is an `NSPanel` above the menu bar that ignores mouse events until a global mouse-moved
  monitor sees the cursor over the visible shape (no Accessibility permission needed).
- `@Observable` everywhere, with an `Observations`-based helper for AppKit controllers; no Combine.

Code: https://github.com/Akiakizero/OpenTunes
