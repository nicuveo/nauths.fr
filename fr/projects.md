---
layout: post
title: Projets
index: 2
lang: fr
---

Ici sont répertoriés quelques uns des différents projets auxquels je consacre
du temps. Sans mention explicite du contraire, il s'agit de projets utilisant
mes outils de prédilection : C++ et *boost*. Comme il s'agit de projets
développés sur mon temps libre, ils ne sont pas soumis à des deadlines ou à des
impératifs extérieurs ; en conséquence de quoi ils sont bien souvent le reflet
de mes deux travers majeurs : une tendance à *l'over-design* et un certain goût
pour le [syndrome du *NIH*](https://en.wikipedia.org/wiki/NIH_syndrome).

L'over-design est d'ailleurs la raison pour laquelle ces projets sont pour la
plupart des bibliothèques : confronté à un problème précis, je trouve
généralement plus intéressant de réfléchir à comment résoudre toute la classe
de problèmes similaires et d'écrire une solution générique. C'est bien sûr une
forme de perfectionnisme qui a tendance à allonger considérablement le temps de
développement de certains projets...

Mon goût pour le *NIH* relève quant à lui de ma volonté de comprendre comment
fonctionnent les choses ainsi que d'une certaine répugnance à dépendre de
bibliothèques qui ne sont pas dans le standard du langage que j'utilise
(*boost* étant la grande exception à cette règle). Pour un de mes projets,
j'avais ainsi recodé mes propres wrappers autour de la *libpng* et de la
*libjpeg*...

---

{% include project.html proj="mml" %}

Une bibliothèque mathématique minimaliste (*Minimalistic Maths Library*).

La *MML* a commencé son existence comme la simple agrégation des diverses
fonctions mathématiques dont j'avais eu un jour besoin. C'est devenu désormais
une bibliothèque cohérente, qui se concentre sur la notion de formes
géométriques 2D.

C'est une bibliothèque uniquement composée de headers, car elle utilise
templates et macros pour atteindre ses objectifs de généricité, notamment pour
décider quels types de données manipuler.

{% include image.html src="projects/mml.png" thumb="projects/mml_thumb.png" title="Exemple de pavage généré" %}

---

{% include project.html proj="mcl" %}

Une bibliothèque de couleur minimaliste (*Minimalistic Color Library*).

À l'origine de la *MCL*, il y a l'envie et le besoin d'avoir un outil
pour faire de l'interpolation de couleur et pour convertir de *rgb* à
*hsl* et vice-versa. La bibliothèque va un peu plus loin et gère huit
espaces de couleur distincts, des transformations de couleur
endomorphiques, des fonctions de calcul de distance perceptible entre
deux couleurs...


{% include image.html src="projects/mcl.gif" thumb="projects/mcl.png" title="LCHab color space" %}

---

{% include project.html proj="saw" %}

Une surcouche au dessus de l'API *sqlite3* (*Sqlite3 API Wrapper*).

Ayant eu besoin d'écrire du code manipulant l'API C de sqlite3, j'ai préféré
procrastiner le code que je devais écrire et créer à la place une surcouche en
C++.

Le but de cette petite bibliothèque n'est pas d'intégralement remplacer l'API C
; ce serait bien trop fastidieux, compliqué et, honnêtement, inutile. Non, son
but est simplement d'utiliser des fonctionnalités du C++ pour simplifier
certaines tâches, comme gérer la durée de vie d'une connexion à une base de
donnée ou la génération d'une requête.

---

{% include project.html proj="mwl" %}

Une bibliothèque minimaliste de *widgets* (*Minimalistic Widgets Library*).

La *MWL* est ma roue réinventée en matière d'*IHM*. Inspirée d'un précédent
projet visant à créer une bibliothèque de widgets pour mes projets *OpenGL*, la
*MWL* est maintenant une bibliothèque "agnostique". Elle fournit des widgets,
implémente leur comportement, définit des points d'entrée... mais c'est à
l'utilisateur de transmettre les inputs extérieurs ou de gérer l'affichage des
widgets.

---

{% include project.html proj="stream" %}

Un jeu de "tower defense" dans lequel les ennemis ont un comportement
adaptatif.

Tout le jeu est construit autour des "personnalités" des ennemis : chaque
ennemi adapte son comportement et son chemin en fonction de son but, sa
personnalité, son humeur... Le développement est pour l'instant en pause, mais
une vidéo démontrant le concept est déjà sur *Youtube*. (c.f. ci-dessous)

{% include youtube.html src="//www.youtube.com/embed/nX-7JNG5RME?rel=0" %}

---

{% include project.html proj="zolver" %}

Un résolveur pour *Robozzle*.

Ayant beaucoup joué à [*Robozzle*](http://robozzle.com/), un jeu de
programmation assez génial, un ami et moi avons décider d'écrire un programme
qui pourrait résoudre les niveaux pour nous. Nous avions bien conscience de la
difficulté du problème (probablement *NP*), mais ce n'était pas suffisant pour
nous empêcher d'essayer. Le projet n'est pas vraiment fini mais vraiment
abandonné, bien qu'il soit à peu près fonctionnel (et très lent, comme on
pouvait s'y attendre).
