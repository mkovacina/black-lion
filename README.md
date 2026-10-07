# Sandbox

Small projects live under `projects/<name>/`.

## Publishing

`main` is published to GitHub Pages by `.github/workflows/deploy-site.yaml`:

- every `projects/<name>/` folder with an `index.html` is served at `/<name>/` (Markdown files are left out)
- the site root is a generated index linking to each project, using its `<title>` and `<meta name="description">`

Preview locally with `scripts/build-site.sh` (writes to `_site/`).
