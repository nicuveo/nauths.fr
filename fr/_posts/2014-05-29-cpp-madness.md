---
layout: post
title: "Le préprocesseur qui rend fou"
lang: fr
---

En tant que développeurs, nous avons tous déjà écrit un jour du code dont nous
étions très fiers. Propre, beau, intuitif, rapide... Des gemmes parfaites, nées
de notre esprit, extraites des minéraux les plus purs. Nous avons hélas aussi
écrit tellement de code de "plomberie", rarement intéressant, parfois
fastidieux, que nous en avons oublié une bonne partie.

Et puis il y a le code vraiment sale, écrit la nuit dans une pièce obscure. Le
genre de code qui pousse les outils qui le manipulent dans leurs
retranchements, le genre de code qui grille les neurones de ceux qui essayent
de le comprendre, le genre de code qui invoque *Cthulhu* si on le lit à
l'envers.

Devinerez-vous dans quel groupe il faut ranger
[*TOOLS_PP*](https://github.com/nicuveo/TOOLS_PP) ?


## Yo, dawg...

Il a été dit un jour que tout problème en informatique pouvait théoriquement
être résolu en ajoutant un niveau d'indirection supplémentaire. Quels problèmes
rencontre-t-on lorsque l'on écrit du code ? Hé bien, par exemple, le problème
du code répétitif (on parle en anglais de [*boilerplate
code*](http://en.wikipedia.org/wiki/Boilerplate_code)). Comment peut-on s'en
débarrasser ? Hé bien, on pourrait ajouter un nouveau niveau d'indirection et
créer un programme qui générerait notre programme ; on pourrait écrire du code
qui générerait tout ce code répétitif. Cette technique est connue, elle porte
un nom : elle est l'une des facettes de la
[metaprogrammation](http://fr.wikipedia.org/wiki/M%C3%A9taprogrammation).

Bien que rien n'empêche d'écrire votre propre outil de *préprocessing* de *C++*
via *Python*, la plupart des langages fournissent leur propre outil standard de
méta-programmation. Les langages de la famille du *Lisp*, tel
[*Clojure*](http://clojure.org/), sont connus pour leur
[homoiconicité](http://fr.wikipedia.org/wiki/Homoiconicit%C3%A9), grâce à
laquelle ils sont leur propre
méta-language. [*Nimrod*](http://nimrod-lang.org/) et
[*Rust*](http://www.rust-lang.org/) ont des systèmes de macros assez puissants,
[*Haskell*](http://www.haskell.org) a le (presque standard) [Template
Haskell](http://www.haskell.org/haskellwiki/Template_Haskell), ce qui permet
dans les trois cas d'écrire, là aussi, le méta-code dans le même langage que le
code.

Mais pendant que ces langages ont des outils de méta-programmation propres,
élégants et vérifiables, les utilisateurs du *C* et du *C++* doivent se
contenter d'un outil un peu plus rudimentaire : le redouté *préprocesseur C*.


## Un outil générique de *préprocessing* de texte ?

Les systèmes de macros tel celui de *Rust* sont intégrés dans les compilateurs
des langages dont ils sont indissociables. À l'inverse, le *préprocesseur C*
(ci-après abrégé en *CPP*) est un outil indépendant avec sa propre syntaxe. Et
bien que les compilateurs *C* et *C++* l'utilisent (ces deux langages n'ont
aucun mécanisme d'`include`, de `using` ou d'`import` : ils dépendent de *CPP*
pour ça), il pourrait parfaitement être utilisé pour transformer n'importe quel
autre type de fichiers, n'importe quel autre langage (comme
[*Brainfuck*](https://github.com/nicuveo/BrainPlusPlus), au hasard)...

Sa syntaxe est relativement simple : chaque ligne commençant par un "#" est
interprétée comme une directive. Il existe une poignée de directives:
`include`, `if` / `else` / `endif`, et bien sûr `define`. Cette dernière est
utilisée pour définir des macros, la fonctionnalité la plus importante de
*CPP*. Et c'est par cette fonctionnalité qu'arrive les possibilités de code
horrible, via la multiple substitution : toute macro peut être remplacée par du
texte contenant une macro qui doit donc être traitée à son tour.

{% highlight c++ %}
// This is harmless.

#define WORLD_WIDTH   42
#define WORLD_HEIGHT  64
#define WORLD_AREA   (WORLD_WIDTH * WORLD_HEIGHT)

const int area = WORLD_AREA; // expanded as (42 * 64)


// This isn't.

#define TYPES_ARRAY (Shape<int>, Shape<float>, Shape<double>)

#define TYPE1(X, Y, Z) X
#define TYPE2(X, Y, Z) Y
#define TYPE3(X, Y, Z) Z
#define APPLY(X, Y) X Y
#define SELECT(X) APPLY(X, TYPES_ARRAY)

void method1(SELECT(TYPE1) const& object); // expanded as Shape<int>
{% endhighlight %}

En voyant les opportunités offertes par ce genre de manipulations, quelques
génies ont écrit
[*Boost.Preprocessor*](http://www.boost.org/doc/libs/release/libs/preprocessor/),
une bibliothèque contenant toutes les définitions de macros nécessaires pour
créer et manipuler des tableaux, des *n*-uplets, des listes et des "séquences"
dans le langage du préprocesseur, malgré la limite imposée par le fait que ce
langage n'est pas
[Turing-complet](http://fr.wikipedia.org/wiki/Turing-complet), en raison de
l'impossibilité de faire du remplacement récursif.


## Vous avez aimé *BOOST_PP* ? Découvrez *TOOLS_PP* !

En utilisateur averti de *Boost.Preprocessor*, j'en ai parfois rencontré les
limites : il m'y a manqué certaines fonctionnalités. C'est ainsi qu'est née
*TOOLS_PP*, ma petite collection d'outils complémentaires à *BOOST_PP*. J'aime
prétendre que je pourrais la soumettre à *Boost*, mais je n'ai pas même
entrepris de me renseigner pour connaître les étapes des processus de
soumission et de validation.

La fonctionnalité principale de *TOOLS_PP* est une très bonne illustration du
code maléfique, tordu et horrible dont je parlais en introduction. J'en suis
très fier. C'est une *macro fonction* nommée `TOOLS_PP_ARRAY_SORT`. (Vous
pouvez en lire le code [sur
Github](https://raw.githubusercontent.com/nicuveo/TOOLS_PP/master/include/nauths/tools_pp/array_sort.hh).)

{% highlight c++ %}
#include <nauths/tools_pp/array_sort.hh>

#define TEST (9, (2, 1, 1, 4, 3, 5, 4, 5, 3))

TOOLS_PP_ARRAY_SORT(TEST)   // expands to (9, (1, 1, 2, 3, 3, 4, 4, 5, 5))
TOOLS_PP_ARRAY_SORT_U(TEST) // expands to (5, (1, 2, 3, 4, 5))
{% endhighlight %}

Conceptuellement, ce n'est pas si compliqué : c'est la syntaxe limitée de *CPP*
qui rend le code si indéchiffrable. La macro se content d'itérer sur tout le
tableau en entrée (grâce à `BOOST_PP_WHILE`), en insérant chaque élément dans
un nouveau tableau accumulé. La position à laquelle il faut insérer l'élément
est donnée par `TOOLS_PP_LOWER_BOUND`, qui ne fait rien de plus compliqué que
d'itérer sur le tableau accumulé. Le principe en est illustré par le code
*Haskell* ci-dessous, qui fait presque la même chose (mais de manière bien plus
lisible).

{% highlight haskell %}
sort [] = []
sort (x:xs) = insert x $ sort xs

insert x [] = [x]
insert x (y:ys)
  | x > y     = y:(insert x ys)
  | otherwise = x:y:ys
{% endhighlight %}


Au final, ce qui est vraiment dérangeant et problématique, ce n'est pas
vraiment `TOOLS_PP_ARRAY_SORT_U` en elle-même ; c'est plutôt le fait que j'en
aie eu besoin, que je l'aie *UTILISÉE* dans un autre projet...

Mais ça, c'est une autre histoire.
