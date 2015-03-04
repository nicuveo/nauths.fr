---
layout: post
title: "Un design haut en couleur"
lang: fr
---

{% assign u=site.data.urls %}

Il y a quelques semaines, j'ai publié la version *1.0.0-alpha* de ma
[*MCL*](/fr/{{u.projs}}#mcl) et j'ai mis à jour la page
[*Projets*](/fr/{{u.projs}}) de ce site en conséquence, ignorant
superbement au passage ma bonne résolution&nbsp;: terminer les projets
existants plutôt que d'en commencer de nouveaux. Pour être honnête, ce
petit projet n'est pas de la plus haute importance, et j'en resterai
probablement son seul utilisateur, mais pour citer ce que j'avais dit au
moment de la [publication de *SAW*](/fr/2014/03/30/saw.html)&nbsp;:

> Ce n'est pas grand chose, d'abord et surtout parce que personne ne
> l'utilise à part moi, ce qui fait que je n'ai pas de problèmes à
> résoudre, pas de bugs bizarres que je n'arrive pas à reproduire chez
> moi... Mais pour autant, la publier n'était pas vide de sens.

Et donc, parlons de couleurs, de design, de C++ et de *build
systems*&nbsp;! Cet article se focalise sur certains aspects techniques
de la *MCL*, sans ordre particulier. Un probable prochain article
s'occupera de présenter quelques anecdotes amusantes et illustrées au
sujet de l'interpolation de couleurs.

---

## Il était une fois...

...un
[passionnant article](http://blog.noctua-software.com/procedural-colors-for-game.html)
(en anglais) sur *Hacker News*. Son sujet&nbsp;: la génération procédurale de
couleurs, et l'interpolation de couleurs dans l'espace de couleur *CIE
LCHab*. Il se trouve que j'avais déjà implémenté, longtemps avant, une
très rudimentaire classe de gestion de couleur, gérant *RGB* et *HSV*,
que j'utilisais pour faire le même genre d'interpolation. Cette vieille
classe était très limitée, principalement par le fait qu'elle stockait
en permanence tous les champs des deux espaces de couleur (*R*, *G*,
*B*, *H*, *S*, *V*). En conséquence&nbsp;:

* cette classe `Color` était relativement lourde,
* elle n'était pas facilement extensible à de nouveaux espaces de couleur,
* elle n'était pas efficace (le moindre changement forçait à recalculer
  tous les champs impactés).

J'avais en conséquence, dans mon code, plusieurs classes de couleur
différentes en parallèle&nbsp;: celle susmentionnée pour l'interpolation, que
je traduisais en une autre plus légère adaptée à du code *OpenGL*... Peu
pratique. Inspiré par cet article, je me suis lancé à corps perdu dans
l'implémentation d'une nouvelle classe de couleur, commençant ce qui est
devenu la *MCL*.

---

## Objectifs

Avant même de me lancer dans le projet, j'avais déjà en tête plusieurs
buts que je voulais clairement atteindre. Même si certaines des
features amusantes sont apparues au fur et à mesure du développement,
celles qui suivent étaient des objectifs dès le lancement du projet.

#### Une classe *RGB* minimaliste

Premier objectif&nbsp;: avoir une struct *RGB* minimaliste, que je puisse
caster en `double*`, en `float*`, ou en `unsigned char*` selon le type
de représentation choisi. Avoir une telle classe me permettrait de
passer directement des tableaux d'instances *RGB* à *OpenGL*, par
exemple.

#### Gérer l'espace de couleur *LCHab*

En plus de gérer les espaces de couleur que je connaissais déjà (*RGB*,
*HSL*, *HSV*), je voulais pouvoir manipuler des couleurs en *LCHab*,
l'espace de couleur loué dans l'article susmentionné.

#### Colormaps

Ma vieille classe de couleur était accompagnée d'une implémentation
assez simple d'une colormap, permettant l'interpolation linéaire entre
plusieurs couleurs. Étant la feature la plus utilisée de mon ancien
code, il était impensable de ne pas l'adapter à cette nouvelle
bibliothèque.

#### C++11

Bien que ce ne soit pas exactement un objectif en tant que tel, j'ai
utilisé l'excuse du C++11 pour me convaincre que commencer un nouveau
projet pouvait être une bonne idée&nbsp;: tous mes autres projets étant
encore en C++03, je n'avais encore jamais écrit de code utilisant les
nouvelles features de C++11.

---

## Types algébriques > héritage

En raison de mon premier objectif, il n'était pas possible d'avoir une
classe différente par espace de couleur, héritant chacune d'une classe
abstraite *Color*. La raison, bien sûr, la
[vtable](http://en.wikipedia.org/wiki/Virtual_method_table). Pas
d'héritage, pas de vtable, en conséquence de quoi la taille de la classe
devrait être égale à la somme de la taille de ses composants, s'ils sont
correctement alignés. Le standard n'autorisant pas le compilateur à
modifier l'ordre des membres, une classe minimaliste de ce type devrait
respecter mon premier objectif.

Il est par contre important de noter que le fait de dépendre du fait que
les compilateurs aligneront correctement les données en mémoire sans
rien ajouter autour est un peu moche&nbsp;: rien ne les y oblige, ces
classes n'étant pas des
["PODS"](http://isocpp.org/wiki/faq/intrinsic-types#pod-types). Bien
qu'en pratique ce soit bien le cas pour tous les compilateurs testés, en
dépendre pour faire les casts moches susmentionnés (pour *OpenGL* par
exemple), c'est mettre le pied dans les territoires démoniaques des
[*comportements non-spécifiés*](http://blog.llvm.org/2011/05/what-every-c-programmer-should-know.html). Fun
stuff. :)

La meilleure solution pour avoir une classe *Color* générique est
d'utiliser des outils de la programmation fonctionnelle&nbsp;; ici,
nommément, les
[types de données algébriques](http://fr.wikipedia.org/wiki/Type_alg%C3%A9brique_de_donn%C3%A9es). Comme
il n'existe pas en C++ de syntaxe pour écrire un ADT (non, les unions ne
comptent pas), j'ai invoqué le pouvoir du tout-puissant
[`boost::variant`](http://www.boost.org/doc/html/variant.html), qui permet la
création de pseudo "unions typées".

{% highlight c++ %}
typedef boost::variant<
    CMY, CMYK, HSL, HSV, LAB, LCH, RGB, RGBf, RGBub, XYZ
> ColorData;
{% endhighlight %}

Comparé à une hiérarchie classique, un type de ce genre est à l'opposée
en ce qui concerne le fameux
[*Expression Problem*](http://c2.com/cgi/wiki?ExpressionProblem): autant
il devient fastidieux d'ajouter de nouveaux espaces de couleurs, de
nouveaux types (ce qui est en l'occurrence, peu probable), ajouter de
nouvelles fonctions sur les couleurs est facile, et se fait de manière
générique sans avoir besoin d'aller modifier les classes existantes. Et
surtout, il permet de manipuler des couleurs de manière polymorphique,
sur la *stack*, sans pointeur.

---

## Graphe de référence

Une façon naïve mais fastidieuse d'implémenter les conversions entre les
différents espaces de couleur serait d'implémenter chacune des *N \* N*
fonctions. La *MCL* prend plutôt le parti de diviser les espaces de
couleurs en trois groupes.

* Écran&nbsp;: ***RGB***, *HSL*, *HSV*.
* Impression&nbsp;: **CMYK**, *CMY*.
* Indépendant&nbsp;: ***XYZ***, *LAB*, *LCH*.

Chaque groupe a un type de référence (mis en évidence ci-dessus),
déclaré en dur via un `typedef`. Convertir d'un espace de couleur à un
autre revient donc à suivre les arêtes du graphe ci-dessous, ce qui
limite de manière drastique le nombre de fonctions à implémenter. Qui
plus est, s'il faut un jour ajouter un nouvel espace de couleur, il ne
sera nécessaire d'implémenter que les fonctions de conversion vers et
depuis son type de référence.

{% include image.html src="mcl/convert_graph.png" width="300px" legend="Chaque arête est une transformation implémentée." %}

Cette répartition n'est pas le fruit du hasard. Ces trois groupes
exhibent une propriété intéressante&nbsp;: les conversions au sein d'un
groupe ne dépendent d'aucun paramètre externe tel un
[point blanc](http://fr.wikipedia.org/wiki/Point_blanc) (sauf dans un
cas précis&nbsp;: *XYZ* <-> *LAB*). Seules les conversions d'un groupe à un
autre les nécessitent. Tous les paramètres nécessaires sont rassemblées
dans la classe `Environment`.

Toutes les fonctions de la *MCL* qui, à un moment, font des conversions
entre espaces de couleur, prennent en paramètre une variable de type
`Environment`. Par soucis de praticité, chacune admet une variante sans
le paramètre utilisant la variable `Environment::DEFAULT`. Cellle-ci est
faite de manière à ce que tout traitement soit effectué dans un
environnement [*sRGB*](http://fr.wikipedia.org/wiki/SRGB) avec un
*standard illuminant*
[*D65*](http://fr.wikipedia.org/wiki/D65). L'utilisateur souhaitant
personnaliser ce comportement peut soit passer une instance
personnalisée d'`Environnement` à chaque appel, ou plus simplement (mais
moins proprement) remplacer `Environment::DEFAULT`, qui est mutable.

Cela permet par ailleurs d'injecter d'autres fonctions de conversion,
potentiellement bien plus complexes, dans la *MCL*, telles les fonctions
de [LittleCMS](http://www.littlecms.com/) permettant l'utilisation de
[profiles ICC](http://en.wikipedia.org/wiki/ICC_profile).

---

## Composition monoïdale

La plupart des fonctions de transformation de couleur peuvent s'exprimer
sous la forme
d'[endomorphismes](http://fr.wikipedia.org/wiki/Endomorphisme)&nbsp;:
leur type est, schématiquement, `Color -> Color`. Elles forment du coup
un
[monoïde](http://fr.wikipedia.org/wiki/Mono%C3%AFde_%28th%C3%A9orie_des_cat%C3%A9gories%29),
à condition d'implémenter les équivalents de `mempty` et de `mappend`,
qui seraient ici plus justement nommées `id` et `compose`.

Alors qu'en Haskell, c'est relativement trivial,

{% highlight haskell %}
instance Monoid (Endomorphism a) where
    mempty = id
    mappend = (.)
{% endhighlight %}

en C++, c'est une autre paire de manches...

{% highlight c++ %}
// helper functions

template <typename T>
inline Endomorphism<T>
compose(const Endomorphism<T>& f,
        const Endomorphism<T>& g)
{
  using namespace std::placeholders;
  return std::bind(f, std::bind(g, _1));
}

template <typename T>
inline T
id(T const& x)
{
  return x;
}


// monoid instance

template <typename T>
inline Endomorphism<T>
Monoid<Endomorphism<T>>::empty()
{
  return id<T>;
}

template <typename T>
inline Endomorphism<T>
Monoid<Endomorphism<T>>::append(const Endomorphism<T>& f,
                                const Endomorphism<T>& g)
{
  return compose(f, g);
}
{% endhighlight %}

Ces propriétés permettent quelques trucs rigolos, comme le fait de
combiner des transformations, ou même de *folder* des transformations&nbsp;:
une liste de transformations peut être réduite à une seule. Et ces
propriétés restent vraies même avec des fonctions de transformation de
`Color` définies par l'utilisateur, tant qu'elles sont implicitement
convertibles en `Endomorphism`, défini comme `std::function<T (T
const&)>`.

Bien que tout ceci ne faisait pas du tout partie des objectifs initiaux,
le résultat est... esthétiquement satisfaisant. C'était également
l'occasion de chercher une manière d'implémenter des *typeclasses* à la
Haskell en C++, ce pour quoi j'ai trouvé une solution à base de *traits*
amusante à défaut d'être très utile. J'en parlerai plus en détail dans
un prochain article.

---

## Pour résumer

Autant je suis très fier du résultat, autant cette petite bibliothèque a
des limitations sérieuses.

* Le *build system* est l'ideux que j'ai écrit moi-même en 2008...
* La seule fonction fournie pour *clamper* les couleurs hors gamut est très naïve.
* Je n'ai fait aucune analyse poussée de la performance du code
  (intuitivement, monter la limite d'*inlining* devrait avoir un effet
  non négligeable).
* Elle manque drastiquement de feedback de *vrais* utilisateurs&nbsp;!

Si vous voulez en savoir plus sur le fonctionnement technique de la
*MCL*, le [wiki du projet](https://github.com/nicuveo/MCL/wiki) détaille
chaque feature une par une.

Pour résumer et conclure&nbsp;: c'était rigolo. :)
