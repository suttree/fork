# Fork Implementation Plan

This file tracks the next concrete steps for turning Fork from a concept into a working prototype.

The first goal is a thin vertical slice:

```text
Create identity -> write Markdown -> sign record -> verify record -> render page -> exchange with another local peer
```

That slice should prove the heart of Fork before the app grows wider.

## Current Focus

Build the smallest native macOS prototype that can read and write verified Markdown records.

The first prototype does not need perfect UI, real internet discovery, themes, or multi-device support. It does need to treat p2p, signing, and offline/cached reading as core concepts from the beginning.

## Prototype Progress

Status: First in-memory vertical slice implemented.

- Added a Swift Package with a `ForkCore` library and a small SwiftUI `ForkApp`.
- Added key-derived author and document addresses using CryptoKit signing keys.
- Added signed author manifests and signed document records with stable JSON encoding.
- Added previous-record hashes so signed updates point back to the records they replace.
- Same-version signed records no longer replace already cached records.
- Newer signed records now have to point back to the cached record they replace.
- Added verification before rendering; tampered records are refused.
- Signed document verification now rejects malformed author public keys.
- Signed document verification now rejects malformed document public keys.
- Signed manifest shape validation now rejects malformed document addresses before cache acceptance.
- Added a local two-peer exchange loop that fetches from an author peer, caches verified records on a reader peer, and renders the cached copy when no live author peer is available.
- Added a local identity store abstraction with a Keychain-backed implementation for the macOS app.
- Added stable stored document identity for the demo home page.
- Added a file-backed verified record cache for manifests and document records.
- Added a file-backed draft store and wired the demo publish path to it.
- Wired the prototype editor to save drafts and publish signed records from the current draft.
- Added a draft list in the writer, with new-page creation and selection.
- Added a first-class Add Page action in the writer so authors can grow a place from the writing flow.
- Publishing from any page keeps the `home` draft as the author place home while including added pages in the manifest.
- Publishing an added page keeps that page visible after publish instead of bouncing the reader back to Home.
- Added draft deletion for non-home pages in the writer.
- Added explicit local page ordering for writer drafts.
- Legacy drafts without saved order are normalized when the author creates a new page.
- Page-order controls now disable impossible moves and label non-home pages by position.
- Added multi-document publishing so the signed author manifest can list every local draft.
- Added author record bundles so peers exchange signed records through a portable boundary instead of shared in-memory state.
- Incomplete author bundles are rejected before anything is cached.
- Bundles with bad update chains are rejected before any newer manifest or document is cached.
- Author bundles with duplicate document records are rejected before anything is cached.
- Author bundles now reject manifest page titles that disagree with the signed document records.
- Author bundles now reject manifests whose home page is not one of the listed document pages.
- Manifests now reject duplicate document addresses and page roles that disagree with the home document.
- Cache reload now restores only complete verified author bundles after restart.
- Verified cached peers can re-serve author bundles to other readers.
- Added a byte-oriented bundle codec and source protocol so transports can move encoded signed record bundles.
- Added a loopback HTTP transport that serves and fetches encoded author bundles over localhost.
- Wired the prototype app's publish/read path through the loopback transport.
- Added a second sample author place in the app, fetched over its own loopback peer.
- Added a sample-author online/offline toggle to demonstrate verified cached reading in the app.
- Added address entry, persisted bookmarks, and basic back/forward history to the prototype app.
- The app now restores the last visited Fork address on launch when it can be rendered.
- Browsing history now persists across launches as verified Fork addresses.
- History can now be cleared from the sidebar.
- History entries now prefer verified cached page titles over generic address labels.
- Added verified cached rendering for `fork://doc/...` document deep links.
- Added local bookmark nicknames so ugly key addresses can have personal labels.
- Bookmark rows now distinguish author places from document pages.
- Bookmark rows can now delete saved bookmarks from the sidebar.
- Added document-address bookmarks and visible history entries in the sidebar.
- Added copy controls for author and document addresses in the reader.
- Added document version and previous-record hints in the reader.
- Surfaced live/cached/unavailable status in the browsing address bar.
- Cached status messages now include the cached copy timestamp in the address bar.
- Unavailable address states now explain invalid addresses, missing cached copies, and failed verification calmly.
- Added a signed place page list in the sidebar from the current author manifest.
- Place and writer sidebars now label home/current/page roles instead of leaning on raw addresses.
- Added colorful local reader themes for Classic, Starship, and NvChad reading modes.
- Added tests for the vertical slice, tamper refusal, and key-derived addresses.

Still not done:

- The writer can create, select, edit, and delete local pages, but it still needs a more polished document manager for page roles and ordering.
- The peer loop is local/in-process, not a real p2p transport.
- The app shell is intentionally plain and only demonstrates the slice.

## Milestone 1: Project Scaffold

Status: Mostly done

- Create native macOS app scaffold.
- Prefer Swift and SwiftUI.
- Keep the app small and plain at first.
- Add a simple split between reading and writing.
- Add basic local persistence for drafts and verified records.

Output:

- App launches.
- User can see an empty reader/writer shell.

Notes:

- Verified records can now be mirrored to a file-backed cache.
- Drafts can now be mirrored to a file-backed store.

## Milestone 2: Local Identity

Status: Mostly done

- Generate an author keypair on first launch.
- Store private key securely.
- Derive a `fork://author/<key>` address from the public key.
- Show the address in the app.
- Add a way to copy the address.

Output:

- A fresh install has a stable Fork author address.
- The private key stays local.

Notes:

- `ForkApp` now loads or creates its author identity through Keychain.
- Tests use an in-memory identity store so they do not touch the user's Keychain.
- The reader exposes copy controls for key-derived addresses.

## Milestone 3: Markdown Documents

Status: Mostly done

- Create a Markdown document.
- Assign it a stable document identity.
- Derive a `fork://doc/<key>` address.
- Edit Markdown locally.
- Render Markdown in a read view.

Output:

- User can write and preview one local Fork page.

Notes:

- The demo home document now loads or creates its document identity through the same app identity provider, so its `fork://doc/...` address is stable across launches.
- The demo home draft now loads from a draft store when one exists, otherwise it creates the default Markdown draft.
- The prototype editor can now save edits back to the draft store and publish a signed record from the current draft.
- The writer now quietly autosaves local title and Markdown edits after a short pause.
- The writer has an edit/preview switch for local Markdown drafts.
- Draft titles are now trimmed before saving, with blank titles falling back to `Untitled Page`.
- The writer can now create and switch between local Markdown drafts. Each draft uses its own stored document identity when published.
- The writer exposes Add Page from the writing surface, so authors can add pages without hunting through the sidebar.
- The writer exposes move-up and move-down controls for non-home pages.
- The writer labels ordered pages as Page 1, Page 2, etc. while keeping Home distinct.
- Publishing an added page no longer accidentally promotes it to the home page; the protected `home` draft remains the place entry point.
- After publishing an added page, the reader stays on that page while the author address still resolves to Home.
- The writer shows the selected draft's stable document address with a copy control.
- Visiting one of your own signed pages now selects the matching local draft in the writer.
- Non-home drafts can now be deleted from the writer, with confirmation, before the next signed publish.
- Publishing now signs document records for every local draft and lists them in the author manifest, with the protected `home` draft as the home document.
- Republishing after removing a page exports only the documents listed by the latest author manifest.
- Cached document addresses can now be rendered directly as verified deep links.
- The sidebar can now show and visit the pages listed by the current verified author manifest.
- The reader toolbar can now jump from a document page back to the current place's home page.
- Next: improve page roles and page-management polish.

## Milestone 4: Signed Records

Status: Started

- Define first JSON shape for author manifests.
- Define first JSON shape for document records.
- Sign document records.
- Sign author manifests.
- Verify signatures before rendering.
- Refuse to render invalid records.
- Link signed updates to the previous signed record hash.
- Keep existing cached records when another valid record arrives with the same version.
- Require newer records to link to the cached previous record before replacing it.
- Validate signed record type and key shape before accepting records into cache.
- Validate document address key shapes listed by author manifests before accepting them into cache.
- Validate that manifest page roles agree with the declared home document.

Output:

- Fork renders verified Markdown, not arbitrary local text.
- Invalid signatures fail visibly and calmly.
- Signed records form a simple auditable update chain.

## Milestone 5: Local Peer Loop

Status: Mostly done

- Run two local peer instances on one machine.
- Publish a signed document from peer A.
- Fetch it from peer B.
- Verify it on peer B.
- Cache it on peer B.
- Render it from cache if peer A is offline.

Output:

- The core p2p/offline behavior works locally.
- Cached signed content remains readable when the author peer is unavailable.

Notes:

- The local loop is still in-process, but verified records now survive peer restart through `FileRecordCache`.
- Invalid signatures and malformed cache files are ignored on load rather than rendered.
- Incomplete bundles are rejected without partially caching their manifests or documents.
- Bad update chains in bundles are rejected before any partial cache mutation.
- Fetching now goes through encoded `AuthorRecordBundle` data, which is closer to the shape a real transport will move across the network.
- A reader with verified cached records can now act as an `AuthorBundleSource` for another reader.

## Milestone 6: First Real P2P Transport

Status: Started

- Choose the p2p building block.
- Prefer boring, proven infrastructure.
- Evaluate whether the networking core should be Swift-native or a small helper process.
- Add peer discovery.
- Exchange manifests, document records, and blobs over the network.
- Serve cached verified records to other peers.

Output:

- Two machines can exchange and verify Fork pages.

Notes:

- The first transport is intentionally local-only: `LoopbackAuthorBundleServer` and `LoopbackAuthorBundleClient` exchange encoded author bundles over HTTP on localhost.
- This is not real p2p discovery yet, but it proves the app can move signed records through a socket boundary and verify/cache them on the receiving side.
- The app now uses that localhost transport for its prototype author-to-reader flow.
- The app also starts a second sample author peer with a stable local identity, so the read path can visit another local author address through the same transport.

## Milestone 7: Offline-First UX

Status: Started

- Show whether the page is live, cached, or unavailable.
- Show cache age.
- Keep offline states calm.
- Keep reading possible whenever a verified cached copy exists.

Output:

- Offline is treated as a normal reading state.

Notes:

- The address bar now shows the current browsing status so live, cached, and unavailable states are visible outside the writer panel.
- The address bar can now copy the current Fork address directly and confirm the copy.
- The address bar includes cache timestamps when showing a verified cached copy.
- Address failures now distinguish invalid Fork addresses, unavailable verified cache entries, and refused unverifiable records.
- The sample author can be taken offline in the app after a live visit, so the cached-reader path is visible without leaving the prototype.
- The reader has a persisted theme picker with colorful reader-owned Classic, Starship, and NvChad modes. Authors may publish content and metadata, but the reader keeps final control of how pages look locally.

## Milestone 8: Bookmark-Led Browsing

Status: Started

- Bookmark author addresses.
- Bookmark document addresses.
- Add local nicknames for ugly addresses.
- Add history and back/forward.
- Keep the app tabless.

Output:

- Fork browsing starts to feel different from URL/domain browsing.

Notes:

- The app now has a Fork address field, bookmark persistence, and back/forward history for visited author places.
- The app remembers the last visited Fork address across launches.
- Browsing history now persists across launches.
- History can now be cleared from the sidebar.
- The address field can visit cached author and document addresses.
- The address field can copy the current Fork address.
- History entries use verified cached page titles when available.
- History rows now label author places and document pages instead of showing raw keys inline.
- Bookmarks now support local nicknames.
- Bookmarking can now save author and document addresses.
- Bookmark saves now distinguish new bookmarks from updated nicknames.
- Bookmark nicknames are now trimmed before saving, with blank nicknames falling back to page titles.
- Bookmark rows show whether a saved address is an author place or document page.
- Bookmark rows can now delete saved entries.
- History rows refresh immediately when bookmark nicknames are saved or deleted.
- The place page list now labels home and current pages clearly while keeping raw addresses available as help text.
- The reader Home action now returns through the author place address, not just the home document deep link.

## First Technical Questions To Resolve

- Should document keys be independent keypairs, or should document addresses be derived from author key plus document id?
- Which Swift Markdown renderer gives us the best constrained rendering path?
- Can CryptoKit cover the signing model cleanly?
- What is the most maintainable p2p layer for a native Mac app?
- Should the local peer loop be implemented before or after the visible app shell?

## Near-Term Definition Of Done

The first vertical slice is done when:

- one local author can publish a signed Markdown document
- another local peer can fetch it
- the second peer verifies it before rendering
- the second peer can still render its cached verified copy when the first peer is offline
- the UI clearly says when a page is cached

No tabs. No JavaScript. No domains.
