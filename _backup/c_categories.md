---
layout: page
title: Categories
permalink: /categories/
---

***

<ul class="tags-box">
   {% if site.posts != empty %}
      {% for cat in site.categories %}
         {% if cat[0] == 'mysql' %}
         <a href="#{{ cat[0] }}" title="{{ cat[0] }}" rel="{{ cat[1].size }}">MySQL<span class="size"> {{ cat[1].size }}</span></a>
         {% elsif cat[0] == 'nosql' %}
         <a href="#{{ cat[0] }}" title="{{ cat[0] }}" rel="{{ cat[1].size }}">NoSQL<span class="size"> {{ cat[1].size }}</span></a>
         {% else %}
         <a href="#{{ cat[0] }}" title="{{ cat[0] }}" rel="{{ cat[1].size }}">{{ cat[0] | join: "/" | capitalize }}<span class="size"> {{ cat[1].size }}</span></a>
         {% endif %}
      {% endfor %}
</ul>

<ul class="tags-box">
   {% for cat in site.categories %}
      {% if cat[0] == 'mysql' %}
         <li id="{{ cat[0] }}">MySQL</li>
      {% elsif cat[0] == 'nosql' %}
         <li id="{{ cat[0] }}">NoSQL</li>
      {% else %}
         <li id="{{ cat[0] }}">{{ cat[0] | capitalize }}</li>
      {% endif %}
      {% for post in cat[1] %}
         <time datetime="{{ post.date | date:"%Y-%m-%d" }}">{{ post.date | date:"%Y-%m-%d" }}</time> &raquo;
         <a href="{{ site.baseurl }}{{ post.url }}" title="{{ post.title }}">{{ post.title }}</a><br />
      {% endfor %}
   {% endfor %}
   {% else %}
      <span>No posts</span>
   {% endif %}
</ul>
