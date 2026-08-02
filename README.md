# gh-pages

Static project site for [kubernetes-platform](https://github.com/sameeralam3127/kubernetes-platform),
served at **https://sameeralam3127.github.io/kubernetes-platform/**.

This branch is **orphaned** — it shares no history with `main` and contains no platform
code. Only the site lives here.

```
index.html        single page, semantic sections
assets/style.css  design tokens, light/dark, responsive
assets/app.js     renders architecture, roadmap, stack and tree from data
.nojekyll         serve files as-is, skip Jekyll processing
```

## Design constraints

- **No external requests.** No CDN scripts, webfonts, analytics or remote images.
  The page renders identically offline and cannot break because a third party did.
- **Content is data.** The roadmap, stack and architecture are arrays at the top of
  `app.js`. Updating a phase means editing one object, not hunting through markup.
- **Works without JavaScript** for prose sections; the roadmap degrades to a link to
  `ROADMAP.md`.
- **Respects `prefers-reduced-motion`** — the terminal animation and reveals are
  disabled rather than merely shortened.

## Local preview

```bash
git switch gh-pages
python3 -m http.server 8080
# → http://localhost:8080
```

## Keeping it in sync

The site duplicates content from `main` (README, ROADMAP, ADRs). When a phase
completes, update `PHASES` and `STACK` in `assets/app.js` and the status pill in
`index.html`.
