# fork

fork is a native Mac Markdown editor for building a small personal wiki, digital garden, portfolio, or notebook.

The project has pivoted away from the earlier peer-to-peer publishing prototype. The current app is focused on the writing experience: local pages, Markdown preview, wiki links, keyboard shortcuts, calm themes, and fast iteration.

## Try the Prototype

Build a local app bundle:

```sh
./Scripts/build-app.sh
```

Then launch it:

```sh
open .build/Fork.app
```

## Current Shape

- Native macOS app built with SwiftUI and AppKit.
- Local file-backed Markdown drafts.
- A page sidebar for switching, reordering, and deleting pages.
- Modal editor with View and Edit modes.
- Wiki-style links using `[[Page Title]]`.
- Following a missing wiki link creates a new draft page.
- Autosave while editing.
- Keyboard shortcuts in the editor:
  - `Command-B` wraps the selected text in Markdown bold.
  - `Command-U` wraps the selected text in underline HTML.
  - `Command-E` toggles View/Edit mode.
  - `:e` toggles View/Edit mode when the editor is not focused.
- Pasting a web URL over selected text creates a Markdown link.
- Reader-owned themes, including the `Oudh` theme based on duncangough.com.

## Product Principles

- Editing first: the app should feel closer to Byword, Bear, iA Writer, or a personal wiki than a browser.
- Markdown stays visible: source text remains portable and understandable.
- Pages are made by linking: write `[[Projects]]`, follow it, and fill in the page.
- Local-first: drafts live on disk and should remain useful without accounts, servers, or unlock prompts.
- Native first: avoid Electron and make the app feel at home on macOS.
- Calm UI: no tabs, bookmarks, history, address bars, or publishing ceremony in the core writing flow.

## MVP

The MVP should make writing a small personal site/wiki feel excellent before adding network features again.

MVP capabilities:

- launch native Mac app
- edit local Markdown pages
- preview rendered Markdown
- create pages from `[[Wiki Links]]`
- show all local pages in the sidebar
- autosave drafts
- support common writing shortcuts
- paste URLs onto selected text as Markdown links
- switch themes across the whole app
- feel elegant and uncluttered

Out of scope for the current MVP:

- peer-to-peer networking
- document signing
- publishing
- keychain identity prompts
- address bars
- bookmarks
- browsing history
- remote discovery
- analytics, feeds, likes, comments, or arbitrary web rendering
