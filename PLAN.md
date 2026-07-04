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
- Added verification before rendering; tampered records are refused.
- Added a local two-peer exchange loop that fetches from an author peer, caches verified records on a reader peer, and renders the cached copy when no live author peer is available.
- Added tests for the vertical slice, tamper refusal, and key-derived addresses.

Still not done:

- Private keys are not stored in Keychain yet.
- Drafts and verified records are in memory, not persisted to disk.
- The peer loop is local/in-process, not a real p2p transport.
- The app shell is intentionally plain and only demonstrates the slice.

## Milestone 1: Project Scaffold

Status: Started

- Create native macOS app scaffold.
- Prefer Swift and SwiftUI.
- Keep the app small and plain at first.
- Add a simple split between reading and writing.
- Add basic local persistence for drafts and verified records.

Output:

- App launches.
- User can see an empty reader/writer shell.

## Milestone 2: Local Identity

Status: Started

- Generate an author keypair on first launch.
- Store private key securely.
- Derive a `fork://author/<key>` address from the public key.
- Show the address in the app.
- Add a way to copy the address.

Output:

- A fresh install has a stable Fork author address.
- The private key stays local.

## Milestone 3: Markdown Documents

Status: Started

- Create a Markdown document.
- Assign it a stable document identity.
- Derive a `fork://doc/<key>` address.
- Edit Markdown locally.
- Render Markdown in a read view.

Output:

- User can write and preview one local Fork page.

## Milestone 4: Signed Records

Status: Started

- Define first JSON shape for author manifests.
- Define first JSON shape for document records.
- Sign document records.
- Sign author manifests.
- Verify signatures before rendering.
- Refuse to render invalid records.

Output:

- Fork renders verified Markdown, not arbitrary local text.
- Invalid signatures fail visibly and calmly.

## Milestone 5: Local Peer Loop

Status: Started

- Run two local peer instances on one machine.
- Publish a signed document from peer A.
- Fetch it from peer B.
- Verify it on peer B.
- Cache it on peer B.
- Render it from cache if peer A is offline.

Output:

- The core p2p/offline behavior works locally.
- Cached signed content remains readable when the author peer is unavailable.

## Milestone 6: First Real P2P Transport

Status: Not started

- Choose the p2p building block.
- Prefer boring, proven infrastructure.
- Evaluate whether the networking core should be Swift-native or a small helper process.
- Add peer discovery.
- Exchange manifests, document records, and blobs over the network.
- Serve cached verified records to other peers.

Output:

- Two machines can exchange and verify Fork pages.

## Milestone 7: Offline-First UX

Status: Not started

- Show whether the page is live, cached, or unavailable.
- Show cache age.
- Keep offline states calm.
- Keep reading possible whenever a verified cached copy exists.

Output:

- Offline is treated as a normal reading state.

## Milestone 8: Bookmark-Led Browsing

Status: Not started

- Bookmark author addresses.
- Bookmark document addresses.
- Add local nicknames for ugly addresses.
- Add history and back/forward.
- Keep the app tabless.

Output:

- Fork browsing starts to feel different from URL/domain browsing.

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
