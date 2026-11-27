# Jellyfin Player

A customisable Jellyfin client for iPhone, iPad and Apple TV, built with SwiftUI and the official
[Jellyfin Swift SDK](https://github.com/jellyfin/jellyfin-sdk-swift).

## Status

Steps 1 and 2 are in: connect to a server, pick a user (password or Quick Connect), stay signed in, and
browse your library with Continue Watching, Next Up, Recently Added, library grids, collections, show and
episode pages, and search. Playback is next.

Collections leave out films from libraries you've hidden on the device or excluded from "My Media" in
Jellyfin, and can also hide anything tagged as 3D.

Coming next:

1. ~~App skeleton, server sign-in, user picker, saved login~~
2. ~~Library browsing: Continue Watching, Next Up, Recently Added, Movies, TV, Collections, search
   (collections only show items from libraries you've allowed)~~
3. Playback: direct play with transcode fallback, resume and watched sync, subtitle and audio defaults
   that stick
4. Customisation: themes, accent colours, choose and reorder home rows

## Getting started

You need a Mac with Xcode 26 or later (that is what CI builds with).

```sh
brew install xcodegen      # once
xcodegen generate          # whenever project.yml changes or files are added
open JellyfinPlayer.xcodeproj
```

Pick the **JellyfinPlayer** scheme for iPhone and iPad, or **JellyfinPlayerTV** for Apple TV.
To run on a real device, choose your team under *Signing & Capabilities* (or set `DEVELOPMENT_TEAM`
in `project.yml`).

The `.xcodeproj` is generated from `project.yml` and isn't committed, so there are no project-file merge
conflicts.

## Layout

```
project.yml                 XcodeGen project: iOS and tvOS targets sharing all sources
App/Sources/App             App entry point and top-level navigation
App/Sources/Core            Session state, saved servers/users, Keychain, server address handling
App/Sources/Features        Screens, grouped by feature
App/Resources               Asset catalog
```

## Notes

- Access tokens are stored in the Keychain. Server and user names are stored in UserDefaults.
- Plain `http://` servers on the local network are allowed, since that's how most home servers run.
- Typing just a host name tries `https://host`, then `http://host:8096`, then `http://host`.
