# Fork Plan

Fork is a native Mac app for writing and visiting personal Markdown places on a slow peer-to-peer network.

## Try the Prototype

Build a local app bundle:

```sh
./Scripts/build-app.sh
```

Then launch it:

```sh
open .build/Fork.app
```

The app is still a prototype shell. It should show a signed Markdown page, the calm cached/offline status, and key-derived author/document addresses. You can edit the home draft, save it, and publish a new signed record from the editor. The prototype now serves and fetches that signed record bundle over localhost.

It is not a web browser in the usual sense. It does not run JavaScript, render arbitrary HTML, support tabs, track readers, or treat engagement as a product goal. Fork is a browser/editor for signed Markdown documents that live on a peer-to-peer network and can be cached, shared, bookmarked, and revisited.

## Core Idea

Fork brings back the feeling of small personal websites, blogs, portfolios, and digital gardens, but removes the parts of the modern web that made those places feel noisy or extractive.

The app should make it easy to:

- create a personal Fork identity
- write Markdown pages and posts
- publish a signed personal place
- visit another person's Fork address
- read cached pages when the author is offline
- bookmark and wander through the network without domains, feeds, tabs, ads, or tracking

## Product Principles

- Native first: start with macOS, avoid Electron, and make the app feel at home on the Mac.
- Markdown only: pages are Markdown plus a small, explicit set of supported assets and metadata.
- No JavaScript: pages are documents, not remote programs.
- No arbitrary HTML: rendering stays constrained, predictable, and safe.
- No tabs: Fork should encourage reading and visiting, not attention hoarding.
- No domains: addresses come from cryptographic keys, not rented names.
- Offline is normal: cached signed pages are first-class, not an error state.
- Slow is a feature: freshness matters less than authorship, integrity, and calm.
- Boring infrastructure: use proven networking, storage, crypto, and Markdown tools where possible.
- User-owned identity: publishing authority belongs to the holder of the private key.

## Address Model

Fork should avoid nice domains and human-readable URLs at the protocol level.

Instead, addresses are derived from public keys:

- an author key identifies a personal place
- document keys identify individual pages
- signed manifests connect an author to their current set of documents

This gives every page a stable, unique address without DNS, accounts, usernames, or domain squatting.

Example address shapes:

```text
fork://author/<author-public-key>
fork://doc/<document-public-key>
```

The author address is the main browsing entry point. Visiting it means:

```text
Find the latest valid signed manifest for this author.
Render the author's selected home document.
```

Document addresses are stable deep links. Visiting one means:

```text
Find the latest valid signed state for this document.
Verify it belongs to the expected document key.
Render the Markdown.
```

The app can make these addresses friendlier in the interface with bookmarks, titles, local nicknames, icons, and reading history, but the protocol should remain key-based and domainless.

## Signing Model

Each Fork install creates or imports an author identity:

- private author key: stored locally and protected by the OS keychain
- public author key: shared as the author's network address

Each document can also have its own key:

- private document key: used to publish updates to that page
- public document key: used as the page address

A signed author manifest says:

```text
This is my current site.
These document keys belong to this place.
This document is the home page.
This is the current version number.
This replaces the previous manifest hash.
Signed by the author private key.
```

A signed document record says:

```text
This is the current Markdown for this document.
This is its title and metadata.
This is the current version number.
This replaces the previous document hash.
Signed by the document private key.
Optionally countersigned or listed by the author manifest.
```

Readers verify signatures before trusting content. Peers can be stale, unavailable, or dishonest, but they cannot forge a valid update without the relevant private key.

Core rule:

```text
Stale is acceptable. Forged is not.
```

## P2P Model

The p2p layer is core from the start.

Fork apps should be peers. A peer can:

- announce signed records it has
- request records for an author or document key
- cache records it has visited
- serve cached records to other peers
- try the author's own device first when reachable
- fall back to cached copies from the network when the author is offline

Initial network behavior:

```text
1. User visits fork://author/<key>.
2. Fork asks the network for signed manifests for that key.
3. Fork picks the newest valid manifest it can verify.
4. Fork fetches the referenced Markdown document records and assets.
5. Fork renders the page.
6. Fork caches the verified records locally.
```

If the author's device is online, it may serve the freshest version directly. If not, any peer with a cached valid copy can help.

The UI should make offline status calm and legible:

```text
Showing cached version from 2026-07-04.
Looking for newer signed versions...
```

## Likely Building Blocks

The exact stack should be validated in a prototype, but the bias is:

- App: Swift, SwiftUI, and AppKit where needed
- Markdown: a proven Swift Markdown parser/renderer
- Crypto: Apple's CryptoKit where suitable
- Local storage: plain files plus a small local index database if needed
- P2P: libp2p or another mature peer-to-peer stack
- Assets: content-addressed blobs referenced from signed Markdown records

One open question is whether the p2p core should be written directly in Swift or run as a small local core in a language with stronger libp2p support. The app should still be native; a helper process is acceptable if it keeps the network layer boring and reliable.

## MVP

The first working version should prove the whole shape, not every feature.

MVP capabilities:

- launch native Mac app
- create local author identity
- create a first Fork place
- write Markdown in a built-in editor
- create stable document keys for pages
- publish signed author manifest
- publish signed document records
- run as a p2p peer
- visit another author address
- retrieve signed content from the network
- verify signatures before rendering
- cache verified pages locally
- show offline/cached state clearly
- bookmark author and document addresses
- render Markdown with one or two simple themes

Out of scope for MVP:

- comments
- likes
- analytics
- feeds
- tabs
- arbitrary HTML
- JavaScript
- custom domains
- multi-device authoring
- rich theme marketplace
- search engine crawling
- moderation system beyond local blocking

## App Shape

Fork has two main modes:

- Read: visit addresses, browse bookmarks, move backward and forward, read cached pages.
- Write: edit your own Markdown documents, preview them, publish signed updates.

Navigation should be intentionally restrained:

- one current page
- back and forward
- bookmarks
- reading history
- maybe a reading shelf for saved places

No tabs.

The interface should make addresses feel less important than places:

- show titles and local nicknames first
- keep full key addresses copyable
- let users bookmark weird key addresses with personal labels
- allow trails of linked Fork documents to become the browsing experience

## Data Model Sketch

Author manifest:

```json
{
  "type": "fork.authorManifest",
  "authorPublicKey": "...",
  "version": 1,
  "previous": null,
  "homeDocument": "fork://doc/...",
  "documents": [
    {
      "address": "fork://doc/...",
      "role": "page",
      "title": "Home"
    }
  ],
  "theme": "plain",
  "createdAt": "2026-07-04T00:00:00Z",
  "signature": "..."
}
```

Document record:

```json
{
  "type": "fork.documentRecord",
  "documentPublicKey": "...",
  "version": 1,
  "previous": null,
  "title": "Hello Fork",
  "markdownBlob": "bafy...",
  "assets": [],
  "createdAt": "2026-07-04T00:00:00Z",
  "signature": "..."
}
```

Rendered pages should come from verified records only.

## Open Questions

- Should every document have its own keypair, or should documents use stable content identifiers signed only by the author key?
- Should document keys be recoverable from the author key, or generated independently and listed in the author manifest?
- How much HTML-like Markdown should be allowed, if any?
- What image and asset limits should exist?
- How should private key backup and recovery work?
- How should multi-device publishing work later?
- How do bookmarks, trails, and discovery work without turning into a feed?
- Should peers pin friends' sites by default, explicitly, or never automatically?
- What local blocking or filtering primitives are needed for abuse?
- What is the minimum viable p2p stack on macOS that still feels maintainable?

## First Implementation Milestones

1. Project scaffold
   - Create a native macOS app.
   - Choose initial Markdown renderer.
   - Create basic read/write split.

2. Local identity
   - Generate author keypair.
   - Store private key securely.
   - Display copyable Fork author address.

3. Local documents
   - Create Markdown documents.
   - Assign stable document addresses.
   - Render preview from Markdown.

4. Signed publishing
   - Write signed author manifests.
   - Write signed document records.
   - Verify records before rendering, even locally.

5. Local peer loop
   - Run two local Fork peers.
   - Publish from one.
   - Visit from the other.
   - Verify and cache content.

6. Real p2p transport
   - Add peer discovery.
   - Fetch manifests and records over the network.
   - Serve cached verified records.

7. Offline UX
   - Prefer freshest reachable signed version.
   - Fall back to cached signed versions.
   - Show cache age and verification state calmly.

8. Bookmark-led browsing
   - Save author and document addresses.
   - Add local nicknames.
   - Add reading history without tabs.

## Working Tagline

```text
Fork is a native, tabless Markdown browser/editor for signed personal places on a slow p2p network.
```
