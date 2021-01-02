---
layout: post
title: "Haskell type-level functions shenanigans"
subtitle: "An introduction to some useful language extensions"
lang: en
---

Last Wednesday, on Twitter, [@TechnoEmpress](https://twitter.com/TechnoEmpress) posted a [purposefully horrible solution](https://twitter.com/TechnoEmpress/status/1341780597442826241) to the following problem: given two types `a` and `b`, how does one test that type `a` is contained in type `b`? Can we write a function `contains` such that:

{% highlight haskell %}
contains @Int         @(Either (Maybe [IO Int]) String) => True
contains @[IO Int]    @(Either (Maybe [IO Int]) String) => True
contains @(Maybe Int) @(Either (Maybe [IO Int]) String) => False
{% endhighlight %}

The answer is: of course we can; the real question is *how*. Looking into it, I found several possible implementations, that relied on parts of the language I wasn't very familiar with. I thought it'd be interesting to go over them, and highlight why each extension is required, step by step. So... let's go!

## Runtime solution

The easiest approach relies on a `base` library: [Data.Typeable](https://hackage.haskell.org/package/base/docs/Data-Typeable.html), which provides functions that, to a given runtime value, associate a corresponding `TypeRep` value that represents the value's type. Using `typeRepArgs` on that representation, one can obtain the list of the type arguments of a given type: from the representation of `Either String Int`, we can get `[String, Int]`. A first approach could therefore look like this:

{% highlight haskell %}
contains :: (Typeable a, Typeable b) => a -> b -> Bool
contains a b = containsA typeB
  where
    typeA = typeOf a
    typeB = typeOf b
    containsA x = x == typeA || any containsA (typeRepArgs x)
{% endhighlight %}

There are several ways to improve on this: first, we can use `typeRep` instead of `typeOf`: its argument is a proxy type, such as `Proxy` from [Data.Proxy](http://hackage.haskell.org/package/base/docs/Data-Proxy.html): a type that does not contain any data and is only used as a way to convey type information. This allows us to call `contains` even if we do not have actual values of our types.

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

But we can go one step further: what if our function had no runtime argument? After all, while we need a proxy to call `typeRep`, we can create it in the function itself, it doesn't need to be passed as an argument. Ideally, we'd like to define our function as such:

{% highlight haskell %}
contains :: (Typeable a, Typeable b) => Bool
{% endhighlight %}

However... This definition doesn't compile: the compiler will not be able to identify what the types of `a` and `b` are from the arguments to the function, given that there's no longer any argument! Calls to that function will therefore be ambiguous, and the compiler rejects it. The solution to this problem is provided by our first language extension: [**AllowAmbiguousTypes**](https://downloads.haskell.org/ghc/latest/docs/html/users_guide/glasgow_exts.html#ambiguous-types-and-the-ambiguity-check). It simply disables that check in the compiler. We can now implement our function:

{% highlight haskell %}
contains :: (Typeable a, Typeable b) => Bool
contains = containsA typeB
  where
    typeA = typeRep (Proxy :: Proxy a)
    typeB = typeRep (Proxy :: Proxy b)
    containsA x = x == typeA || any containsA (typeRepArgs x)
{% endhighlight %}

#### > ScopedTypeVariables

But that still does not compile! The problem is that the bindings in our `where` block are independent from our function's signature. So when we say `Proxy a`, it could be _any_ `a`: it is understood to be generic, as it would be in a top-level function's signature. What we would need is a way to tell the compiler that the `a` in the where block is the same as the one in the function's signature, that they're in the same scope. Introducing [**ScopedTypeVariables**](https://downloads.haskell.org/ghc/latest/docs/html/users_guide/glasgow_exts.html#lexically-scoped-type-variables); thanks to it, type variables introduced with the `forall` syntax will, well, be scoped: the compiler will now know that the `a` in that `Proxy a` is indeed the same one as in the function's signature.

{% highlight haskell %}
contains :: forall a b. (Typeable a, Typeable b) => Bool
contains = containsA typeB
  where
    typeA = typeRep (Proxy :: Proxy a)
    typeB = typeRep (Proxy :: Proxy b)
    containsA x = x == typeA || any containsA (typeRepArgs x)
{% endhighlight %}

#### > TypeApplications

But now, how do we actually call that function? We have disabled the ambiguity check, but we need to resolve that ambiguity at the call site. And, of course, one more extension solves this problem: thanks to [**TypeApplications**](https://downloads.haskell.org/ghc/latest/docs/html/users_guide/glasgow_exts.html#visible-type-application), we can use the `@Type` syntax to specify what `a` and `b` are.

{% highlight haskell %}
> contains @Int         @(Either (Maybe [IO Int]) String)
True
> contains @[IO Int]    @(Either (Maybe [IO Int]) String)
True
> contains @(Maybe Int) @(Either (Maybe [IO Int]) String)p
False
{% endhighlight %}

You can find the code of this version in [this gist](https://gist.github.com/nicuveo/e2ac9256bcf1d85d4cf6134265c00890).

But... we can do better. Type information is only relevant at compilation time, and is (mostly) elided at runtime. It should be possible to solve this entirely at compile time... With that, we could also extend our function to work on *any* type, not just the ones that define a `Typeable` instance.

## Compile-time solution

If we are to write a solution at compile-time, we can't write it as a function. Our input is going to be a type but... our output is also going to be a type. There's no way to write a mapping from type to type in Haskell 98 (AFAIK); to do so, we'll need our first language extension.

#### > TypeFamilies

[**TypeFamilies**](https://downloads.haskell.org/ghc/latest/docs/html/users_guide/glasgow_exts.html#extension-TypeFamilies) allows us to add type mappings to regular typeclasses. For instance, consider the class `IsList` (defined as part of another language extension): types that are not generic over their content can still be valid instances of `IsList`, and the typeclass therefore includes a type mapping, so that each instance can specify what the type of the contained items is:

{% highlight haskell %}
class IsList l where
  type Item l
  fromList :: [Item l] -> l
  toList   :: l -> [Item l]
{% endhighlight %}

There's several different ways to declare a type family; one that's going to be useful for a us is a _top-level closed type family_, in which all instances are given together alongside the declaration. There's additionally one very interesting property of those closed families, which solves the problem of overlapping instances:

>  _The advantage of a closed family is that its equations are tried in order, similar to a term-level function definition._

But first: how are we going to represent our result?

#### > DataKinds

We could use some arbitrary new abstract types to represent truthiness:

{% highlight haskell %}
data BTrue
data BFalse

type family Contains a b where
  Contains Int  (Maybe Int) = BTrue
  Contains Char (Maybe Int) = BFalse
  -- TODO: make this more generic
{% endhighlight %}

but there's of course a better solution. But first, we need to talk about ~~parallel universes~~ kinds. Kinds are, in essence, the [type of types](https://wiki.haskell.org/Kind). `Int` has kind `Type`; `Maybe` requires a type argument to yield a type, such as in `Maybe Int`, and has therefore kind `Type -> Type`. [**DataKinds**](https://downloads.haskell.org/ghc/latest/docs/html/users_guide/glasgow_exts.html#datatype-promotion) is an extension that allows to "lift things one level up". Types are allowed to be used at the kind level, which means that their constructors are allowed to be used at the type level. Which means that here, we can use good ol' `Bool` type as a kind, and use `True` and `False` as "types". Syntax-wise, we have to prefix a constructor with a single quote to use it at the type level.

With this, and with the fact that patterns are tried in order, we can write our first attempt:

{% highlight haskell %}
type family Contains (a :: Type) (b :: Type) :: Bool where
  Contains a a = 'True
  Contains _ _ = 'False

> :kind! Contains Int Int
'True
> :kind! Contains Char Int
'False
{% endhighlight %}

What we have here is a very naive version of type equality: if the compiler can match the first line, it will associate the "type" `'True` to the type application of contains, otherwise fall back to the second instance, which is defined for all possible types. The only thing left to do is for us to handle recursion: we'll need to decompose more complex types and recurse over them:

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

Recursively: `Contains Int (Maybe Int) = Contains Int Int = 'True`. We don't match the recursive case first to avoid decomposing our type when we have a match: `Contains [IO Int] [IO Int]` should return `True` without matching the recursive case.

But... we're not out of the woods yet:

{% highlight haskell %}
> :kind! Contains Int (Int, Char)
'False
> :kind! Contains Int (Either Int Char)
'False
{% endhighlight %}

The problem lies in our recursive match: `f x`. In the case of `Either Int Char`, `x` is `Char`, a type, and `f` is `Either Int`, a type function of kind `Type -> Type`. In our recursion, we only check `x`, but we would need to decompose `f` too...

A naive solution would be to manually decompose up to as many arguments as we deem reasonable, but that's very verbose, not complete, and quite unsatisfying:

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

A better solution would be, in the case of `f x`, to recurse on _both parts_: is `a` contained in `f`, or is `a` contained in `x`? This poses two problems; the first is: how can we recurse on `f`?


#### > PolyKinds

The problem we face is that we have explicitly declared the second argument of `Contains` to be of kind `Type`. To be able to recurse on `f`, we'd need a similar type family, in which the second argument would be of kind `Type -> Type`. And, in the recursion case of that second type family, we'd need to delegate the recursion to a third type family for types of kind `Type -> Type -> Type`... and so on.

What we need is instead to define our family so that it is _generic over kinds_. That's what we can do with [**PolyKinds**](https://downloads.haskell.org/~ghc/latest/docs/html/users_guide/glasgow_exts.html#extension-PolyKinds): we can now declare that the kind of our `b` parameter is generic: any kind `k` will do, which allows us to recurse on `f` too:

{% highlight haskell %}
type family Contains (a :: Type) (b :: k) :: Bool where
  Contains a a     = 'True
  Contains a (f x) = Contains a f ??? Contains a x
  Contains _ _     = 'False
{% endhighlight %}

The only thing that's left is to combine our two recursive calls: what we'll need is a boolean "or" at the type-level! It's thankfully pretty straightforward, now, with all our extensions:

{% highlight haskell %}
type family Or (a :: Bool) (b :: Bool) :: Bool where
  Or 'True  _ = 'True
  Or 'False b = b
{% endhighlight %}


#### > UndecidableInstances

Putting it together:

{% highlight haskell %}
type family Contains (a :: Type) (b :: k) :: Bool where
  Contains a a     = 'True
  Contains a (f x) = Or (Contains a f) (Contains a x)
  Contains _ _     = 'False
{% endhighlight %}

But as you might have guessed, this doesn't compile. GHC really wants to guarantee that instance resolution terminates in finite time; for that reason, it forbids several patterns that it deems "dangerous", such as nested type family applications, which is precisely what we're trying to do here! A dangerous extension, [**UndecidableInstances**](https://downloads.haskell.org/~ghc/latest/docs/html/users_guide/glasgow_exts.html#extension-UndecidableInstances), disables some of those checks at our own risk, and allows our solution to compile.


#### > TypeOperators

While our solution is now correct, we can make it better. One last thing we can do is use an existing implementation of type-level boolean `or`, rather than reimplementing our own: there is one already in [Data.Type.Bool](https://hackage.haskell.org/package/base-4.14.1.0/docs/Data-Type-Bool.html). You'll notice however that it is defined as an operator! As you will have guessed, this is what is allowed by [**TypeOperators**](https://downloads.haskell.org/~ghc/latest/docs/html/users_guide/glasgow_exts.html#extension-TypeOperators).

With that, we can finally settle on one final version:

{% highlight haskell %}
type family Contains (a :: Type) (b :: k) :: Bool where
  Contains a a     = 'True
  Contains a (f x) = Contains a f || Contains a x
  Contains _ _     = 'False
{% endhighlight %}

#### Coming to terms with our solution

For convenience, and without any extension, we can define a simple typeclass to bring our type-level booleans back to term-level:

{% highlight haskell %}
class ToBool (b :: Bool) where
  toBool :: Bool

instance ToBool 'True  where toBool = True
instance ToBool 'False where toBool = False
{% endhighlight %}

We can now finally test it:

{% highlight haskell %}
> toBool @(Contains Int (Either Int String))
True
> toBool @(Contains Int (Either Int))
True
{% endhighlight %}

And... that's it! You can find this version of the code in [this other gist](https://gist.github.com/nicuveo/275d66bcc179e586444ce3cee9871536). This was a silly but fun exercise, I learned a ton, hopefully this will be useful to you too!

Happy new year, and all that sort of things. :)
