<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
**Titolo:** [Open source] OpenTunes – now playing in your menu bar, notch, desktop widget and Last.fm/ListenBrainz scrobbling (free, GPL)

Hi r/macapps! I'm the developer of OpenTunes, a free and open-source (GPL-3.0) app for macOS 26+ that shows
what's playing and lets you control it from everywhere:

- **Menu bar**: artwork, scrolling title with a custom format, controls, love; auto-compact next to the notch
- **Notch player**: artwork and a playing indicator around the notch, expands on hover with controls and progress
  (a glass capsule on Macs without a notch; can be turned off if you use another notch app)
- **Desktop widget**: live progress bar, three layouts, resizable, lockable, optional Last.fm chart
- **macOS widgets** in three sizes with interactive play/pause, skip and love buttons
- **Floating Liquid Glass player** tinted with the album colours, HUD, notifications, global shortcuts
- **Scrobbling** to Last.fm and/or ListenBrainz from any player (Apple Music, Spotify, YouTube in the browser…),
  offline queue, clean-up of "(Remastered)", "[Official Video]" and similar tags
- Album artwork as the **Dock icon** (optional)

It works with any app that publishes to the system Now Playing, with an AppleScript fallback for Music and Spotify.

Download (DMG) and source: https://github.com/Akiakizero/OpenTunes — or `brew install --cask Akiakizero/tap/opentunes`.
The app isn't notarized yet, so the README explains how to remove the quarantine flag.

It's an independent project, not affiliated with NepTunes or Apple. Feedback and bug reports are very welcome!
