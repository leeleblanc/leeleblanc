# site/

The personal site, built with Jekyll and published to GitHub Pages by
`.github/workflows/pages.yml`.

## Run it locally

```sh
cd site
bundle install      # once
bundle exec jekyll serve
```

Then open <http://localhost:4000/>. It rebuilds as you save.

## Add a post

Create `_posts/YYYY-MM-DD-some-title.md`:

```markdown
---
title: Some title
date: 2026-11-02
description: One sentence, used on the front page and in the feed.
tags: [notes]
---

The post, in Markdown.
```

Commit it. The front page, the archive, the feed and the sitemap update
themselves — there is no index to edit.

## Add a page

Create `whatever.md` with `permalink: /whatever/`. To put it in the top
navigation, give it `nav_order: 4`; leave that out and it exists without
appearing in the nav. **The nav is built from the pages**, so there is no
list anywhere to keep in step.

## Where it is served

`baseurl` in `_config.yml` is deliberately empty and should stay that way:
the workflow passes the correct value at build time, so the same commit is
right in all three cases.

| Hosting | URL | What to do |
|---|---|---|
| This repo as a project site | `leeleblanc.github.io/leeleblanc/` | nothing |
| A repo named `leeleblanc.github.io` | `leeleblanc.github.io` | nothing |
| A custom domain | `example.com` | add `site/CNAME` holding the domain, and set `url:` in `_config.yml` |

**One setting to change by hand, once:** repository → Settings → Pages →
Build and deployment → Source → **GitHub Actions**. Until that is set, the
workflow builds and the deploy step fails, because Pages is still expecting
to build a branch itself.

> ⚠️ There is a four-year-old `_config.yml` at the **repository root**
> holding `theme: jekyll-theme-minimal`. It is from 2022 and nothing here
> reads it. It is harmless once Pages is set to GitHub Actions, but while
> Pages is still set to "Deploy from a branch" it is what GitHub tries to
> build. Deleting it is one commit, and worth doing so there is only one
> Jekyll config in the repository.

## What this deliberately does not use

No theme, no plugins, no JavaScript, no Sass, no CDN, no web font. Each of
those is a decision rather than an omission, and the reasons are written in
`_config.yml` and in the first post.

The practical consequence: `_posts/*.md` is portable Markdown with four
front-matter keys, so if Jekyll is ever the wrong answer the writing moves
to another generator essentially untouched.
