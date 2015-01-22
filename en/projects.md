---
layout: post
title: Projects
index: 2
lang: en
---

Here's a short list of projects on which I spend some of my free time. Most are
made with my favourite tools, those I know the most: C++ and *boost*. As they
are side-projects, they aren't subjects to deadlines and explicit
specifications; which is the reason why there are also a showcase for my two
weaknesses: *over-design* and
[*NIH* syndrome](https://en.wikipedia.org/wiki/NIH_syndrome).

Over-design is the reason why most of those projects are libraries. When facing
a specific problem, I usually find it more interesting to try to solve the
whole class of similar problems and write a small generic library to do it. The
downside of this "perfectionist" approach is of course that it slows down
everything...

My taste for *NIH* is the result of both my will to understand how things work
and my "disdain" for anything not in the standard library of my current
language (*boost* being the exception). For instance, when working on an old
*GUI*-related project, I rewrote my own wrappers around *libpng* and
*libjpeg*...

---

{% include project.html proj="mml" %}

A *Minimalistic Maths Library*.

The *MML* was born as a collection of various maths tools that I needed at some
point in some of my projects. It is now a rather unified library that focuses
on fundamental 2D shapes.

It is a "headers only" library, as it relies on templates / macros to decide
what types to use for value storage and for intermediate computations, and what
relational operations to use on them.

{% include image.html src="projects/mml.png" thumb="projects/mml_thumb.png" title="Generated tiling example" %}

---

{% include project.html proj="mcl" %}

A *Minimalistic Color Library*.

The idea of the *MCL* came from the need to have tools to interpolate
colors and to convert back and forth from *rgb* and *hsl*. It went a bit
further than that and now handles eight different color spaces,
endomorphic color transformations, perceived color distance
computations...


{% include image.html src="projects/mcl.gif" thumb="projects/mcl.png" title="LCHab color space" %}

---

{% include project.html proj="saw" %}

(Yet another) *Sqlite3 API Wrapper*.

Faced with the need to write some code using *sqlite3*'s C API, I've
procrastinated the real task at hand by writing a C++ library wrapping it.

The goal of this small library is NOT to hide sqlite3's API; if it aimed to do
so, it would be far more complicated than it already is. Its goal is simply to
facilitate some common *sqlite3* tasks, such as managing database connections
and statements. All wrapped structures such as `Database` and `Statement`
provide access to the raw data that lies beneath.

---

{% include project.html proj="mwl" %}

A *Minimalistic Widgets Library*.

The *MWL* is my attempt at reinventing the *GUI* wheel. Based on a prior
attempt to create a *GUI* library for *OpenGL* projects, it is now a
renderer-agnostic library. It provides objects, behaviour and entry points, but
it is up to the user of the library to translate external input and to decide
how to render each element.

---

{% include project.html proj="stream" %}

A tower defense game with adaptive enemy behavior.

The game is centered around the notion of enemy "personality": each enemy
adapts its behavior and path according to its goal, its personality, its
mood... Development is currently on hold, but there's already a *proof of
concept* on *Youtube*, please see below.

{% include youtube.html src="//www.youtube.com/embed/nX-7JNG5RME?rel=0" %}

---

{% include project.html proj="zolver" %}

A *Robozzle solver*.

Having spent a lot of time on [*Robozzle*](http://robozzle.com/), a fun
programming game, we decided with a friend to try and write a piece of software
that would solve the levels for us. We knew it was probably a *NP* problem, but
why would that stop us? The project is unfinished and abandoned, but it almost
works (although rather slowly, as expected).
