---
layout: post
title: "Haskell typeclasses in C++"
lang: en
---

{% assign u=site.data.urls %}

Haskell's
[typeclasses](http://learnyouahaskell.com/types-and-typeclasses#typeclasses-101)
are somewhat akin to what object oriented languages call *interfaces* or
*abstract classes*: they define a "contract", sometimes offer a default
implementation, and even share some common vocabulary: a type that
is an instance of a typeclass is said to be "deriving" it.

However, amongst the many differences, one stands out: while one can
implement a typeclass for an existing type without modifying it, a class
in most object oriented languages has to explicitly declare which
interfaces it implements. A language that is a notable exception to this
rule is [Go](http://www.golangbootcamp.com/book/interfaces). But in C++,
which doesn't have interfaces but only abstract classes, such a feat is
impossible.

While developing my [*MCL* library](/en/{{u.projs}}#mcl), I chose to
represent color transformations as endomorphisms. It led me to implement
an equivalent of Haskell's `mconcat` function, to compress a list of
transformations into one. Wanting that code to remain generic, I had to
find a way, in C++, to describe monoids, and therefore typeclasses,
which is the reason why I started, as usual, a side project.

The code that emerged from this little experiment is
[on Github](https://github.com/nicuveo/CppTypeclasses), this post is
about the journey. In case you doubted it: this is not something you're
really advised to do. Don't try this at home. Except for fun. Fun is
good.


## Partial specialization

Let's start with `Monoid`, which was my starting point. What's a monoid
anyway? Well, briefly, it's a set (in the mathematical sense) equipped
with an associative binary function and its neutral element. As far as
Haskell is concerned, it's expressed this way:

{% highlight haskell %}
class Monoid a where
    mempty :: a
    mappend :: a -> a -> a
{% endhighlight %}

How should we translate that in C++? The naive first approach is to
simply use (template) functions that we redefine for each type that we
want to make an instance of our typeclass. We have two strategies from
which we can choose when redefining functions: specialization and
overloading. If we choose to specialize our functions, we have to create
an alternate definition of our function with explicit type parameters;
the compiler will know that both are only one function, with different
implementations. Overloading, in contrast, consists in creating a brand
new function with the same name but a different signature.

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

But alas, none of this can work. Partial specialization of functions
[isn't allowed](http://www.gotw.ca/publications/mill17.htm) by the
language, and overloading is not worth trying, at it will obviously only
result in insolvable ambiguous function calls...

Which means we have no choice but to move to traits!


## Traits

Traits are a useful tool while dealing with generic C++ template
code. They're *metaprogramming functions over types*: they're template
structs that map their parameter types to stuff: other types, functions,
constants... And since they're implemented with structs, they can be
partially specialized, which is exactly what we need here. So, if we
move everything in a `Monoid` class and partially specialize it...

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

This works wonders! For convenience, we only have to define two helper
functions outside of the `Monoid` class, and *voilà*. Those two can be
easily inlined and only provide syntaxic sugar.

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

But this solution isn't a silver bullet... When trying to apply the same
strategy to `Functor`, we encounter a new problem.
-

## Too much *kindness*

The issue is that, in Haskell, `Functor` isn't defined over what we
would call a *concrete type* (of [kind](https://wiki.haskell.org/Kind)
`*`), but on a *parameterized type* (of kind `* -> *`). Trying to mimick
this in C++ yields a new bunch of issues.

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

The first issue is that almost all *STL* containers have more than one
template parameter: `vector` for instances has two, which means we can't
specialize `Functor` with it, as `Functor` expects types with only one
template parameter. This seems to be avoidable thanks to C++11 template
type synonyms, such as the introduced `Vec`. However, the compiler has a
hard time resolving our types with such shenanigans, because alias
templates are never used in
[template template argument detection](http://en.cppreference.com/w/cpp/language/template_argument_deduction),
which means that we have to call `fmap` with a fully explicit *F*
parameter, as in `fmap<Vec>(f, v)`.

This might seem acceptable, albeit ugly, until we move to
`Monad`. Because, for `Monad`, we will want to override the `>>` and
`>>=` operators. And we can't really specify explicit parameters on
operators... This means we have to choose between painfully writing
verbose wrappers for all classes that don't have the appropriate
"kindness" (standard containers, `Either`...) or going back to the
drawing board and find a new way to declare `Functor` and `Monad`...


## Going full template

How can we make sure the compiler will resolve our types correctly while
still making it easy to implement said typeclasses? Our only remaining
option: using concrete types in template specialization. `Monad` should
not be specialized over `Vec` but over `Vec<A>`. However, this requires
a bit more information in the typeclass itself.

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

The only downside, regarding the `>>=` operator, is that, since
we're deducing the types of `MB` and `A` from the type of `f`, we can't
use lambdas or function pointers with `bind`: we're restricted to real
instances of `std::function`. But at last, monads work as expected! The
following snippet correctly outputs `[0,1,2,3,4,5,6,7,8]` (given a
proper implementation of `show`).

{% highlight c++ %}
int main()
{
  Vec<int> v = Vec<int> { 1, 4, 7 };
  std::function<Vec<int>(int)> f =
    [](int x){ return Vec<int> { x-1, x, x+1 }; };

  std::cout << show(v >>= f) << std::endl;
}
{% endhighlight %}


## Wrapping up

You might have noticed that we didn't give any common pattern for
`Monad`. That's because we can't: there's no generic way to extract
either `M` or `A` from the given `MA`. But this isn't a bad thing: this
is the pattern that yields the best error messages. Trying, for
instance, to call `fmap` on a random type `A` gives the following error
in *clang*: `implicit instantiation of undefined template
'Functor<A<int> >'`.

And... this is it! A way to build haskell-like typeclasses in C++. You
can find all the code of this article plus some extra on
[Github](https://github.com/nicuveo/CppTypeclasses). Although some of
those typeclasses *might* be useful in some very specific cases
(`Monoid` comes to mind), the cataclysmic performance penalty of
`Functor` or `Monad` over lists or vectors compared to handwritten code
using
[standard C++ algorithms](http://www.cplusplus.com/reference/algorithm/)
isn't worth the lines it saves. It remains, however, a fun way to
explore the internals and limits of C++'s type system.

What comes next, implementing the
[*Cont* monad](http://en.wikibooks.org/wiki/Haskell/Continuation_passing_style)
for instance, is left as an exercise to the motivated reader. :)


## Going further

While proofreading this article, I discovered the
[*Functional C++* blog](https://functionalcpp.wordpress.com); they have
a very similar way of implementing the
[*Monoid* typeclass](https://functionalcpp.wordpress.com/2013/08/16/type-classes/). But
they also do fun stuff with the *STL* containers. Worth the read!
