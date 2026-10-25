---
title: Archive
permalink: /archive/
nav_order: 3
description: Everything published here, newest first.
---

{% if site.posts.size > 0 %}
{%- comment -%}
  Grouped by year, computed from the posts themselves. There is no list to
  maintain and no year to add by hand each January.
{%- endcomment -%}
{%- assign posts_by_year = site.posts | group_by_exp: "post", "post.date | date: '%Y'" -%}
{%- for year in posts_by_year %}
<h2 class="archive-year">{{ year.name }}</h2>
<ul class="post-list">
  {%- for post in year.items %}
  <li>
    <a href="{{ post.url | relative_url }}">{{ post.title | escape }}</a>
    <time datetime="{{ post.date | date_to_xmlschema }}">{{ post.date | date: "%-d %b" }}</time>
  </li>
  {%- endfor %}
</ul>
{%- endfor %}
{% else %}
Nothing published yet.
{% endif %}
