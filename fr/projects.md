---
layout: default
title: Projects
index: 4
lang: fr
---

{% assign u=site.data.urls %}

## Piètre

`Piètre` est un compilateur qui traduit une version simplifiée de
[Rust](https://rust-lang.org/) en un langage ésotérique:
[Piet](https://www.dangermouse.net/esoteric/piet.html). Il est écrit en Haskell,
et a vocation à être un project éducatif : tout le code est écrit en _live_ sur
[Twitch]({{u.twitch}}).

- sources du projet sur [GitHub](https://pietre.dev);
- live stream sur [Twitch]({{u.twitch}});
- archive vidéo sur ma [chaîne YouTube secondaire](https://youtube.com/@nicuveo-archive);
- une introduction au projet sur [ma chaîne YouTube principale](https://youtu.be/uCQ2hjx_7-Y).

<hr class="softline" />

## GraphWiz

`GraphWiz` est une bibliothèque Haskell qui fournit un "DSL", un langage dédié,
pour aider à la création de graphes DOT au [format
Graphviz](https://graphviz.org/). Ce project est activement maintenu.

- sources sur [Codeberg](https://codeberg.org/nicuveo/graphwiz);
- copie secondaire sur [GitHub](https://github.com/nicuveo/graphwiz);
- disponible sur [Hackage](https://hackage.haskell.org/package/graphwiz) et
  [Flora](https://flora.pm/packages/@hackage/graphwiz).

J'ai également développé une [version en
Rust](https://codeberg.org/nicuveo/graphwiz-rs) de cette bibliothèque, et je
l'ai publiée sur [crates:io](https://crates.io/crates/graphwiz), mais je ne
maintiens pas activement cette version.

<hr class="softline" />

## lens-indexed-plated

`lens-indexed-plated` est une petite bibliothèqye en Haskell qui accompagne
`lens` pour y ajouter une alternative à `Plated` nommée `IndexedPlated`, qui
ajoute un index choisi par l'utilisateur à chaque élément d'une structure
auto-récursive, comme par exemple le chemin parcouru dans un objet JSON. Cette
bibliothèqe est dans un état stable.

- sources sur [Codeberg](https://codeberg.org/nicuveo/lens-indexed-plated);
- copie secondaire sur [GitHub](https://github.com/nicuveo/lens-indexed-plated);
- disponible sur [Hackage](https://hackage.haskell.org/package/lens-indexed-plated) et
  [Flora](https://flora.pm/packages/@hackage/lens-indexed-plated).
