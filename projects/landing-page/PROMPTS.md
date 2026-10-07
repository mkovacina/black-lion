# HomeBase — Prompts & Decisions Log

---

## 2026-03-28 — Initial implementation

**Prompt:**
> Read the spec.md file and implement.

**What was built:**
- `index.html` — page structure: sticky header, tile grid, add/edit modal
- `styles.css` — CSS Grid layout, responsive breakpoints, hover/touch action visibility
- `defaults.js` — admin-editable default tile list (separate file for easy deployment config)
- `app.js` — tile rendering, add/edit/delete, localStorage persistence

**Notable decisions:**

- **No frameworks** — plain HTML5/CSS/JS per spec. No build step required; just open `index.html`.
- **Favicons** — using `https://www.google.com/s2/favicons?domain=...&sz=64`. Falls back to a generated letter-avatar (colored circle + first letter of tile name) on error.
- **Admin config** — `defaults.js` is the single file an admin needs to edit to change default tiles. It is loaded before `app.js` and exposes `DEFAULT_TILES`.
- **localStorage key** — `homebase_tiles`. Once a user has any saved state, `DEFAULT_TILES` is ignored (user data takes precedence).
- **URL normalization** — `https://` is prepended automatically if the user omits a protocol in the add/edit form.
- **Touch support** — action buttons (Edit/Delete) are hidden until hover on pointer devices (`@media (hover: hover)`), and always visible at reduced opacity on touch devices (`@media (hover: none)`).
- **Responsive grid** — `auto-fill` with `minmax(130px, 1fr)` scales cleanly from wide desktop down to small phones; tightens to `minmax(100px, 1fr)` at ≤600 px and locks to 3 columns at ≤360 px.

---

## 2026-03-28 — Consolidate into single file

**Prompt:**
> I'd like it to all be in one file for easy deployment.

**What changed:**
- Inlined `styles.css` into a `<style>` block in `index.html`
- Inlined `defaults.js` and `app.js` into a single `<script>` block in `index.html`
- Removed the now-redundant separate files

**Notable decisions:**
- `DEFAULT_TILES` admin config kept at the very top of the `<script>` block, clearly delimited with comments, so it remains easy to find and edit in the single file.

---

## 2026-10-06 — Publish via GitHub Pages

**Prompt:**
> Can you setup so that the page can get published as a github page?

**What changed:**
- Added `.github/workflows/deploy-landing-page.yaml`, which deploys the page to GitHub Pages with the official Pages actions
- Added a Deployment section to `spec.md`

**Notable decisions:**
- **Actions-based deploy rather than branch/folder source**: the classic "deploy from branch" option only serves the repo root or `/docs`, and the page lives in `projects/landing-page/`. A workflow avoids moving files or keeping a `gh-pages` branch.
- **Only `index.html` is published**: the workflow copies it into a staging `_site/` folder, so `spec.md` and `PROMPTS.md` aren't served. It also adds `.nojekyll` to skip Jekyll processing.
- **Path-filtered trigger**: it deploys only when the landing page (or the workflow itself) changes on `main`. It can also be run manually.
- **One-time repo setting required**: Settings → Pages → Source must be set to "GitHub Actions".

---

## 2026-10-07 — Publish alongside other projects with a site index

**Prompt:**
> Option 2, with a simple index linking to each project.
> (The repo already serves `main` / root through "Deploy from a branch", under the custom domain `kovacinacomputing.com/black-lion/`.)

**What changed:**
- Replaced the landing-page-only workflow with `.github/workflows/deploy-site.yaml`, which publishes the whole repo site
- Added `scripts/build-site.sh`, which builds the site into `_site/`
- Added a `<meta name="description">` to `index.html` so the site index can show a one-line blurb

**Notable decisions:**
- **One Pages site per repo**: a repo can only have one Pages source, so the workflow publishes every project rather than just HomeBase. The Pages source has to be switched from "Deploy from a branch" to "GitHub Actions".
- **Convention-based publishing**: any `projects/<name>/` folder with an `index.html` is published at `/<name>/`, with `*.md` files left out. New projects need no workflow changes.
- **Generated root index**: the index lists each project using its `<title>` and description meta, so it can't drift out of sync with the projects.
- **Script, not inline YAML**: the build logic lives in a script so it can be run and previewed locally.

---

## 2026-10-07 — Fix 404 on the published page

**Prompt:**
> I merged it but I'm getting a 404 when trying to access the page.

**Root cause:**
- The workflow calls `scripts/build-site.sh _site` with a relative output path. The copy step runs from inside each project folder, so `cp` was pointed at a path that didn't exist and failed. `find -exec … \;` ignores a failing command, so the build still succeeded and deployed a site whose `landing-page/` folder was empty.

**What changed:**
- `build-site.sh` turns the output path into an absolute path before copying
- The copy uses `find -exec … +`, which passes a `cp` failure through, so under `set -e` a broken copy now fails the build instead of deploying an incomplete site
