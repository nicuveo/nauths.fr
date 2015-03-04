---
layout: post
title: "Doxygen et BOOST_PP"
lang: fr
---

{% assign u=site.data.urls %}

La liste des sujets que je voudrais aborder ici est longue comme le
bras. Pour reprendre les publications, un petit article : quelque chose
de simple.

---

## Le contexte

Vous l'avez peut-être constaté, j'aime
[jouer avec l'infâme préprocesseur C](/fr/2014/05/29/cpp-madness.html). J'ai
pris par ailleurs l'habitude de générer automatiquement une
documentation de mes projets en C++ grâce à *Doxygen*, qui offre à mes
yeux pas mal d'avantages.

* À l'inverse d'une documentation d'API écrite séparément, une
  documentation générée à partir du code ne risque pas de souffrir de
  désynchronisation.
* En l'absence de de toute autre forme de documentation, la
  documentation générée offre une indexation du code pas mauvaise, une
  navigation plus aisée, et une lecture des prototypes plus adaptée que
  ce que permet une simple lecture de code dans l'éditeur.
* Annoter le code par de simples commentaires peut donc suffire à
  obtenir quelque chose de suffisant.

Globalement, c'est donc un très bon pis-aller pour le flemmard que je
suis, étant donnée la taille limitée de mes projets. Qui plus est,
*Doxygen* génère des graphes d'inclusion et d'héritage, et *ÇA* c'est la
classe.

{% include image.html src="doxygen/graph.png" width="400px" %}

---

## Le problème

Mais, pour générer sa documentation, *Doxygen* doit parser les
sources. Et, à cause de *BOOST_PP* et de ce genre de macros, mon code
est parfois... obfusqué. En conséquence, la documentation générée est
incomplète, voire erronée. Ce qui donne des résultats
aussi absurdes que les deux exemples ci-dessous.

{% include image.html src="doxygen/dox_1.png" width="400px" %}

{% include image.html src="doxygen/dox_2.png" width="200px" %}

---

## La solution

La solution réside dans les options de
[*filtering*](http://www.stack.nl/~dimitri/doxygen/manual/config.html#cfg_input_filter)
de *Doxygen*. Celles-ci permettent de préprocesser les sources avant que
*Doxygen* ne s'en empare. Et plutôt que de lui laisser la tâche de faire
l'expansion des macros, autant demander à l'outil qui est fait pour ça :
le compilateur. La seule difficulté est de réussir à préserver
commentaires et directives d'inclusion, pour que *Doxygen* puisse faire
son travail correctement ; mais ce n'était rien qui ne puisse être
résolu en quelques appels à `sed`.

Au final, le script nécessaire est étonnamment petit. Le voici dans son
intégralité (vous pouvez le [télécharger ici](/files/filter.sh)).

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

Bref, voilà. Ce n'est pas grand chose. Mais si un jour il vous arrive de
devoir générer une documentation *Doxygen* à partir de code C++ bourré de
macros... vous saurez comment faire. :)
