# Agent PMO Website Visual System

This document defines the first PNG asset set for the Agent PMO website, README surfaces, and future prose pages. It extends the existing dark-first website tokens in `website/src/assets/css/style.css` without replacing the CSS system.

## Goals

- Break long technical pages with purposeful images.
- Illustrate the operating words already used by the site: standards, gates, dashboard, traceability, coordination, and direction.
- Keep images reusable across website sections, blog headers, README docs, and social snippets.
- Prefer images that explain a concept at a glance without embedding tiny copy inside the bitmap.

## Visual Direction

- Style: polished editorial technical illustration, not stock photography.
- Subject matter: dashboards, code windows, check gates, spec nodes, agent coordination lines, and repo systems.
- Palette: deep green-black base, Nimblesite green `#19d078`, orchestration purple `#a78bfa`, muted terminal gray, and small amber warning accents.
- Texture: subtle glass, matte panels, clean terminal surfaces, and faint grid lines.
- Composition: wide 16:9 crops for section breaks, with stable negative space and clear focal hierarchy.
- Text in images: avoid text unless it is large, generic, and non-critical. Use HTML captions and alt text for meaning.

## Asset Roles

| Asset | Use | Concept |
|---|---|---|
| `agent-pmo-workspace.png` | Home hero support, README overview | A chaotic repo becoming an ordered Agent PMO workspace |
| `quality-gates.png` | Home quality section, future blog/readme use | Work passing through enforced lint, test, coverage, and CI gates |
| `dashboard-control-room.png` | Features dashboard section, how-it-works step 2 | The dashboard as control room visibility, not manual context switching |
| `traceability-map.png` | Home and features traceability sections | Spec IDs connecting requirements, code, tests, plans, and PRs |
| `parallel-coordination.png` | How-it-works and features TMC sections | Multiple agents sharing one working tree through locks and messages |

## Production Rules

- Save source site images under `website/src/assets/images/`.
- Use PNG format for this first set because the request targets website, blog, and README reuse.
- Use descriptive lowercase filenames with hyphens.
- Include `width` and `height` attributes when embedding images.
- Write alt text as the explanation. Do not rely on in-image text for accessibility or SEO.
- Use `loading="lazy"` for non-hero images.
- Keep CSS changes narrow. Reuse `section`, `feature-detail`, `prose`, and existing layout classes.
- Keep images outside nested cards. They should act as full section breaks or as the visual side of existing detail rows.

## Prompt Pattern

Use case: stylized-concept or productivity-visual  
Asset type: website section illustration and README image  
Style/medium: polished technical editorial illustration, semi-realistic 3D UI panels, subtle depth  
Color palette: `#060c0a`, `#0d1a14`, `#19d078`, `#a78bfa`, muted gray, restrained amber  
Constraints: PNG, no logos, no watermark, no tiny unreadable text, no brand names, no cartoon characters

## Placement Plan

- Home page:
  - Add `agent-pmo-workspace.png` after the problem narrative.
  - Add `quality-gates.png` in the quality gates section.
  - Add `traceability-map.png` in the traceability section.
- Features page:
  - Use `dashboard-control-room.png` in the dashboard detail.
  - Use `parallel-coordination.png` in the TMC detail.
  - Use `traceability-map.png` in the traceability detail.
- How It Works page:
  - Use `parallel-coordination.png` after dispatch and TMC explanation.
  - Use `dashboard-control-room.png` after prioritization.
- Get Started page:
  - Use `agent-pmo-workspace.png` after prerequisites to show the target workspace state.
- README surfaces:
  - Add a concise image to the root `README.md`.
  - Document available assets in `website/README.md`.

## Maintenance

When adding future blog posts or docs, choose one of the five concepts above before creating a new image. Create a new image only when the page introduces a new core word or mental model that the existing set cannot represent.
