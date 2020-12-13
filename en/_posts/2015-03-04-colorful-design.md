---
layout: post
title: "Colorful design"
lang: en
---

{% assign u=site.data.urls %}

A few weeks ago, I proudly released the *1.0.0-alpha* version of
[*MCL*](/en/{{u.projs}}#mcl) and updated the
[*Projects*](/en/{{u.projs}}) page of this site accordingly,
disregarding my resolution to release existing projects rather than work
on new ones. In all fairness, this project isn't of utmost importance
and I'll probably remain its only user, but to quote what I said back
when [I released *SAW*](/en/2014/03/30/saw.html):

> It's not much, mainly because no one is using it besides me, which
> means I have no issues to deal with, no weird bugs that I can't seem
> to reproduce... But it doesn't mean that releasing it publicly is
> devoid of meaning.

So, let's talk about colors, design, C++ and build systems! This post
focuses on some technical aspects of the *MCL*, in no particular
order. A (likely) next article will focus on color interpolation fun
facts.


## Once upon a time...

...there was an
[interesting article](http://blog.noctua-software.com/procedural-colors-for-game.html)
on *Hacker News*. It talked about procedural color generation, and color
interpolation using the *CIE LCHab* color space. As it happens, I had
already written a rudimentary *RGB* and *HSV* hybrid color class that I
used for such a purpose, but it had several shortcomings, the main one
being caching all fields of the two color spaces (*R*, *G*, *B*, *H*,
*S*, *V*). As a result:

* this `Color` class was rather heavy,
* it was hard to extend with other color spaces,
* it wasn't efficient (frequent recomputation).

I was therefore usually using several color classes at the same time:
this one for interpolation, translated into another one that I used with
*OpenGL* code... It was far from being convenient. Inspired by that
article, I launched head first into a better color class implementation,
starting what would become the *MCL*.


## Requirements

From the start, I had a few goals that I wanted to achieve. While some
of the funny features emerged later, while coding, those were intended
from day 1.

#### A lightweight *RGB* class

I wanted to have a *RGB* struct that I could cast to a `float*`, a
`double*`, or a `unsigned char*`, depending on the chosen data
type. This would allow me to have *RGB* arrays that I could give
directly to *OpenGL*, amongst other possibilities.

#### Support for *LCHab* color space

In addition to the color spaces I already knew (namely *RGB*, *HSV* and
*HSL*), I wanted this future library to be able to also handle *LCHab*
values, which were at the heart of the aforementioned article.

#### Linear colormaps

There already was a colormap implementation along with the old color
class. It would need to be adapted to the new color classes, as this was
the main feature I wanted to achieve.

#### C++11

Although this isn't exactly a requirement, I used the excuse of C++11 to
convince myself it would be a good idea to start a brand new project: I
hadn't yet written anything using C++11's new features.


## Algebraic types over inheritance

Due to requirement #1, I could not have different classes for each
color space (*RGB*, *HSV*...) all inheriting from a common *Color* base
class abstraction. The reason being, of course, the
[vtable](http://en.wikipedia.org/wiki/Virtual_method_table). No
inheritance means no vtable, meaning in turn that the size of the class
should be the sum of the size of its elements, providing they're
correctly aligned. As the compiler isn't allowed by the standard to
modify the members order, the resulting class should meet the
requirement.

It is worth noting, however, that relying on the fact that compilers
won't pad those classes with any kind of metadata is a bit ugly, as
there is no rule in the standard that enforces such a layout (those
classes being
[non-POD](http://isocpp.org/wiki/faq/intrinsic-types#pod-types)). Although
it behaves correctly on all tested systems and all tested compilers,
using that knowledge to do ugly casts (for *OpenGL* purposes for
instance) is a direct step into the uncharted unholy territory of
[*undefined behaviour*](http://blog.llvm.org/2011/05/what-every-c-programmer-should-know.html). Fun
stuff. :)

The best solution to have a generic *Color* class is to use functional
programming tools: in this case,
[algebraic data types](http://en.wikipedia.org/wiki/Algebraic_data_type). As
there is no native support for such types in C++ (unions do not count),
I unleashed the almighty
[`boost::variant`](http://www.boost.org/doc/html/variant.html), which
allows the creation of pseudo "typed unions".

{% highlight c++ %}
typedef boost::variant<
    CMY, CMYK, HSL, HSV, LAB, LCH, RGB, RGBf, RGBub, XYZ
> ColorData;
{% endhighlight %}

Compared to a type hierarchy, such a type is at the opposite end of the
[Expression Problem](http://c2.com/cgi/wiki?ExpressionProblem): while it
makes it tedious to add new color spaces, new types (something that is,
in this case, unlikely, or at least uncommon), adding new generic
functions over color spaces is easy, and can be done without modifying
the existing classes. But more importantly, this type allows for easy,
polymorphic, pointer-free use of different color spaces instances on the
stack.


## Reference graph

A naive way of implementing color space conversion would be to have all
*N \* N* conversion functions, which would be a hassle to
implement. Instead, the *MCL* splits the different color spaces in three
groups.

* Print group: **CMYK**, *CMY*.
* Display group: ***RGB***, *HSL*, *HSV*.
* Absolute group: ***XYZ***, *LAB*, *LCH*.

Each group has a "reference" type (highlighted above), which each type
knows via a `typedef`. Converting from a color space *A* to a color
space *B* is therefore done by moving along the resulting graph (see
below). This severely limits the total number of functions
needed. Furthermore, adding a new color space would only mean
implementing conversion from and to its reference type.

{% include image.html src="mcl/convert_graph.png" width="300px" legend="Edges are hard-coded transformations." %}

Those groups were not chosen randomly. They exhibit a nice behavior:
color conversion inside a group does not depend on external parameters
such as a [referent white](http://en.wikipedia.org/wiki/White_point)
(except for one very specific exception: *XYZ* <-> *LAB*). Conversions
from one group to one of the others do however require such
parameters. They're all bundled in a class called `Environment`.

All *MCL* functions that might need at some point to convert from one
color space to another have a `Environment` parameter. For convenience,
however, they all have a `Environment`-free variant that passes in
`Environment::DEFAULT`, which specifies that all device independent
color spaces have to considered as being
[*sRGB*](http://en.wikipedia.org/wiki/SRGB) with a
[*D65*](http://en.wikipedia.org/wiki/Illuminant_D65) standard
illuminant. Users that want to specify another behavior can inject their
`Environment` instances in all calls, or choose the sinful path of
overriding `Environment::DEFAULT`, which is mutable.

This also means users are free to plug any advanced function of their
choice in the *MCL*, such as [LittleCMS](http://www.littlecms.com/)
[ICC profiles](http://en.wikipedia.org/wiki/ICC_profile) transform
functions, to convert from *RGB* to *CMYK* for instance.


## Monoidal composition

Most transformation functions can be expressed as
[endomorphisms](http://en.wikipedia.org/wiki/Endomorphism): their type
is `Color -> Color`. As such, they form a
[monoid](http://en.wikipedia.org/wiki/Monoid_%28category_theory%29),
providing that we implement the equivalents of `mempty` and `mappend`,
in this case `id` and `compose`.

While in Haskell this is really straightforward,

{% highlight haskell %}
instance Monoid (Endomorphism a) where
    mempty = id
    mappend = (.)
{% endhighlight %}

in C++, it's a tiny bit more verbose...

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

This allows for fun stuff, such as combining transformations, or even
transformations folding: a list of color transformations can be reduced
to a single one. This is also true for any user defined function over
`Color` instances, as long as it can be implicitly made into an
`Endomorphism`, which is defined as `std::function<T (T const&)>`.

Although this was not part of the requirements, this was aesthetically
rather pleasing. It was also the opportunity to find a way to implement
Haskell-like typeclasses in C++, for which I found a *traits*-based
solution that I find funny if not particularly useful. I'll speak more
about it in an upcoming article.


## Wrap up

Although I'm quite proud of how everything turned out, this library has
several shortcomings.

* The build system is my own ugly one, hand-written in 2008...
* The only clamping functions provided for out of gamut colors is really
  naive.
* I have made no thorough performance study of the code performance
  (though I suspect it'll work better with a high inlining limit).
* It severely lacks feedback from *real* users!

If you want to see more details about some technical aspects of the
*MCL*, the [wiki of the project](https://github.com/nicuveo/MCL/wiki)
details each major feature of the library.

To summarize: this was a lot of fun. :)
