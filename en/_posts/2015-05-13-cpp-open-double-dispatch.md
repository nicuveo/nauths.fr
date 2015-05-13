---
layout: post
title: "C++ open double dispatch"
lang: en
---

{% assign u=site.data.urls %}

I'm currently trying to validate a method I've found that allows a C++
library writer to do double dispatch via a visitor *that also supports
user-defined types* (hence the "open"). I have yet to make sure that it
is correct with respect to the standard and to compiler
implementations... The goal of the post is to explain why I'm doing
that, to present my proposal, and to plead for help from people more
knowledgeable than me. :)

Let's go back to the very beginning: what's dynamic dispatch?

---

## Dynamic dispatch

*Dynamic dispatch* is the process that, at run time, dispatches a method
call to the correct implementation, based on the type of its
arguments. In C++, it is used for *virtual* methods, and is therefore
restricted to *single dispatch*: the object on which the method is
called is the only one considered by the dispatcher. It is usually
implemented via a
[*vtable*](http://en.wikipedia.org/wiki/Virtual_method_table), though as
far as I know this is implementation defined.

In the following example, the call `b->onClick(l)` is dispatched to
`Button`'s implementation of the `onClick` method based only on `b`'s
type. There is no way via virtual methods to have this call dispatched
to different methods based on the runtime type of `l`.

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

Of course, the whole issue stems from the fact that C++ only has *single
dispatch*. With *multiple dispatch*, with *multi-methods* for instance,
we wouldn't have this problem. However, multi-methods have yet to go
beyond their status as
[proposal](http://www.stroustrup.com/multimethods.pdf).

So, with this restriction, how can we do *double dispatch* in C++?

---

## Visitor pattern

[GOF](http://c2.com/cgi/wiki?GangOfFour)'s
[Visitor pattern](http://butunclebob.com/ArticleS.UncleBob.IuseVisitor)
is the usual answer to this question. Although a verbose solution, it
remains a simple enough one: one simply has to define a `Visitor`
*interface* that has a pure virtual method for each of the types on
which the first dispatch is performed. One then only has to implement a
class that derives from `Visitor` to achieve double dispatch.

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

It's verbose, since any function that needs multiple dispatch has to be
written as a class that inherits from `Visitor`, but it does the job,
with the added benefit of providing a clean way of leveraging the
dispatch mechanism to add new behavior to existing class without
breaking the
[single responsibility principle](http://en.wikipedia.org/wiki/Single_responsibility_principle). Good
stuff.

But this approach suffers from one severe drawback: the list of classes
has to be fully known in order to declare `Visitor`. If those classes
and the visitor are exposed in a library, the library user can't create
her own classes inheriting from `Element` and use a `Visitor` on them...

---

## A *macro* proposal

In the specific case previously mentioned, in which a library exposes a
class hierarchy that might be extended by the user, an other approach
would be to extend the `Visitor` declaration with user-defined types via
macros. This would mean that the library itself wouldn't be able to
declare visitors internally, since it wouldn't, at the library compile
time, have the full list of classes.

A small example of such an approach would look like that.

{% highlight c++ %}
// in library

class Visitor
{
  public:
#ifdef USER_TYPES
    BOOST_PP_MAGIC_MACROS(USER_TYPES)
    // expands to an "apply" declaration for each type in USER_TYPES
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


// in client

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

Seems good! The `Visitor` interface contains a method declaration for
all classes, including the user-defined ones, which means we've reached
our goal of open double dispatch, right? Well... not quite yet: a huge
problem remains.

---

## （╯°□°）╯︵ǝןqɐʇʌ

The problem lies in the fact that the library and the client see
different (and conflicting) versions of `Visitor`, which means the
vtables differ... And both g++ and clang merge the conflicting vtables
without a single warning. The horrifying result? ***Silent incorrect
dispatch at runtime!*** Without realising it, I've managed to reach the
dreaded "undefined compiler behavior" zone, which is both something I
didn't know existed and a term I just made up to describe it.

Compiling with `g++ -fdump-class-hierarchy` allows us to inspect the
vtables layout. The following table displays how the vtable for
`Visitor` is generated in each translation unit.

offset | library.o         | client.o
------ | ----------------- | -------------------
0      | *0*               | *0*
8      | *destructor*      | *destructor*
16     | apply(**Button**) | apply(**TextBox**)
24     | apply(**Label**)  | apply(**Button**)
32     |                   | apply(**Label**)

What happens at link time? Both g++ and clang ***silently choose the
biggest one***, defined in the client. However, this means that all call
to methods of `Visitor` in the library are now rerouted according to
this new vtable; in other words, `Button::apply(Visitor*)` ends up
calling `Visitor::apply(const TextBox&)` instead of
`Visitor::apply(const Button&)` at runtime! As one can imagine, this is
bound to fail in very, *very* interesting ways...

A quick and dirty solution would be to reorder the declaration of
`Visitor` in order to ensure that user-defined methods are declared
*after* the library ones, preserving the declaration order in the client
vtable. It does work... It is however *highly* unreliable. A better
solution would be to prevent the vtable from being generated in the
library altogether...

---

## How to kill a vtable

The best way to prevent the `Visitor` vtable from being generated... is
simply not to declare `Visitor` at all! A predeclaration is enough to
declare the `apply` methods in the headers. The only place where its
predeclaration is not enough is where, of course, its content is used:
in the implementation of those `apply` method. If we manage to have both
the `Visitor` declaration and the `apply` implementations in the client
rather than in the library, we've won.

The simplest way I've found so far is to have both of them in a separate
header, never included in the library itself, and included once in a
compilation unit of the client (not in a header). What the library only
ever sees is a predeclaration of `Visitor`: no vtable is generated. The
only downside is therefore this need for a specific file to be included
in one and only one C++ file: this puts some burden on the library user,
even if she does not plan on declaring her own classes.

{% include image.html src="odd/ded_table.jpg" width="300px" title="OH NOES" legend="The only good vtable is a dead (or missing) vtable." %}

---

## Pining for reviews

Aaaand... it seems to work! From what I can gather, there's no way for
erroneous code or conflicting vtables to be generated for a type that is
only predeclared. But before celebrating too soon: I'd like reviews,
please, to make sure this is indeed correct! A small working example
[can be found in this gist](https://gist.github.com/nicuveo/3a4927116f033813c10e). All
feedback will be appreciated. Thanks! :)

{% include image.html src="odd/please.jpg" width="320px" title="Pretty please?" %}
