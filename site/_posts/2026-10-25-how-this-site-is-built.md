---
title: How this site is built
date: 2026-10-25
description: A static site with no theme, no plugins and no JavaScript — and why each of those is a decision rather than a shortcut.
tags: [meta, jekyll]
---

This site is Jekyll, built by GitHub Actions, and it deliberately uses less
of Jekyll than most Jekyll sites do. Everything below is a choice made for
one reason: **the site should still build in ten years.**

## No theme

There is no `theme:` and no `remote_theme:` in the config. The layouts are
four short HTML files in `_layouts/`.

A theme is someone else's repository. It can stop being maintained, change
its class names, or drop support for the Jekyll version you are on — and
when it does, the failure arrives on a day you were trying to publish
something else. Four files I can read in a minute are worth more than a
theme I would have to re-learn.

## No plugins

The Atom feed, the sitemap and `robots.txt` are ordinary Liquid templates
sitting in the repository. They would normally be `jekyll-feed` and
`jekyll-sitemap`.

Those two gems are about as stable as software gets, so this is a close
call. What tipped it: with no plugins at all, `jekyll build` works on
Jekyll 3 or 4, with or without a `Gemfile`, and on GitHub's own legacy
builder — there is no plugin whitelist to satisfy and nothing to replace
when a gem is abandoned. The cost is that I maintain two small templates
instead of trusting two small gems, and that the feed had to be checked
against a validator rather than assumed correct.

## No JavaScript

Not one line. Nothing to update, nothing to break, nothing to slow the
first paint, and no third-party script to start tracking anybody. Dark mode
is `prefers-color-scheme` in CSS; the navigation is links.

## Plain CSS, and a system font

One stylesheet, no Sass. Everything Sass existed for — variables, nesting,
colour maths — is now in CSS itself and shipping in every browser, so the
compiler was removing a step between writing a line and seeing it and
adding nothing.

The font stack is the reader's own system font. A web font is a request
that can fail, a file that can go missing, and on a third-party CDN a
privacy problem as well. System fonts render instantly and cannot break.

## URLs that will not have to change

Post URLs are `/posts/the-title/`. No date in the path, so correcting a
post's date never breaks its link. Namespaced, so a post can never collide
with a page. Ending in a slash, so any static host serves it by finding
`index.html` in that directory.

URLs are the one thing a site cannot change later without breaking every
link anyone ever saved, so that pattern is the most consequential line in
the config.

## The content is not really Jekyll's

Posts are Markdown with four front-matter keys: `title`, `date`,
`description` and `tags`. There is no Jekyll-specific markup inside the
prose.

That is the actual insurance policy. If Jekyll is ever the wrong answer,
`_posts/*.md` moves to Hugo, Eleventy or Astro essentially untouched. The
generator is replaceable; the writing is not.

## Adding a post

Create a file in `site/_posts/` named `YYYY-MM-DD-some-title.md`:

```markdown
---
title: Some title
date: 2026-11-02
description: One sentence that shows up in the feed and on the front page.
tags: [notes]
---

The post, in Markdown.
```

Commit it. The front page, the archive, the feed and the sitemap all pick
it up on their own — there is no index to update by hand.
