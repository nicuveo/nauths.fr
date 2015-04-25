---
layout: post
title: "Doxygen and BOOST_PP"
lang: en
---

{% assign u=site.data.urls %}

There are many topics I'd like to broach here... In order to start the
writing process anew, a first, small, easy post.


---

## Context

You might have noticed: I really enjoy
[messing with the infamous C preprocessor](/en/2014/05/29/cpp-madness.html). Besides,
I also took the habit of using *Doxygen* to automatically generate some
documentation for my C++ project, as it offers a few interesting
features in my opinion.

* Unlike a separate hand-written API documentation, a documentation
  generated from the source code itself does not suffer the risk of
  being out of sync.
* When there's no other documentation available, a *Doxygen* generated
  documentation provides a good-enough source indexation and layout,
  which makes browsing for info a bit easier than just waltzing through
  source files.
* Having a usable documentation can be just a matter of adding simple
  comments to the source code.

Overall, it is a very good solution for the lazy sloth I am, considering
the limited scale of my projects. And furthermore, it can generate
inclusion or inheritance graphs, and *THAT* is cool.

{% include image.html src="doxygen/graph.png" width="400px" title="a nice inclusion grpah" %}

---

## Issue

But in order to generate the documentation, *Doxygen* has to parse the
source code. And due to *BOOST_PP* and to some similar macros usage, my
code is sometimes somewhat... obfuscated. Usually, this means that the
generated documentation is incomplete, or even sometimes plainly
wrong. Here are two examples of the absurd or unreadable output it can
yield...

{% include image.html src="doxygen/dox_1.png" width="400px" title="wat?" %}

{% include image.html src="doxygen/dox_2.png" width="200px" title="wat?" %}

---

## Solution

The solution came from Doxygen's
[filtering options](http://www.stack.nl/~dimitri/doxygen/manual/config.html#cfg_input_filter). They
allow one to specify how to preprocess a file before it is parsed. And
with this, rather than letting *Doxygen* try to expand macros, we can
use the tool that's made for it: the compiler. The only tricky thing was
to preserve comments and include directives, in order for *Doxygen* to
do its job properly; but it was nothing a few `sed` calls couldn't
solve.

Ultimately, the resulting script is surprisingly small. Here it is in
its entirety (you can also download it [from here](/files/filter.sh)).

{% highlight bash %}
#! /usr/bin/env bash

FILE="$1"
CCOPTS="-C -x c++ -std=c++11 -I include -I src"
G1="__________B $(date +%s) B__________"
G2="__________E $(date +%s) E__________"

function surround()
{
    egrep    "^# *include" "$FILE" | grep -v '\.hxx.$'
    echo "$G1"
    egrep -v "^# *include" "$FILE"
    echo "$G2"
}

egrep "^# *include" "$FILE" | grep -v '\.hxx.$'
surround                       \
    | cpp $CCOPTS -            \
    | sed -n -e "/$G1/,/$G2/p" \
    | sed "/$G1\|$G2\|^#/d"
{% endhighlight %}

So, well, there it is. It isn't much. But if, one day, you have to use
*Doxygen* on some C++ source code which is full of macros... well, then,
that day, you'll be ready. :)
