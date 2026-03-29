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
