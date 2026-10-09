---
name: create-astro-site
description: 'Use when creating a new Astro website from the shared astro-site template or customizing its domain, assets, content, and GitHub Pages deployment.'
---

# Create an Astro site

Create a new project website from the reusable
[astro-site template](https://github.com/DanMarshall909/astro-site). This skill
owns finding and starting the template; the cloned repository's
`.agents/skills/customize-astro-site/SKILL.md` owns its actual content, design,
and deployment. Do not add the starter as a Git submodule: a new site needs its
own files, history, domain, and publishing settings.

## Start the new repository

Confirm the desired repository name, site purpose, source project, and domain
from the request and available project context. A custom domain is a per-site
value; never carry another site's `CNAME` into a new repository. If the domain
is unknown, build the site and leave publishing unconfigured until the owner
supplies it.

Use GitHub's **Use this template** flow to create an independent repository,
then clone it. For a local-only draft, clone or copy the starter into a fresh
directory and give it its own Git remote before publishing. If the template is
unavailable, report the missing repository and ask for its new location; do not
silently substitute a different starter or a submodule.

## Customize and verify

Read the new repository's `AGENTS.md` and local customization skill. Inspect
the source project's current docs and existing site, if any, for terminology,
examples, navigation, metadata, visual assets, and content generation. Reuse
the template's `src/layouts/`, `src/components/`, `src/assets/`, and
`public/assets/` structure; remove generic example content. Keep common
resources organized in the assets folders rather than scattering files across
pages. Adapt the page templates to the site's kind: project landing page,
technical documentation, or blog.

Install the starter's dependencies and run `npm test` for local drafts. Once the
owner supplies the domain, run the starter's setup command for the chosen
identity and domain. Verify `site.config.json`, `public/CNAME`, Astro's `site`,
and the built `dist/CNAME` agree, then run `npm run check:configured`. Without a
domain, retain the unconfigured draft and report that configuration check and
publication as pending. Inspect the pages at a mobile width and check keyboard
navigation, links, and metadata. Add tests for project-specific claims,
generated examples, or article assets when relevant.

## Publish

Follow the repository's publication authority. Set GitHub Pages source to
GitHub Actions, configure its custom-domain setting and DNS, then verify the
live HTTPS site. A `CNAME` file alone is insufficient with a custom Actions
workflow: GitHub ignores that file for domain configuration. Record the final
repository, domain, Pages status, and any pending DNS work in the handoff.
