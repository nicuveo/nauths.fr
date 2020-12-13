---
layout: post
title: "Typeclasses Haskell en C++"
lang: fr
---

{% assign u=site.data.urls %}

Les
[typeclasses](http://learnyouahaskell.com/types-and-typeclasses#typeclasses-101)
de Haskell ont des similarités avec ce que les langages orientés objet
appellent des *interfaces* ou des *classes abstraites* : elles
définissent un contrat, fournissent parfois une implémentation par
défaut... Elles utilisent même un vocabulaire assez proche : on dit d'un
type qui est une instance d'une typeclass qu'il en "dérive".

Parmi les nombreuses différences, une est particulièrement
intéressante : implémenter une typeclass pour un type donné se fait sans
modifier la déclaration du type en question, alors qu'une classe dans la
majorité des langages orientés objets doit déclarer explicitement la
liste des interfaces qu'elle implémente. Une exception notable :
[Go](http://www.golangbootcamp.com/book/interfaces). Mais en C++, qui
d'ailleurs n'a pas de réelle notion d'interface (simplement de classe
abstraite), c'est impossible.

Pendant le développement de ma petite
[bibliothèque *MCL*](/fr/{{u.projs}}#mcl), j'ai choisi de représenter
les transformation de couleurs comme des endomoprhismes ; ça m'a conduit
à implémenter un équivalent de la fonction `mconcat` de Haskell, pour
réduire une liste de transformations à une seule. Souhaitant que le code
reste générique, il m'a fallu trouver un moyen d'exprimer la notion de
monoïde, et donc de typeclass, ce qui m'a poussé à commencer, comme
d'habitude, un petit sous-projet.

Le code qui a résulté de cette petite expérience est
[sur Github](https://github.com/nicuveo/CppTypeclasses), ce post en
détaille la progression. Si vous aviez le moindre doute : ce n'est *pas*
quelque chose que je vous recommande "en vrai". N'essayez pas de faire
ça chez vous. Sauf pour vous amuser. S'amuser, c'est bien.


## Spécialisation partielle

Commençons là où tout a commencé : parlons de `Monoid`. C'est quoi, un
monoïde&nbsp;? En gros, c'est un ensemble (au sens mathématique du
terme), muni d'une fonction binaire associative et de son élément
neutre. En Haskell, un monoïde est exprimé de cette manière :

{% highlight haskell %}
class Monoid a where
    mempty :: a
    mappend :: a -> a -> a
{% endhighlight %}

Comment traduire ça en C++? L'approche naïve est d'utiliser des
fonctions (*template*), qu'il suffit de définir pour chaque type pour
lequel nous voulons implémenter notre typeclass. Il y a deux manières de
redéfinir des fonctions : surcharge et spécialisation. Spécialiser une
fonction template, c'est en créer une définition différente pour un type
explicitement donné ; le compilateur sait qu'il s'agit bien d'une seule
et même fonction, avec plusieurs spécialisations. Surcharger se fait au
contraire en déclarant une nouvelle fonction, qui porte le même nom,
mais avec des paramètres différents.

{% highlight c++ %}
template <typename A>
using Endomorphism = std::function<A(A)>;

template <typename A>
A mempty();

template <typename A>
A mappend(A const&, A const&);

template <typename A>
Endomorphism<A> mempty<Endomorphism<A>>()
{
  return id<A>;
}

template <typename A>
Endomorphism<A> mappend<Endomorphism<A>>(Endomorphism<A> f,
                                         Endomorphism<A> g)
{
  return compose(f, g);
}
{% endhighlight %}

Mais hélas, aucune des deux solutions ne peut marcher... D'une part
parce que la spécialisation partielle de fonctions
[n'est pas autorisée](http://www.gotw.ca/publications/mill17.htm),
d'autre part parce que la surcharge produira forcément des fonctions
ambigües que le compilateur ne sera pas capable de différencier...

Ce qui signifie que nous devons passer à une autre solution : les
*traits* !


## Traits

Les traits sont un outil extrêmement utile lorsqu'on manipule du code
C++ fortement template. En pratique, un trait, c'est une *méta-fonction
sur des types*: une structure template qui associe des informations
(types, constantes, fonctions) au type passé en paramètre. Et comme ils
sont implémentés avec des *struct*, les traits supportent la
spécialisation partielle, ce qui est précisément ce dont nous avons
besoin. Donc, si nous déplaçons tout le code dans une classe `Monoid` et
que nous utilisons la spécialisation partielle...

{% highlight c++ %}
template <typename A>
class Monoid
{
  public:
    static A empty();
    static A append(A, A);
};

template <typename A>
class Monoid<Endomorphism<A>>
{
  public:
    static Endomorphism<A> empty()
    {
      return id;
    }

    static Endomorphism<A> append(Endomorphism<A> f, Endomorphism<A> g)
    {
      return compose(f, g);
    }
};
{% endhighlight %}

...ça marche à la perfection ! Par soucis de simplicité, nous pouvons
définir deux fonctions de wrapping, en dehors de la classe
`Monoid`. Elles peuvent facilement être inlinées par le compilateur, et
sont surtout du sucre syntaxique.

{% highlight c++ %}
template <typename A>
A empty()
{
  return Monoid<A>::empty();
}

template <typename A>
A append(A x, A y)
{
  return Monoid<A>::append(x, y);
}
{% endhighlight %}

Mais cette solution qui marche si bien pour `Monoid` n'est pas
parfaite. L'appliquer telle quelle pour `Functor` a mis en évidence
quelques limitations.


## Méta-problèmes

En Haskell, `Functor` n'est pas défini pour ce qu'on appelle un *type
concret* (de [kind](https://wiki.haskell.org/Kind) `*`), mais pour un
*type paramétré* (de *kind* `* -> *`). Essayer de faire la même chose en
C++ est tout sauf évident...

{% highlight c++ %}
template <typename A>
using Vec = std::vector<A>;

template <template<typename> class F>
class Functor
{
  public:
    template <typename A, typename B>
    static F<B> fmap(std::function<B(A)>, F<A>);
};

template <>
class Functor<Vec>
{
  public:
    template <typename A, typename B>
    static Vec<B> fmap(std::function<B(A)>, Vec<A>)
    {
      // left as an uninteresting exercise to the reader. :)
    }
};

template <template<typename> class F, typename A, typename B>
F<B> fmap(std::function<B(A)> f, F<A> fa)
{
  return Functor<F>::template fmap<A, B>(f, fa);
}
{% endhighlight %}

Le premier problème est que les conteneurs de la *STL* n'ont rarement
qu'un seul paramètre ; `vector` en a par exemple deux, ce qui signfie
qu'il n'est pas possible de lui créer une implémentation de `Functor`,
qui n'attend que des types avec un seul paramètre. Ce problème semble de
prime abord évitable grâce aux *template type synonyms* de C++11, tel
`Vec` introduit dans l'exemple ci-dessus. Mais le compilateur a parfois
un peu de mal à s'y retrouver, entre autre parce que selon le standard,
ces synonymes ne sont jamais utilisés pour la
[détection des arguments template template](http://en.cppreference.com/w/cpp/language/template_argument_deduction),
ce qui nous oblige à expliciter le type *F* dans l'appel à fmap :
`fmap<Vec>(f, v)`.

Ce compromis pourrait sembler acceptable à défaut d'être élégant, mais
cesse d'etre convaincant lorsqu'on réfléchit à notre prochaine
typeclass : `Monad`. Car pour celle-ci, nous allons vouloir surcharger
les opérateurs `>>` et `>>=`. Et expliciter les paramètres templates
d'opérateurs est très laid... Ce qui veut dire que nous avons le choix
entre implémenter des *wrappers* pour chaque classe que nous voulons
utiliser qui n'a pas le bon nombre de paramètres (les conteneurs
standard, `Either`...), et repartir de zéro pour trouver une nouvelle
façon de représenter `Functor` et `Monad`...


## Encore des templates, toujours des templates

Comment, du coup, faire en sorte que le compilateur identifie
correctement nos types tout en gardant une certaine simplicité
d'utilisation ? Hé bien, tout simplement : utiliser des types concrets
dans la spécialisation des templates. `Monad` devrait être implémentée
pour `Vec<A>` plutôt que pour `Vec`. En contrepartie, il faudra fournir
plus d'informations lors de l'implémentation.

{% highlight c++ %}
template <typename MA>
class Monad;

template <typename A>
class Monad<Vec<A>>
{
  public:
    typedef A Type;

    static Vec<A> mreturn(A a);

    template <typename B>
    static Vec<B> bind(Vec<A> as, std::function<Vec<B>(A)> f);
};

template <typename MA, // deduced from ma
          typename MB, // deduced from f
          typename A>  // deduced from f
MB operator >>= (MA ma, std::function<MB(A)> f)
{
  return Monad<MA>::bind(ma, f);
}

template <typename MA, // deduced from ma
          typename MB> // deduced from mb
MB operator >> (MA ma, MB mb)
{
  typedef typename Monad<MA>::Type A;
  std::function<MB(A)> f = [=](A){ return mb; };
  return ma >>= f;
}
{% endhighlight %}

La seule limitation, pour l'opérateur `>>=` ("bind"), est due au fait
que le compilateur déduit les types `MB` et `A` du paramètre `f`, en
conséquence de quoi il n'est pas possible de passer à `bind` une
fonction qui ne soit pas exactement de type `std::function`, telle une
lambda ou un pointeur sur fonction. Mais à ce détail près, nous avons
des monades ! Le code ci-dessous affiche correctement
`[0,1,2,3,4,5,6,7,8]` (à condition d'implémenter `show`).

{% highlight c++ %}
int main()
{
  Vec<int> v = Vec<int> { 1, 4, 7 };
  std::function<Vec<int>(int)> f =
    [](int x){ return Vec<int> { x-1, x, x+1 }; };

  std::cout << show(v >>= f) << std::endl;
}
{% endhighlight %}


## Pour conclure

Le lecteur attentif aura probablement remarqué qu'il n'y avait pas de
définition par défaut de la classe `Monad`. La raison en est simple : ce
n'est pas possible. Il n'y a aucun moyen, à partir du paramètre `MA`, de
déduire les types `M` et `A`. Mais ce n'est pas nécessairement une
mauvaise chose : ce design est celui qui a en général les messages
d'erreur les plus lisibles. Typiquement, essayer d'appeler `fmap` sur un
type `A` quelconque donne le message d'erreur suivant avec *clang* :
`implicit instantiation of undefined template 'Functor<A<int> >'`.

Et... c'est tout. Une méthode pour exprimer des typeclasses à la Haskell
en C++. Tout le code présenté ici (ainsi que quelques autres
typeclasses) est sur
[Github](https://github.com/nicuveo/CppTypeclasses). Bien que certaines
ont potentiellement une *vraie* utilité (tel `Monoid`), l'impact
catastrophique sur les performances de `Monad` et de `Functor` sur les
listes ou les vecteurs fait de ces typcelasses une alternative peu
intéressante à du code écrit à la main utilisant les
[algorithmes standard](http://www.cplusplus.com/reference/algorithm/) de
C++. Elles restent néanmoins une manière amusante d'explorer et de
tester les limites du *type system* de C++.

La suite, comme implémenter la
[monad *Cont*](http://en.wikibooks.org/wiki/Haskell/Continuation_passing_style)
par exemple, est laissé en exercice aux lecteurs/trices motivé·e·s. :)


## Aller plus loin

En faisant la relecture de cet article, j'ai découvert le blog
[*Functional C++*](https://functionalcpp.wordpress.com) ; leur méthode
pour implémenter la
[typeclass `Monoid`](https://functionalcpp.wordpress.com/2013/08/16/type-classes/)
est assez proche de la mienne. Mais ils font aussi des choses amusantes
avec les conteneurs de la *STL*. Une lecture vivement recommandée !
