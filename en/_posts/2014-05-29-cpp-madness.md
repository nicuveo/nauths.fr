---
layout: post
title: "Preprocessor madness"
lang: en
---


As developers, we all have written some code of which we are really
proud. Clean, beautiful, intuitive, fast... Some little gems born from our
minds, carved out of the most precious ore. We also have, alas, written so much
"plumbing" code, barely interesting, sometimes tedious, that we can't recall
half of it.

And then there's the really ugly code, written at night in dark rooms. The kind
that exploits the poor tools that have to process it, the kind that scrambles
the brains of the fellow devs who try to understand how the thing can even
work, the kind that would summon *Cthulhu* if read backwards.

Can you guess in which group [*TOOLS_PP*](https://github.com/nicuveo/TOOLS_PP)
belongs?


## Yo, dawg...

It has been once said that all problems in computer science could theoretically
be solved by another level of indirection. What kind of problems do we
sometimes face when we have to write code? Well, for instance, [boilerplate
code](http://en.wikipedia.org/wiki/Boilerplate_code). How to avoid that? Well,
we could add another level of indirection, and create a program that would
generate our program; we could write code that would generate all the
boilerplate code. This is a known technique; it's a part of what is called
[*metaprogramming*](http://en.wikipedia.org/wiki/Metaprogramming).

While nothing forbids you from rolling your own "*C++ Python preprocessor*"
tool, most languages have a built-in or standard way to meta-program. Languages
of the *Lisp* family, such as [*Clojure*](http://clojure.org/), are famous for
their [homoiconicity](http://en.wikipedia.org/wiki/Homoiconicity), thanks to
which they are their own meta-language. [*Nimrod*](http://nimrod-lang.org/) and
[*Rust*](http://www.rust-lang.org/) have powerful macro systems,
[*Haskell*](http://www.haskell.org) has the almost-standard [Template
Haskell](http://www.haskell.org/haskellwiki/Template_Haskell), all three of
which allow to write meta-code in the same language as the target code.

But while those languages have fancy, checked, proper meta-programming tools,
*C* and *C++* users are stuck with a far simpler tool: the dreaded *C
preprocessor*.


## A general-purpose text-processing tool?

While macro systems such as *Rust*'s are hard-wired in the compiler itself, the
*C preprocessor* (hereafter referred to as *CPP*) is a standalone tool. It has
its own "markup" syntax, and while *C* and *C++* compilers need it and use it
(those two languages do *not* have any `include`, `using` or `import`
statement: they rely on *CPP* for that), it could be used to transform any kind
of text file, any language (such as
[*Brainfuck*](https://github.com/nicuveo/BrainPlusPlus))...

Its syntax is rather simple: any line starting with a "#" is to be
interpreted. There are only a handful of instructions that might be used:
`include`, `if` / `else` / `endif`, and of course `define`. That last one is
used to define macros, the main feature of *CPP*. And with it comes the feature
that can be abused: multiple substitutions. The idea behind it is that a
substitution can output code that is still "substituable".

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

With the opportunities it opens in mind, some clever folks wrote
[*Boost.Preprocessor*](http://www.boost.org/doc/libs/release/libs/preprocessor/),
a library that provide macro definitions that allow one to create and
manipulate arrays, tuples, lists and sequences in the preprocessor language,
although it's not [Turing
complete](http://en.wikipedia.org/wiki/Turing_completeness) due to the lack of
recursion.


## Introducing *TOOLS_PP*

Using *Boost.Preprocessor*, I sometimes needed additional features, missing
from it. This is how [*TOOLS_PP*](https://github.com/nicuveo/TOOLS_PP) came to
life: it's a collection of stuff built on top of *BOOST_PP*. I like to think I
could submit it, have it reviewed as a part of *Boost* itself, but I haven't
even took the time to figure what it would require.

The main feature of *TOOLS_PP* is made of the kind of dark, ugly, wicked code I
was talking about in the introduction. I take a certain pride in it. It's a
macro function named `TOOLS_PP_ARRAY_SORT`. (Read its code [on
Github](https://raw.githubusercontent.com/nicuveo/TOOLS_PP/master/include/nauths/tools_pp/array_sort.hh).)

{% highlight c++ %}
#include <nauths/tools_pp/array_sort.hh>

#define TEST (9, (2, 1, 1, 4, 3, 5, 4, 5, 3))

TOOLS_PP_ARRAY_SORT(TEST)   // expands to (9, (1, 1, 2, 3, 3, 4, 4, 5, 5))
TOOLS_PP_ARRAY_SORT_U(TEST) // expands to (5, (1, 2, 3, 4, 5))
{% endhighlight %}

It isn't that difficult, conceptually; it's *CPP*'s syntax that makes it this
ugly. It sorts the given array by simply folding over it (using
`BOOST_PP_WHILE`), inserting each element in the accumulated array. The correct
insertion index is found with `TOOLS_PP_LOWER_BOUND`, which simply iterates
over the accumulated array. Conceptually, it does almost the same thing as the
following (and far more readable) *Haskell* code.

{% highlight haskell %}
sort [] = []
sort (x:xs) = insert x $ sort xs

insert x [] = [x]
insert x (y:ys)
  | x > y     = y:(insert x ys)
  | otherwise = x:y:ys
{% endhighlight %}


The really, really troubling thing in this story is not `TOOLS_PP_ARRAY_SORT_U`
in itself: it's that I've actually *USED* it in another project...

But that's another story for another time.
