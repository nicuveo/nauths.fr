---
layout: post
title: "Double dispatch extensible en C++"
lang: fr
---

{% assign u=site.data.urls %}

Ces temps-ci, j'essaie de vérifier la validité d'une petite astuce
permettant à l'auteur d'une bibliothèque C++ d'exposer une API
permettant du *double dispatch* grâce à un visiteur *extensible aux
types définis par l'utilisateur*. La grande question : est-ce que ma
solution est valable pour tous les compilateurs et respecte le standard
du langage ? Le but de ce post est de revenir sur ce travail : présenter
le besoin de départ, les difficultés rencontrées, et enfin quémander
l'avis de gens plus compétents que moi. :)

Repartons du début : qu'est-ce que le *dispatch dynamique* ?

---

## Dispatch dynamique

Le *dispatch dynamique* est le procédé responsable, à l'exécution, de la
résolution des appels de fonctions en fonction du type des arguments. En
C++, ce procédé est utilisé pour les méthodes *virtuelles*, en
conséquence de quoi il est restreint à ce qu'on pourrait traduire en
*dispatch unique* : la résolution ne se fait qu'en étudiant le type d'un
seul objet, celui sur lequel la méthode virtuelle est appelée. En
pratique, les compilateurs l'implémentent via une
[*vtable*](http://en.wikipedia.org/wiki/Virtual_method_table), mais il
me semble que c'est un choix d'implémentation et que le standard ne
préconise rien à ce sujet.

Dans l'exemple ci-dessous, l'appel `b->onClick(l)` est donc "dispatché"
à l'implémentation de `onClick` de la classe `Button`. Il n'y a aucun
moyen, via ces méthodes virtuelles, de dispatcher l'appel à des
implémentations différentes en fonction du type de `l`.

{% highlight c++ %}
class Element {
  public:
    virtual void onClick(Element* sender) = 0;
};

class Button : public Element {
  public:
    virtual void onClick(Element*) {
      std::cout << "You clicked on a button!" << std::endl;
    }
};

class Label : public Element {
  public:
    virtual void onClick(Element*) {
      std::cout << "You clicked on a label?" << std::endl;
    }
};

void main() {
  Element* b = new Button();
  Element* l = new Label();
  b->onClick(l);
}
{% endhighlight %}

Bien sûr, tout le problème vient de cette limitation du C++. Si le
langage supportait le *dispatch multiple*, grâce à des "multi-méthodes"
par exemple, cet article n'aurait aucune raison d'être. Mais hélas, les
multi-méthodes ne sont pour l'instant rien de plus qu'une simple
[proposition](http://www.stroustrup.com/multimethods.pdf).

Mais du coup, comment contourner cette restriction ; comment faire du double dispatch en C++ ?

---

## Les Visiteurs

Un des *design patterns* du
[Gang of Four](http://c2.com/cgi/wiki?GangOfFour), le
[Visiteur](http://butunclebob.com/ArticleS.UncleBob.IuseVisitor), est la
réponse usuelle à cette question. Bien qu'un peu verbeux, il est en
effet une solution à la fois simple et efficace. Il suffit de définir
une *interface* `Visitor` dotée d'une méthode virtuelle pure pour chacun
des types sur lesquels le premier dispatch est effectué. Il suffit
ensuite d'implémenter des classes qui héritent de `Visitor` pour obtenir
du double dispatch.

{% highlight c++ %}
class Visitor {
  public:
    virtual void apply(Button*) = 0;
    virtual void apply(Label*)  = 0;
};

class Button : public Element {
  public:
    virtual void apply(Visitor* v) {
      v->apply(this);
    }
};

class Label : public Element {
  public:
    virtual void apply(Visitor* v) {
      v->apply(this);
    }
};

class IdentificationVisitor : public Visitor {
  public:
    virtual void apply(Button*) { std::cout << "Button!" << std::endl; }
    virtual void apply(Label*)  { std::cout << "Label!"  << std::endl; }
}
{% endhighlight %}

C'est assez verbeux, puisque pour chaque fonction sur laquelle on veut
faire du double dispatch il faut créer une nouvelle classe héritant de
`Visitor`. Mais, bon, ça marche. Et, bonus : un visiteur est une bonne
manière d'utiliser le mécanisme de dispatch dyamique pour ajouter du
comportement supplémentaire à une hiérarchie de classe tout en
respectant le
[principe de responsabilité unique](http://en.wikipedia.org/wiki/Single_responsibility_principle). Rien
que du bon.

Mais cette approche a une grosse limitation : la liste des classes doit
être exhaustivement connue au moment de la déclaration de `Visitor`. Si
ces classes sont dans une bibliothèque, alors un·e utilisateur/trice ne
peut les étendre avec ses propres classes et utiliser le `Visitor`
dessus...

---

## Les macros à la rescousse

Dans le cas mentionné ci-dessus dans lequel on souhaite étendre une
hiérarchie de classe, une autre approche serait d'utiliser des macros
afin d'étendre la définition de `Visitor` pour y ajouter les méthodes
nécessaires à l'utilisation des types définis par l'utilisateur. Avec
cette solution, la bibliothèque ne peut plus utiliser de visiteur en
interne, n'ayant pas la définition complète de `Visitor` au moment de sa
compilation.

Le code ci-dessous montre un petit exemple de ce à quoi une solution de
ce genre pourrait ressembler.

{% highlight c++ %}
// dans la bibliothèque

class Visitor
{
  public:
#ifdef USER_TYPES
    BOOST_PP_MAGIC_MACROS(USER_TYPES)
    // déclaration de "apply" pour chaque type dans USER_TYPES
#endif
    virtual void apply(const Button&) const = 0;
    virtual void apply(const Label&)  const = 0;
};

class Button : public Element {
  public:
    virtual void apply(Visitor* v) {
      v->apply(*this);
    }
};

class Label : public Element {
  public:
    virtual void apply(Visitor* v) {
      v->apply(*this);
    }
};


// dans le client

class TextBox;

#define USER_TYPES (TextBox)
#include <library>

class TextBox : public Element {
  public:
    virtual void apply(Visitor* v) {
      v->apply(*this);
    }
};
{% endhighlight %}

Ça n'a pas l'air mal. `Visitor` contient bien des déclarations pour le
type défini par l'utilisateur, ce qui signifie que nous avons bien
atteint notre objectif de double dispatch extensible, non ? Hé
bien... pas tout à fait. Il reste un *tout petit* problème...

---

## （╯°□°）╯︵ǝןqɐʇʌ

Le problème vient du fait qu'à la compilation le client et la
bibliothèque voient deux versions différentes (et incompatibles) de
`Visitor`, et génèrent donc deux vtables différentes. Et tant g++ que
clang acceptent de les fusionner sans le moindre
avertissement. L'horrible résultat ? ***Du dispatch silencieusement
erroné à l'exécution !*** Sans le faire exprès, j'ai réussi avec du code
en apparence très simple à atterrir à pieds joints dans la terrible zone
des "comportements indéfinis du compilateur", dont j'ignorais
l'existence et pour lesquels je viens de créer ce terme.

Compiler avec `g++ -fdump-class-hierarchy` permet d'étudier l'agencement
des différentes versions de la vtable de `Visitor`. Le petit tableau
ci-dessous en montre le contenu dans les deux unités de compilation.

offset | library.o         | client.o
------ | ----------------- | -------------------
0      | *0*               | *0*
8      | *destructor*      | *destructor*
16     | apply(**Button**) | apply(**TextBox**)
24     | apply(**Label**)  | apply(**Button**)
32     |                   | apply(**Label**)

Et donc, au moment de linker, que se passe-t-il ? Encore une fois, tant
g++ que clang ***choisissent silencieusement la plus volumineuse des
deux***, définie dans le client. Ce qui signifie que tous les appels à
des méthodes de `Visitor` compilés dans la bibliothèque se retrouvent
redirigés en fonction de cette nouvelle table ; autrement dit,
`Button::apply(Visitor*)` appelle donc `Visitor::apply(const TextBox&)`
au lieu de `Visitor::apply(const Button&)`, au runtime ! Le genre de
trucs qui peut foirer de tas de manières, toutes aussi silencieuses
qu'intéressantes...

Une solution aussi rapide qu'inacceptable serait de réordonner la
déclaration de `Visitor`, de manière à ce que les méthodes
supplémentaires ne soient définies *qu'après* celles de la bibliothèque,
préservant ainsi l'ordre de la vtable du client. Certes, ça "marche",
mais ce n'est pas fiable. Une meilleure solution serait de faire en
sorte que la vtable ne soit pas générée du tout dans la bibliothèque...

---

## Comment se débarrasser d'une vtable

Le meilleur moyen de n'avoir aucune vtable pour `Visitor` est
encore... de ne pas déclarer `Visitor` ! La prédéclarer est suffisant
pour déclarer les méthodes `apply` dans les headers. Le seul endroit où
la prédéclaration ne suffit pas est bien entendu là où le contenu de la
classe est nécessaire : dans l'implémentation de ces méthodes. Il ne
reste plus qu'à trouver un moyen simple d'avoir tant la déclaration de
`Visitor` que l'implémentation des `apply` dans le client, et le tour
est joué.

Le moyen le plus simple que j'ai trouvé pour l'instant est de les mettre
dans un header séparé, jamais inclus dans la bibliothèque elle-même, et
inclus dans une seule unité de compilation du client (pas dans un
header). La bibliothèque ne voit ainsi qu'une prédéclaration de
`Visitor`, aucune vtable n'est générée. Le seul inconvénient de cette
méthode est qu'elle nécessite une manipulation spécifique de la part du
client (inclure ce fameux header), quand bien même l'utilisateur/trice
n'a pas l'intention d'étendre le visiteur avec ses propres classes.

{% include image.html src="odd/ded_table.jpg" width="300px" title="OH NOES" legend="The only good vtable is a dead (or missing) vtable." %}

---

## I can has reviews?

Eeeet... ça marche ! De ce que j'ai pu comprendre, il semble impossible
que du code erroné / une vtable conflictuelle soit généré·e à partir
d'une simple prédéclaration. Mais avant de me réjouir : j'aimerais avoir
un deuxième avis, un regard neuf, une vérification. Un exemple simple
qui marche
[est sur Github](https://gist.github.com/nicuveo/3a4927116f033813c10e). Tout
retour sera apprécié à sa juste valeur. Merci d'avance ! :)

{% include image.html src="odd/please.jpg" width="320px" title="Pretty please?" %}
