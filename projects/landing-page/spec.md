# static landing page called HomeBase

HomeBase is a static landing page.
It should be a home page for users that allow them to quickly easily get to sites that they chose.
There should be no server involved.

## Interface

- static web page, no server
- repsonsive, works equally well on desktop, tablet, and mobile
- each site should be represented by a tile
- the user should be able to set a friendly name for each tile
- each site tile should try to use the favicon for the site
- there should be a set of default tiles
- the defaults should be easy to change so that an admin can easily deploy this
- user should be able to add, remove, and modify tiles
- user changes should be stored locally

## Tech
- HTML5
- JavaScript
- CSS
- no frameworks

## Environment
- compliant browsers

## Deployment
- published with the rest of the repo's projects via GitHub Pages, by the
  `.github/workflows/deploy-site.yaml` workflow (Pages source: GitHub Actions)
- served at `/black-lion/landing-page/`; the site root `/black-lion/` is a
  generated index linking to each project
- the index entry uses the page's `<title>` and `<meta name="description">`
- only non-Markdown files are published; spec/log files are not

## Workflow
- After each logical change, update PROMPTS.md with the prompt and any 
  notable decisions, then git add and commit with a descriptive message
- Keep commits atomic — one logical change per commit
- As decision are made, update the spec.md file