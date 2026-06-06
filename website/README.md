# Agent PMO Website

Marketing site for Agent PMO. Built with [Eleventy (11ty)](https://www.11ty.dev/) v3,
deployed to GitHub Pages.

**Live:** https://nimblesite.github.io/AgentPMOWorkflow/

## Develop

```bash
npm install          # install dependencies
npm run dev          # serve with live reload (http://localhost:8080/)
npm run build        # build static site to _site/
```

From the repo root you can also use `make website-run` / `make website-build`.

## Structure

```
website/
├── .eleventy.js          # 11ty config (input src/, output _site/, HtmlBasePlugin)
├── src/
│   ├── _data/site.js     # site-wide metadata (name, url, githubUrl, socialImage)
│   ├── _includes/base.njk# base layout: head, meta/OG/Twitter tags, JSON-LD, nav, footer
│   ├── index.njk         # home
│   ├── how-it-works.njk
│   ├── features.njk
│   ├── get-started.njk
│   ├── robots.njk        # → /robots.txt
│   ├── sitemap.njk       # → /sitemap.xml
│   └── assets/           # css, favicon, social-preview, images (passthrough-copied)
└── _site/                # build output (gitignored)
```

## Deployment

`.github/workflows/deploy-pages.yml` builds and publishes to GitHub Pages on every push
to `main` that touches `website/**`. The workflow injects two env vars so canonical URLs,
the sitemap, and social-card URLs resolve correctly under the project subpath:

| Env var | Value (set by workflow) |
|---|---|
| `SITE_URL` | `https://<owner>.github.io/<repo>` |
| `ELEVENTY_PATH_PREFIX` | `/<repo>/` |

For a custom domain, add a `CNAME` file (passthrough-copied) and override `SITE_URL` /
drop the path prefix in the workflow.

## Social preview card

`og:image` / `twitter:image` point to `src/assets/social-preview.png` (1200×630). Social
platforms reject SVG, so the PNG is the source of truth for sharing. It is rendered from
`src/assets/social-preview.svg` — regenerate after editing the SVG:

```bash
rsvg-convert -w 1200 -h 630 src/assets/social-preview.svg -o src/assets/social-preview.png
```
