# fork Implementation Plan

This file tracks the current editor-first direction for fork.

## Product Direction

fork is now a native Mac Markdown editor for local personal wikis and digital gardens.

The earlier p2p/signing/browser prototype has been removed from the active app direction. That work helped clarify the product, but the MVP should now focus on whether writing in fork feels good enough to become a daily tool.

The app should feel closer to Byword, Bear, iA Writer, or a small personal wiki than a browser. Pages are created by writing links, not by managing addresses.

## Current Focus

Build a polished local Markdown editor with:

- modal View/Edit workflow
- page list sidebar
- local file-backed drafts
- wiki-style `[[Page Title]]` links
- keyboard-first formatting
- whole-app themes
- no publishing, signing, unlock prompts, history, bookmarks, address bars, or p2p network surface

## Completed

- Reframed fork around editing rather than publishing.
- Removed the active p2p/signing/document-address app path.
- Removed bookmarks, history, address browsing, sample peers, and publish controls from the app UI.
- Kept a local file-backed draft store as the core persistence layer.
- Added a page-only sidebar for selecting, reordering, and deleting local pages.
- Added modal View/Edit mode.
- Added `Command-E` and `:e` mode toggles.
- Added `Command-B` Markdown bold wrapping for selected editor text.
- Added `Command-U` underline wrapping for selected editor text.
- Added paste-over-selection URL handling, producing Markdown link syntax.
- Added `[[Page Title]]` wiki links that open existing local pages or create missing pages.
- Added the `Oudh` theme based on duncangough.com: pale green patterned background, serif typography, blue text, and blue links.
- Renamed the app-facing title to `fork`.
- Replaced the eye icon with the magic/book artwork.

## MVP Definition

The MVP is in good shape when:

- Writing and previewing a page feels calm and immediate.
- The sidebar makes a small wiki or portfolio easy to navigate.
- Wiki links are natural enough that authors do not think about URLs.
- Common keyboard actions work without reaching for toolbar buttons.
- Themes apply across the whole app and feel intentional.
- The app opens without keychain prompts or network setup.
- Drafts survive restart reliably.

## Near-Term Next Steps

- Improve Markdown rendering coverage beyond headings and paragraphs.
- Add inline toolbar or menu commands for bold, underline, and link creation.
- Add a faster page switcher/search command.
- Add backlinks or “linked mentions” for wiki pages.
- Add export to a folder of Markdown files.
- Add import from a folder of Markdown files.
- Decide whether local pages should eventually be plain `.md` files instead of JSON draft records.
- Revisit publishing only after the local editor feels excellent.

## Out Of Scope For Current MVP

- P2P networking
- signed records
- document keys
- author identities
- keychain storage
- publishing
- remote discovery
- bookmarks
- browsing history
- address bars
- arbitrary HTML or JavaScript execution
