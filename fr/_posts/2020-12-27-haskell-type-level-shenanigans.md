---
layout: post
title: "Méta-programmation en Haskell?"
subtitle: "Les extensions du langage les plus utiles."
lang: fr
---

Mercredi dernier, sur Twitter, [@TechnoEmpress](https://twitter.com/TechnoEmpress) a posté une [solution volontairement horrible](https://twitter.com/TechnoEmpress/status/1341780597442826241) au problème suivant : soient deux types `a` et `b`; est-il possible de déterminer si le type `a` est contenu dans le type `b` ? Autrement dit, est-il possible d'écrire une fonction `contains` telle que :

{% highlight haskell %}
contains @Int         @(Either (Maybe [IO Int]) String) => True
contains @[IO Int]    @(Either (Maybe [IO Int]) String) => True
contains @(Maybe Int) @(Either (Maybe [IO Int]) String) => False
{% endhighlight %}

La réponse est oui, bien sûr, c'est possible. La vraie question, c'est : comment ? En y travaillant, j'ai trouvé plusieurs solutions faisant appel à des parties du langage que je connaissais mal. Il me paraîssait intéressant d'écrire un "retour d'expérience" a posteriori, et de faire le point sur ces extensions du langage : à quoi elles servent, et pourquoi elles sont nécessaires !

## Solution au runtime

La solution la plus simple consiste à utiliser un module de la bibliothèque `base` : [Data.Typeable](https://hackage.haskell.org/package/base/docs/Data-Typeable.html). On y trouve plusieurs fonctions permettant de déterminer le type d'une valeur, et d'obtenir une valeur de type `TypeRep` qui le représente. En utilisant la fonction `typeRepArgs` sur cette dernière, on peut obtenir la liste des paramètres de ce type. Par exemple, pour `Either String Int`, on obtient `[String, Int]`. On peut donc commencer ainsi :

{% highlight haskell %}
contains :: (Typeable a, Typeable b) => a -> b -> Bool
contains a b = containsA typeB
  where
    typeA = typeOf a
    typeB = typeOf b
    containsA x = x == typeA || any containsA (typeRepArgs x)
{% endhighlight %}

Mais on peut faire mieux. Pour commencer, on peut utiliser `typeRep` au lieu de `typeOf`. Cette fonction prend en argument un type "proxy", comme par exemple `Proxy` (défini dans [Data.Proxy](http://hackage.haskell.org/package/base/docs/Data-Proxy.html)) : un type qui ne contient pas d'information, mais sert uniquement à capturer un type. Ce changement nous permet maintenant d'utiliser notre fonction sans nécessiter une valeur des types concernés :

{% highlight haskell %}
contains
  :: (Typeable a, Typeable b) => Proxy a -> Proxy b -> Bool
contains a b = containsA typeB
  where
    typeA = typeRep a
    typeB = typeRep b
    containsA x = x == typeA || any containsA (typeRepArgs x)

> contains (Proxy :: Proxy Int)  (Proxy :: Proxy (Maybe Int))
True
> contains (Proxy :: Proxy Char) (Proxy :: Proxy (Maybe Int))
False
{% endhighlight %}

#### > AllowAmbiguousTypes

Mais on peut faire encore mieux, et nous débarasser entièrement des arguments de cette fonction ! Après tout, s'il est nécessaire d'avoir un proxy pour utiliser `typeRep`, rien ne nous empêche en théorie de le créer directement dans notre fonction, sans qu'il soit passé en argument. En théorie, cette définition est suffisante :

{% highlight haskell %}
contains :: (Typeable a, Typeable b) => Bool
{% endhighlight %}

Mais, en pratique... le compilateur ne l'aime pas. Le problème est que cette définition est ambiguë : il est impossible de déterminer les types `a` et `b` en fonction des arguments de la fonction, puisqu'il n'y a plus d'arguments ! Tout appel à cette fonction sera par définition ambigu, et le compilateur la refuse. La solution, c'est notre première extension : [**AllowAmbiguousTypes**](https://downloads.haskell.org/ghc/latest/docs/html/users_guide/glasgow_exts.html#ambiguous-types-and-the-ambiguity-check). Cette extension désactive cette vérification, et le compilateur accepte maintenant notre nouvelle version :

{% highlight haskell %}
contains :: (Typeable a, Typeable b) => Bool
contains = containsA typeB
  where
    typeA = typeRep (Proxy :: Proxy a)
    typeB = typeRep (Proxy :: Proxy b)
    containsA x = x == typeA || any containsA (typeRepArgs x)
{% endhighlight %}

#### > ScopedTypeVariables

Mais ce n'est pas suffisant, il reste un problème : les définitions dans notre bloc `where` sont indépendantes de la signature de notre fonction. Le compilateur comprend `Proxy a` comme une définition générique, comme il la comprendrait si cette définition était celle d'une fonction : ce `a` est générique, il pourrait s'agir de *n'importe quel type*. Ce qu'il nous faudrait, c'est un moyen de dire au compilateur que ces deux `a` sont les mêmes : ils sont après tout dans le même *scope*... Et c'est évidemment à ça que sert [**ScopedTypeVariables**](https://downloads.haskell.org/ghc/latest/docs/html/users_guide/glasgow_exts.html#lexically-scoped-type-variables). Grâce à cette extension, les types introduits par un `forall` ont un *scope* : le compilateur comprend que le `a` de notre proxy est le même que celui de la signature de la fonction.

{% highlight haskell %}
contains :: forall a b. (Typeable a, Typeable b) => Bool
contains = containsA typeB
  where
    typeA = typeRep (Proxy :: Proxy a)
    typeB = typeRep (Proxy :: Proxy b)
    containsA x = x == typeA || any containsA (typeRepArgs x)
{% endhighlight %}

#### > TypeApplications

Un dernier obstacle : comment appeler cette fonction ? Comme mentionné précédemment, elle est ambiguë ; et il est maintenant nécessaire de résoudre explicitement cette ambiguïté... La solution est, bien sûr, une extension de plus ! Grâce à [**TypeApplications**](https://downloads.haskell.org/ghc/latest/docs/html/users_guide/glasgow_exts.html#visible-type-application), nous avons accès à la syntaxe `@Type`, qui nous permet de spécifier les types de `a` et `b`.

{% highlight haskell %}
> contains @Int         @(Either (Maybe [IO Int]) String)
True
> contains @[IO Int]    @(Either (Maybe [IO Int]) String)
True
> contains @(Maybe Int) @(Either (Maybe [IO Int]) String)p
False
{% endhighlight %}

Le code de cette version est disponible dans [ce gist](https://gist.github.com/nicuveo/e2ac9256bcf1d85d4cf6134265c00890).

Mais... on peut faire mieux. Les types ne sont réellement utiles que pendant la compilation, et la plupart de leur information est perdue au runtime. Il devrait être possible de résoudre intégralement ce problème pendant la compilation... Un des avantages serait que notre solution fonctionnerait pour n'importe quels types, et pas juste ceux qui ont une instance de `Typeable`.

## Solution à la compilation

Si notre solution doit être calculée à la compilation, nous ne pouvons pas la définir avec une fonction : nos arguments seront des types... et notre résultat le sera également. En pur Haskell 98 il n'y a pas (à ma connaissance) de mécanisme pour associer un type à un autre ; il va nous falloir une extension de plus.

#### > TypeFamilies

L'extension [**TypeFamilies**](https://downloads.haskell.org/ghc/latest/docs/html/users_guide/glasgow_exts.html#extension-TypeFamilies) nous permet de définir des associations de type au sein d'une *typeclass*. Par exemple : `IsList` (une autre classe, pour une autre extension) ; un type qui n'est pas générique peut néanmoins avoir une instance de `IsList`, car la définition de la typeclass inclue le type des objects de la liste.

{% highlight haskell %}
class IsList l where
  type Item l
  fromList :: [Item l] -> l
  toList   :: l -> [Item l]
{% endhighlight %}

Ce n'est pas la seule manière d'utiliser les *type families*. Une autre façon de les déclarer, qui va nous être utile, est ce que l'on appelle une *famille fermée* : toute les instances sont définies au moment de la déclaration. Une propriété essentielle de ces familles fermées permet de résoudre le problème usuel des instances qui se "superposent" :

>  _L'avantage d'une famille fermée est le fait que ses équations sont essayées dans l'ordre, comme le seraient les implémentations d'une fonction._

Mais pour commencer : comment allons-nous représenter le résultat de notre function ?

#### > DataKinds

Une possibilité : utiliser deux types abstraits, qu'on associerait de manière arbitraire à "vrai" et "faux".

{% highlight haskell %}
data BTrue
data BFalse

type family Contains a b where
  Contains Int  (Maybe Int) = BTrue
  Contains Char (Maybe Int) = BFalse
  -- TODO: make this more generic
{% endhighlight %}

Mais il y a bien sûr une meilleure solution ; mais pour commencer, il nous faut d'abord parler des *kinds*. Les *kinds* sont simplement le [type des types](https://wiki.haskell.org/Kind) ; le *kind* de `Int` est tout simplement `Type`. `Maybe`, en revanche, n'est pas un type concret : il nécessite un argument. `Maybe Int` a pour *kind* `Type`, mais `Maybe` a pour *kind* `Type -> Type`. [**DataKinds**](https://downloads.haskell.org/ghc/latest/docs/html/users_guide/glasgow_exts.html#datatype-promotion) est une extension qui permet de tout décaler d'un cran : elle permet d'utiliser des types en tant que *kind*, et donc leurs constructeurs en tant que types. Grâce à ça, il est possible de simplement utiliser `Bool` pour notre résultat, et `True` and `False` en tant que "types". La seule différence, en terme de syntaxe, est que les constructeurs doivent être préfixés par une apostrophe quand ils sont utilisés en tant que types.

Ça rend notre première version plutôt lisible :

{% highlight haskell %}
type family Contains (a :: Type) (b :: Type) :: Bool where
  Contains a a = 'True
  Contains _ _ = 'False

> :kind! Contains Int Int
'True
> :kind! Contains Char Int
'False
{% endhighlight %}

Cette première version, assez naïve, correspond à un test d'égalité entre types : si la première instance est choisie, les deux types sont les mêmes, et le type qui est associé à `Contain` est `'True`. Si la première instance ne peut être sélectionnée, le compilateur choisira la deuxième, qui est valide pour n'importe quels types, et asssociera `'False`. L'étape suivante : déconstruire des types plus complexes, pour pouvoir inspecter récursivement leurs arguments :

{% highlight haskell %}
type family Contains (a :: Type) (b :: Type) :: Bool where
  Contains a a     = 'True
  Contains a (f x) = Contains a x
  Contains _ _     = 'False

> :kind! Contains Int (Maybe Int)
'True
> :kind! Contains Int (Maybe (Maybe Int))
'True
> :kind! Contains Char (Maybe Int)
'False
{% endhighlight %}

Dans l'ordre : `Contains Int (Maybe Int) = Contains Int Int = 'True`. Notre récursion vient en deuxième, pour éviter de continuer la récursion lorsqu'on arrive à notre résultat : `Contains [IO Int] [IO Int]` doit retourner `'True` directement, sans essayer de faire une récursion sur `[]`.

Mais... on est pas encore sortis de l'auberge :

{% highlight haskell %}
> :kind! Contains Int (Int, Char)
'False
> :kind! Contains Int (Either Int Char)
'False
{% endhighlight %}

Le problème, c'est le *pattern* pour notre récursion : `f x`. Dans le cas de `Either Int Char`, `x` est `Char`, un type, et `f` est `Either Int`, une "fonction entre types", de *kind* `Type -> Type`. Notre récursion inspecte `x`, mais devrait également inspecter `f`...

Une solution très naïve serait simplement de décomposer explicitement tous les types à *n* arguments, pour une valeur de *n* raisonnable. Mais c'est une solution inélégante, verbeuse, et surtout incorrecte :

{% highlight haskell %}
type family Contains (a :: Type) (b :: Type) :: Bool where
  Contains a (_ a _ _ _) = 'True
  Contains a (_ _ a _ _) = 'True
  Contains a (_ _ _ a _) = 'True
  Contains a (_ _ _ _ a) = 'True
  Contains a (_ a _ _)   = 'True
  Contains a (_ _ a _)   = 'True
  Contains a (_ _ _ a)   = 'True
  Contains a (_ a _)     = 'True
  Contains a (_ _ a)     = 'True
  Contains a (_ a)       = 'True
  Contains a a           = 'True
  Contains _ _           = 'False
{% endhighlight %}

Ce qu'il nous faudrait, ce serait un moyen de faire notre récursion sur chacune des deux parties de notre *pattern* : `a` est-il contenu dans `x`, *ou* `a` est-il contenu dans `f`? Mais cette approche révèle de nouveaux obstacles ; le premier d'entre eux est tout simplement : comment faire une récursion sur `f` ?


#### > PolyKinds

La raison pour laquelle il n'est pas valide de simplement essayer `Contains a f` est que nous avons déclaré le deuxième argument de `Contains` avec un kind `Type`. Pour notre récursion sur `f`, il nous faudrait une deuxième *typeclass*, totalement identique, mais pour laquelle le deuxième argument aurait pour *kind* `Type -> Type`. Et pour la récursion dans cette deuxième *typeclass*, il nous en faudrait une troisième pour `Type -> Type -> Type`, et ainsi de suite...

Plus simplement, il nous faudrait écrire une classe qui est la même pour *n'importe quel kind*, une classe générique. Et c'est exactement ce que permet [**PolyKinds**](https://downloads.haskell.org/~ghc/latest/docs/html/users_guide/glasgow_exts.html#extension-PolyKinds) : il nous est possible de définir notre deuxième argument comme un argument générique pour n'importe quel kind `k`, ce qui nous permet de faire notre récursion sur `f` :

{% highlight haskell %}
type family Contains (a :: Type) (b :: k) :: Bool where
  Contains a a     = 'True
  Contains a (f x) = Contains a f ??? Contains a x
  Contains _ _     = 'False
{% endhighlight %}

La dernière étape : combiner nos deux appels récursifs. Ce qu'il nous faut, c'est un "ou booléen" entre types ! Pas besoin de nouvelle extension pour ça, nous avons tout ce qu'il faut pour simplement créer :

{% highlight haskell %}
type family Or (a :: Bool) (b :: Bool) :: Bool where
  Or 'True  _ = 'True
  Or 'False b = b
{% endhighlight %}


#### > UndecidableInstances

Au final, une fois toutes les pièces du puzzle rassemblées, on obtient :

{% highlight haskell %}
type family Contains (a :: Type) (b :: k) :: Bool where
  Contains a a     = 'True
  Contains a (f x) = Or (Contains a f) (Contains a x)
  Contains _ _     = 'False
{% endhighlight %}

Mais, vous vous en doutez, ça ne compile pas encore... GHC est assez strict, et veut pouvoir garantir que le choix d'une instance ne contiendra pas de boucle infinie, que la compilation pourra tojours arriver à un résultat. Pour cette raison, il interdit certaines constructions "dangereuses" qui, mal utilisées, pourraient causer une boucle infine. L'une d'entre elles : avoir un appel à une *type family* dans la définition d'une autre *type family*, ce qui est exactement ce que nous voulons faire ! Une extension dangereuse, [**UndecidableInstances**](https://downloads.haskell.org/~ghc/latest/docs/html/users_guide/glasgow_exts.html#extension-UndecidableInstances), désactive cette restriction à nos risques et périls, et permet à notre solution de compiler.


#### > TypeOperators

Notre solution est maintenant correcte ! Mais nous pouvons néanmoins l'améliorer encore un peu. Une dernière étape : plutôt que de créer notre propre "ou booléen", nous devrions utiliser celui qui existe déjà, défini dans [Data.Type.Bool](https://hackage.haskell.org/package/base-4.14.1.0/docs/Data-Type-Bool.html). Le seul défi : il est défini en tant qu'opérateur ! Vous vous en doutez, l'extension qui va nous permettre d'utiliser un opérateur sur nos types est  [**TypeOperators**](https://downloads.haskell.org/~ghc/latest/docs/html/users_guide/glasgow_exts.html#extension-TypeOperators).

Au final, voici notre résultat, notre version définitive :

{% highlight haskell %}
type family Contains (a :: Type) (b :: k) :: Bool where
  Contains a a     = 'True
  Contains a (f x) = Contains a f || Contains a x
  Contains _ _     = 'False
{% endhighlight %}

#### Mettre en valeur notre solution.

Pour pouvoir utiliser notre solution dans un programme, et pas juste dans `ghci`, il nous suffit de définir une dernière classe, permettant de transformer un "type" booléen en une valeur booléenne :

{% highlight haskell %}
class ToBool (b :: Bool) where
  toBool :: Bool

instance ToBool 'True  where toBool = True
instance ToBool 'False where toBool = False
{% endhighlight %}

Il nous est maintenant possible d'écrire :

{% highlight haskell %}
> toBool @(Contains Int (Either Int String))
True
> toBool @(Contains Int (Either Int))
True
{% endhighlight %}

Et... voilà ! Vous pouvez trouver le code de cette deuxième version dans ce [deuxième gist](https://gist.github.com/nicuveo/275d66bcc179e586444ce3cee9871536). Cet exercice, même si un peu futile, était très amusant, et instructif. J'espère que ce compte-rendu vous sera également utile !

Bonne année, tout ça. :)
