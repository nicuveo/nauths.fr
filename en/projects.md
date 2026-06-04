---
layout: default
title: Projects
index: 4
lang: en
---

{% assign u=site.data.urls %}

## Piètre

`Piètre` is a compiler from a subset of [Rust](https://rust-lang.org/) to the
esoteric language [Piet](https://www.dangermouse.net/esoteric/piet.html),
written in Haskell. It is meant as an educational project, and all of the code
is written live on [Twitch]({{u.twitch}}).

- source code on [GitHub](https://pietre.dev);
- live streams on [Twitch]({{u.twitch}});
- stream archive on my [secondary YouTube channel](https://youtube.com/@nicuveo-archive);
- project introduction video on my [main YouTube channel](https://youtu.be/uCQ2hjx_7-Y).

<hr class="softline" />

## GraphWiz

`GraphWiz` is a Haskell library that provides a monadic DSL to generate DOT graphs
in the [Graphviz format](https://graphviz.org/). It is actively maintained.

- source code on [Codeberg](https://codeberg.org/nicuveo/graphwiz);
- mirror on [GitHub](https://github.com/nicuveo/graphwiz);
- available on [Hackage](https://hackage.haskell.org/package/graphwiz) and
  [Flora](https://flora.pm/packages/@hackage/graphwiz).

I have also developed a [Rust version](https://codeberg.org/nicuveo/graphwiz-rs)
of that library, and i have published it as a
[crate](https://crates.io/crates/graphwiz), but i don't actively maintain it to
the same extent.

<hr class="softline" />

## lens-indexed-plated

`lens-indexed-plated` is a small Haskell companion library for `lens` that adds
an alternative to `Plated` named `IndexedPlated`, which associates an index of
the user's choosing to each element of the self-recursive structure, like a JSON
path for a JSON value for instance. It is considered stable.

- source code on [Codeberg](https://codeberg.org/nicuveo/lens-indexed-plated);
- mirror on [GitHub](https://github.com/nicuveo/lens-indexed-plated);
- available on [Hackage](https://hackage.haskell.org/package/lens-indexed-plated) and
  [Flora](https://flora.pm/packages/@hackage/lens-indexed-plated).
