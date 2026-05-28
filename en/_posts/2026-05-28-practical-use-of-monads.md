---
layout: post
title: "Practical uses of monads in Haskell"
lang: en
---

On the "haskellquestions" subreddit, a user recently asked for some help
with monads in Haskell. In their post, they wrote (slightly paraphrased):

> I feel stuck. I understand the basic concept of monads, but when it comes to
> the practical use of different types of monads, I am lost.

My answer to them was [one long
comment](https://www.reddit.com/r/haskellquestions/comments/1tmaic9/comment/onltku4/). But,
in hindsight, I think that I could have structured my answer a bit differently,
I could have chosen better examples, I could have made that comment more
helpful. This post is an attempt at doing just so.

In it, we will explore how we can use some standard monads to structure our
code, what benefits they bring, and how to use them. In some ways, it covers a
lot of what a hypothetical "Haskell 103" would have been, back when I was
teaching Haskell at Google.

This post contains optional exercises, that you can expand if you want to test
your understanding of each section!

<div markdown="1" id="markdown-toc-container">
**Contents**
* TOC
{:toc}
</div>


## Preamble

This post's intended audience is people who are in the same boat as that
original Reddit user: people who understand monads in Haskell *in theory*, but
struggle to use them in practice. Consequently, this post will not re-explain
basic Haskell syntax, and will assume familiarity with it. More importantly, we
will not be covering what monads *are*. This post is not yet another monad
tutorial.

In other words, this should make sense to you:

{% highlight haskell %}
class Applicative m => Monad m where
  (>>=) :: m a -> (a -> m b) -> m b
{% endhighlight %}

Ok, so `Monad` is the trait of types that provide the chaining operator `>>=`
often referred to as `andThen` in other languages. Great. Now what can we *do*
with that?

### Do

Even if this post doesn't re-explain monads, it's worth going over `do`
notation. `do` notation is one of the direct practical benefits of monads; it's
an essential part of the syntax of the language, that desugars to calls to
`>>=`. To demonstrate its convenience, let's use a slightly contrived example
that my former students will remember. Let's imagine that we want to chain
operations in `Maybe`; that is, operations that can fail to return a result,
like a lookup for instance. If we imagine that we have access to those three
functions:

{% highlight haskell %}
lookupTransaction :: TransactionID -> Maybe Transaction
lookupCustomer    :: Transaction -> Maybe UserID
lookupUser        :: UserID -> Maybe User
{% endhighlight %}

we could build one new big function that, given a `TransactionID`, gives us the
`Maybe User` of the corresponding customer if it exists.

Without using monads at all, such a function could be written like this:

{% highlight haskell %}
lookupTransactionCustomer :: TransactionID -> Maybe User
lookupTransactionCustomer tid =
  case lookupTransaction tid of
    Nothing -> Nothing
    Just transaction ->
      case lookupCustomer transaction of
        Nothing -> Nothing
        Just uid ->
          lookupUser uid
{% endhighlight %}

It's not very complicated, but it's clunky: at every step, we must check whether
we got `Just` a value, and "return early" if we didn't and got `Nothing`. It's
like Go's `if err != nil { return err; }`, but with staircases. Surely we can do
better.

Obviously we remember that `Maybe` is a monad! The nitty-gritty details of how
to chain operations have already been implemented for us, we don't have to do
all those `case _ of` manually. Rewriting this function to make use of `>>=`
gives us the following:

{% highlight haskell %}
lookupTransactionCustomer :: TransactionID -> Maybe User
lookupTransactionCustomer tid =
  lookupTransaction tid >>= \transaction
    lookupCustomer transaction >>= \uid ->
      lookupUser uid
{% endhighlight %}

This is better, and not just because it's more terse: each step performs a
lookup, and we chain into the next step as long as the previous one gave us a
value. But... it's still a staircase. We can do better, by using the
aforementioned "do notation".

### Desugaring

The keyword `do` opens a block, in which whitespace is significant: newlines
separate "statements". This allows us to write sequential code, step by step,
and have it translated back into the correct chain of monadic operations.

{% highlight haskell %}
-- this do block
foo = do
  a <- bar
  baz
  b <- qux
  pure (a, b)

-- desugars to
foo =
  bar >>= \a ->
    baz >>= \_ ->
      qux >>= \b ->
        pure (a, b)
{% endhighlight %}

Armed with this, we can now finally rewrite our example function in its most
readable form (if not its most concise):

{% highlight haskell %}
lookupTransactionCustomer :: TransactionID -> Maybe User
lookupTransactionCustomer tid = do
  transaction <- lookupTransaction tid
  uid <- lookupCustomer transaction
  lookupUser uid
{% endhighlight %}

The core thing to remember is that this notation desugars to `>>=`, meaning that
it works for *any* monad. We can write `do` blocks for expressions in `Maybe`,
for lists, for `IO`... and so on.

<details>
<summary><h4>Exercise 1</h4></summary>
<div markdown="1" class="exercise">
Here's a classic "hello world" example:

{% highlight haskell %}
main :: IO ()
main = do
  putStrLn "Please input your name:"
  userName <- getLine
  putStrLn $ "Hello " ++ userName ++ "!"
{% endhighlight %}

Rewrite it without `do`, only using `>>=`.

<details>
<summary>Solution</summary>
<div markdown="1" class="solution">
{% highlight haskell %}
main :: IO ()
main =
  putStrLn "Please input your name:" >>= \_ ->
    getLine >>= \userName ->
      putStrLn $ "Hello " ++ userName ++ "!"
{% endhighlight %}

If you don't need the argument to `>>=`, you can use `>>` instead:

{% highlight haskell %}
main :: IO ()
main =
  putStrLn "Please input your name:" >>
    getLine >>= \userName ->
      putStrLn $ "Hello " ++ userName ++ "!"
{% endhighlight %}
</div>
</details>
</div>
</details>

<details>
<summary><h4>Exercise 2</h4></summary>
<div markdown="1" class="exercise">
Here's a list comprehension expression:

{% highlight haskell %}
foo :: [Int] -> [Int]
foo l = [x + 5 | x <- l, even x]
{% endhighlight %}

Rewrite it with `>>=`, and then with `do`.  
Hint: you should use `guard :: Bool -> [()]`.

<details>
<summary>Solution</summary>
<div markdown="1" class="solution">
All following implementations are valid.

{% highlight haskell %}
foo l = l >>= \x -> guard (even x) >>= \_ -> pure (x + 5)
foo l = l >>= \x -> guard (even x) >> pure (x + 5)
foo l = l >>= \x -> guard (even x) >> [x + 5]

foo l = do
  x <- l
  guard $ even x
  pure $ x + 5
{% endhighlight %}
</div>
</details>
</div>
</details>

## Motivating example

In our quest to showcase the benefits of monads, let's set ourselves a goal:
let's build a trivial command-line calculator, with variables. Something we can
use like this:

{% highlight text %}
> x = 4
> 6 + x * 3 - 2
16
{% endhighlight %}

To complicate things and make them more interesting, let's imagine that this
calculator can be run with a "debug" option, that prints a detail of every step
of the calculation:

{% highlight text %}
> x = 4
> 6 + x * 3 - 2
: x = 4
: 4 * 3 = 12
: 6 + 12 = 18
: 18 - 2 = 16
16
{% endhighlight %}

The structure of such a program isn't very complicated: we need a main loop that:
- displays a prompt
- reads a line
- parses the line into a statement
- executes the statement

For the sake of not making this post more overwhelming than it already is, we
will only cover the last item. That is: assuming that we already have code that
parses a line, and our role is to write the execution stage, how do we do that?

### Types

Since we assume that the rest of the program is already given, we don't have to
think about what the type representation of our statements needs to be. Here's
what we will be working with:

{% highlight haskell %}
data AppConfig = AppConfig
  { debugMode :: Bool
  }

type VarName = Text

type Variables = HashMap VarName Int

data Statement
  = SetVariable VarName Expression
  | ComputeExpression Expression

data Expression
  = Literal        Int
  | Variable       VarName
  | Addition       Expression Expression
  | Subtraction    Expression Expression
  | Multiplication Expression Expression
  | Division       Expression Expression
  | Modulo         Expression Expression
{% endhighlight %}

We don't need to represent parentheses, nor to worry about precedence: this is
all handled for us during parsing. For instance:

{% highlight haskell %}
-- the expression
3 + x * 5 / (4 - y)

-- gets parsed as
(Addition
  (Literal 3)
  (Division
    (Multiplication
      (Variable "x")
      (Literal 5)
    )
    (Subtraction
      (Literal 4)
      (Variable "y")
    )
  )
)
{% endhighlight %}

### Goal

Our job today is to write the `execute` and `evaluate` functions, that
respectively take a `Statement` and an `Expression` as an argument. But the
question is... what *shape* must they take?

{% highlight haskell %}
execute :: Statement -> ???
execute = error "TODO"

evaluate :: Expression -> ???
evaluate = error "TODO"
{% endhighlight %}

We will start by identifying all of the "capabilities" that those functions
require: what arguments they need, what must be present in their return type,
and so on. Afterwards we will introduce several monads that each, individually,
provide one such capability we have identified; and finally we will see how we
can bring them all together to find a clean solution.

## Capabilities

### Function type

To figure out the "capabilities" we need, let's start by having a look at
`evaluate`. We know what kind of result we want: we want a value, so the result
has to be an `Int`:

{% highlight haskell %}
evaluate :: Expression -> Int
{% endhighlight %}

But, obviously, even if we parsed it correctly, an expression can be incorrect:
division by zero, reference to an unknown variable... Not all evaluations will
succeed, so we need to be able to handle errors, both in `evaluate` and in
`execute`: if evaluating an expression can fail, so can executing a
statement. We will therefore use our trusty `Either` to represent our result,
with a simple `Text` error message:

{% highlight haskell %}
evaluate :: Expression -> Either Text Int
{% endhighlight %}

Furthermore, we will need to know whether we are in debug mode or not, so that
we know whether to display individual steps of the computation, so `evaluate`
needs to also have access to the `AppConfig`:

{% highlight haskell %}
evaluate :: AppConfig -> Expression -> Either Text Int
{% endhighlight %}

We probably don't want `evaluate` itself to print with `IO`, so it means we need
to return our debug log lines as part of our output type.

{% highlight haskell %}
evaluate
  :: AppConfig
  -> Expression
  -> Either Text (Int, Seq Text)
{% endhighlight %}

And of course we need to have access to our variables. The final form of `evaluate` therefore becomes:

{% highlight haskell %}
evaluate
  :: AppConfig
  -> Variables
  -> Expression
  -> Either Text (Int, Seq Text)
{% endhighlight %}

For `execute`, the reasoning is the same, except for the fact that it also needs
to return the new map of variables, since it might have been modified by an
assignment, leaving us finally with:

{% highlight haskell %}
execute
  :: AppConfig
  -> Variables
  -> Statement
  -> Either Text (Int, Seq Text, Variables)
{% endhighlight %}

### Naive implementation

Now that we have an idea of the type of our functions, we can try implementing
them "manually", like we did in our first example earlier. Even with a partial
implementation, we can see very quickly that the sum of all of those
"capabilities" makes the code complex and quite clunky:

{% highlight haskell %}
evaluate
  :: AppConfig
  -> Variables
  -> Expression
  -> Either Text (Int, Seq Text)
evaluate appConfig variables expression = case expression of
  Multiplication lhs rhs ->
    case evaluate appConfig variables lhs of
      Left errorMsg -> Left errorMsg
      Right (lhsValue, lhsLog) ->
        case evaluate appConfig variables rhs of
          Left errorMsg -> Left errorMsg
          Right (rhsValue, rhsLog) ->
            let
              result  = lhsValue * rhsValue
              logLine = printf ": %d * %d = %d" lhsValue rhsValue result
            in
              Right
                ( result
                , if debugMode appConfig
                  then lhsLog <> rhsLog |> Text.pack logLine
                  else Seq.empty
                )
  Division lhs rhs ->
    case evaluate appConfig variables lhs of
      Left errorMsg -> Left errorMsg
      Right (lhsValue, lhsLog) ->
        case evaluate appConfig variables rhs of
          Left errorMsg -> Left errorMsg
          Right (rhsValue, rhsLog) ->
            if rhsValue == 0 then
              Left "division by zero"
            else
              let
                result  = lhsValue `div` rhsValue
                logLine = printf ": %d / %d = %d" lhsValue rhsValue result
              in
                Right
                  ( result
                  , if debugMode appConfig
                    then lhsLog <> rhsLog |> Text.pack logLine
                    else Seq.empty
                  )
  _ -> error "TODO"
{% endhighlight %}

If you gave up trying to read this halfway through, I can't blame you. Deep
staircases of doom, and a lot of repetition... This isn't very
elegant. Obviously, we can do better, by using monads.

## Monads

A first step is to realize that `evaluate` returns an `Either Text` value, and
so do the intermediate steps, the recursive calls to `evaluate` itself. So, we
can trivially get rid of some of the staircases by using the monadic properties
of `Either`, with a `do` block!

{% highlight haskell %}
evaluate
  :: AppConfig
  -> Variables
  -> Expression
  -> Either Text (Int, Seq Text)
evaluate appConfig variables expression = case expression of
  Multiplication lhs rhs -> do
    (lhsValue, lhsLog) <- evaluate appConfig variables lhs
    (rhsValue, rhsLog) <- evaluate appConfig variables rhs
    let
      result  = lhsValue * rhsValue
      logLine = printf ": %d * %d = %d" lhsValue rhsValue result
    Right
      ( result
      , if debugMode appConfig
        then lhsLog <> rhsLog |> Text.pack logLine
        else Seq.empty
      )
  Division lhs rhs -> do
    (lhsValue, lhsLog) <- evaluate appConfig variables lhs
    (rhsValue, rhsLog) <- evaluate appConfig variables rhs
    if rhsValue == 0 then
      Left "division by zero"
    else do
      let
        result  = lhsValue `div` rhsValue
        logLine = printf ": %d / %d = %d" lhsValue rhsValue result
      Right
        ( result
        , if debugMode appConfig
          then lhsLog <> rhsLog |> Text.pack logLine
          else Seq.empty
        )
  _ -> error "TODO"
{% endhighlight %}

I don't think I'm going to have a hard time convincing you that this is
better. The code behaves the same, but we no longer do all the tedious manual
job of checking each step for errors.

There is a metaphor that you will sometimes see in monad tutorials, that claims
that monads are a "programmable semicolon". I am personally not a huge fan of
this comparison, but I think this example illustrates this line of thinking
quite well: if you imagine a semicolon separating each statement in those `do`
blocks (which is, by the way, valid syntax, you can do that!), then yeah: how we
move from one statement to the next, the invisible glue that binds them, that's
dictated by the monad we have chosen.

Another line of thinking, that we'll explore in more details if / when I write a
part 2 to this post, is to think more in terms of "capability": what does the
monad we have chosen provide us with? In this case, with `Either Text`, it's the
capability to short-circuit with an error if a computation fails.

Let's now look at what other repetitive tasks we perform in this version of the
code, to see what else we could simplify. There are three aspects worth
investigating:
- we pass the `AppConfig` to every function call, in `execute`, in `evaluate`,
  recursively: it would be nice if we could make it an "implicit" part of the
  code, available where we need it, that we don't need to explicitly thread
  along;
- whenever we make a recursive call to `evaluate`, we have to collect the debug
  logs it outputs and combine then manually;
- `execute` takes the variables as input, returns the new variables as output,
  and those variables are then threaded through `evaluate`, it would likewise be
  nice to be able to abstract that away without manual bookkeeping.

As mentioned earlier, there's a monad that can help us with each of those
problems. Introducing three ubiquitous monads: `Reader`, `Writer`, and `State`.

### Reader

The `Reader` monad is an essential component of most Haskell applications,
despite its simplicity. You can think of `Reader r a`, that is a value `a` in
the `Reader r` monad, as being equivalent to `r -> a`: a function that produces
an `a` given a `r`. You can imagine the `r` as being some kind of "environment",
accessible to all functions in that `Reader r` monad; it is often used to store
things such as an application config, that we want easily accessible from
everywhere without having to manually pass it around.

In practice, `Reader` provides us with one simple function:

{% highlight haskell %}
ask :: Reader r r
{% endhighlight %}

Which is, basically: while in the context of `Reader r`, retrieve that value
`r`. For a contrived and unrealistic example:

{% highlight haskell %}
-- at the top level

compileModule :: Source -> Reader Options Object
compileModule source = do
  rawAST       <- parse source
  validatedAST <- analyze rawAST
  rawIR        <- lower validatedAST
  optimizedIR  <- optimize rawIR
  generateCode optimizedIR

-- deep within the analysis part of the code

analyzeVariableDeclaration
  :: Context
  -> VariableDeclaration
  -> Reader Options (ValidatedVariableDeclaration, [Diagnostic])
analyzeVariableDeclaration context declaration = do
  let shadowsAnExistingVariable =
        varName declaration `isMemberOf` context
  -- we retrieve the options
  options <- ask
  let diagnostics =
        if shouldWarnVariableShadow options &&
           shadowsAnExistingVariable
        then [WarnVariableShadow context declaration]
        else []
  undefined -- TODO
{% endhighlight %}

All the way down into some analysis function, we can call `ask` and retrieve the
options, despite the fact that they are never passed explicitly: the type system
informs us that every function has the "capability" to `ask` for the options.

In our calculator example, we could think about using `Reader` to store the
`AppConfig`, if we weren't already using the `Either` monad.

<details>
<summary><h4>Exercise 3</h4></summary>
<div markdown="1" class="exercise">
Here's a simplified implementation of `Reader`:

{% highlight haskell %}
newtype Reader r a = Reader { runReader :: r -> a }
{% endhighlight %}

Implement `Functor`, `Applicative`, `Monad`, and `ask`:

{% highlight haskell %}
instance Functor (Reader r) where
  fmap :: (a -> b) -> Reader r a -> Reader r b
  fmap = undefined -- TODO

instance Applicative (Reader r) where
  pure :: a -> Reader r a
  pure = undefined -- TODO

  (<*>) :: Reader r (a -> b) -> Reader r a -> Reader r b
  (<*>) = undefined -- TODO

instance Monad (Reader r) where
  (>>=) :: Reader r a -> (a -> Reader r b) -> Reader r b
  (>>=) = undefined -- TODO

ask :: Reader r r
ask = undefined -- TODO
{% endhighlight %}

<details>
<summary>Solution</summary>
<div markdown="1" class="solution">
{% highlight haskell %}
instance Functor (Reader r) where
  fmap :: (a -> b) -> Reader r a -> Reader r b
  fmap f (Reader a) = Reader $ f . a

instance Applicative (Reader r) where
  pure :: a -> Reader r a
  pure a = Reader (const a)

  (<*>) :: Reader r (a -> b) -> Reader r a -> Reader r b
  Reader f <*> Reader a = Reader $ \r -> (f r) (a r)

instance Monad (Reader r) where
  (>>=) :: Reader r a -> (a -> Reader r b) -> Reader r b
  Reader a >>= f = Reader $ \r -> runReader (f $ a r) r

ask :: Reader r r
ask = Reader id
{% endhighlight %}
</div>
</details>
</div>
</details>
<p />

### Writer

`Writer` is a bit less common, but has its uses. You can think of `Writer w a`,
a value `a` in the monad `Writer w`, as a computation that produces the desired
`a` value alongside some additional information `w`. In short: `(a, w)`. This
can be used to collect information, such as debug logs or annotations, without
having to do any manual bookkeeping.

In practice, `Writer` provides us with a few functions, including, most importantly:

{% highlight haskell %}
tell :: Monoid w => w -> Writer w ()
{% endhighlight %}

That is: given some piece of information `w`, append it to the end of the
already collected information. We need the `Monoid` constraint because we don't
want to restrict the information in the `Writer` to any kind of structure, like
a list: they can be anything that has a default empty value (`mempty`) and a
concatenation operation (`mappend`); this include all kinds of containers, like
`Seq Text` in our example, but also more specific monoids like `First` and
`Last`.

In our calculator example, if we didn't use `Either` for error handling, if we
decided to not handle errors, we could use `Writer` to handle our text output:

{% highlight haskell %}
evaluate
  :: AppConfig
  -> Variables
  -> Expression
  -> Writer (Seq Text) Int
evaluate appConfig variables expression = case expression of
  Multiplication lhs rhs -> do
    lhsValue <- evaluate appConfig variables lhs
    rhsValue <- evaluate appConfig variables rhs
    let result = lhsValue * rhsValue
    when (debugMode appConfig) $
      tell $ Seq.singleton $ Text.pack $
        printf ": %d * %d = %d" lhsValue rhsValue result
    pure result
  Division lhs rhs ->
    lhsValue <- evaluate appConfig variables lhs
    rhsValue <- evaluate appConfig variables rhs
    when (rhsValue == 0) $
      -- we are no longer do error handling, so we panic
      error "division by zero"
    let result = lhsValue `div` rhsValue
    when (debugMode appConfig) $
      tell $ Seq.singleton $ Text.pack $
        printf ": %d / %d = %d" lhsValue rhsValue result
    pure result
  _ -> error "TODO"
{% endhighlight %}

While we lost the ability to do error handling with `Either`, this `do` block
being in the `Writer` monad means we no longer have to manually collect debug
text lines and concatenate them: this is handled for us by the monad. If we want
to output a log line, we just `tell` that log line. `Seq` is a monoid, so we
`tell` a new sequence, and it gets concatenated to the existing sequence of
logs.

<details>
<summary><h4>Exercise 4</h4></summary>
<div markdown="1" class="exercise">
Here's a simplified implementation of `Writer`:

{% highlight haskell %}
newtype Writer w a = Writer { runWriter :: (w, a) }
{% endhighlight %}

Implement `Functor`, `Applicative`, `Monad`, and `tell`:

{% highlight haskell %}
instance Functor (Writer w) where
  fmap :: (a -> b) -> Writer w a -> Writer w b
  fmap = undefined -- TODO

instance Monoid w => Applicative (Writer w) where
  pure :: a -> Writer w a
  pure = undefined -- TODO

  (<*>) :: Writer w (a -> b) -> Writer w a -> Writer w b
  (<*>) = undefined -- TODO

instance Monoid w => Monad (Writer w) where
  (>>=) :: Writer w a -> (a -> Writer w b) -> Writer w b
  (>>=) = undefined -- TODO

tell :: Monoid w => w -> Writer w ()
tell = undefined -- TODO
{% endhighlight %}

<details>
<summary>Solution</summary>
<div markdown="1" class="solution">
{% highlight haskell %}
instance Functor (Writer w) where
  fmap :: (a -> b) -> Writer w a -> Writer w b
  fmap f (Writer (w, a)) = Writer (w, f a)

instance Monoid w => Applicative (Writer w) where
  pure :: a -> Writer w a
  pure a = Writer (mempty, a)

  (<*>) :: Writer w (a -> b) -> Writer w a -> Writer w b
  Writer (w1, f) <*> Writer (w2, a) = Writer (w1 <> w2, f a)

instance Monoid w => Monad (Writer w) where
  (>>=) :: Writer w a -> (a -> Writer w b) -> Writer w b
  Writer (w1, a) >>= f =
    let Writer (w2, b) = f a
    in  Writer (w1 <> w2, b)

tell :: Monoid w => w -> Writer w ()
tell w = Writer (w, ())
{% endhighlight %}

</div>
</details>
</div>
</details>
<p />

### State

Last but certainly not least, `State`. As the name suggests, `State s` handles
some state `s` for us. You can think of `State s a` as a value `a` that has
access to and can modify a state `s`. Something like `s -> (s, a)`: a function
that takes the previous state, and returns the result of the computation
alongside the new state.

State provides a few functions to access and modify the state:

{% highlight haskell %}
get    :: State s s
put    :: s -> State s ()
modify :: (s -> s) -> State s ()
{% endhighlight %}

`get` does something similar to `ask`: it retrieves the inner state value, `put`
replaces the state with the new provided value, and `modify` transforms the
existing state by applying the provided function (by doing a `get` then a
`put`).

For a slightly contrived example, we can imagine adding caching to a recursive
fibonacci function using `State`:

{% highlight haskell %}
-- naive fibonacci (no caching)
fibo :: Int -> Int
fibo 0 = 0
fibo 1 = 1
fibo n = fibo (n-1) + fibo (n-2)

-- with manual caching using a hashmap
fibo :: Int -> Int
fibo n = snd $ go n HashMap.empty
  where
    go
      :: Int
      -> HashMap Int Int
      -> (HashMap Int Int, Int)
    go 0 cache0 = (cache0, 0)
    go 1 cache0 = (cache0, 1)
    go n cache0 =
      case HashMap.lookup n cache0 of
        -- found the value in the cache
        Just result -> (cache0, result)
        -- did not find the value in the cache
        Nothing ->
          let
            -- compute the result recursively
            (cache1, nm1) = go (n-1) cache0
            (cache2, nm2) = go (n-2) cache1
            result = nm1 + nm2
          in
            -- return the new cache
            (HashMap.insert n result cache2, result)

-- with caching using State
fibo :: Int -> Int
fibo n = snd $ runState (go n) HashMap.empty
  where
    go :: Int -> State (HashMap Int Int) Int
    go 0 = pure 0
    go 1 = pure 1
    go n = do
      -- retrieve cache from state
      cache <- get
      case HashMap.lookup n cache of
        -- found the value in the cache
        Just result -> pure result
        -- did not find the value in the cache
        Nothing -> do
          -- compute the result recursively
          nm1 <- go (n-1)
          nm2 <- go (n-2)
          let result = nm1 + nm2
          -- modify the cache
          modify $ HashMap.insert n result
          pure result
{% endhighlight %}

As you can notice, thanks to `State`, we don't have to manually pass the cache
around, which reduces the risk of passing the wrong state (such as passing
`cache0` to `go (n-2)`).

In our calculator example, we could use `State` to store the variables, instead
of having `execute` take a hashmap and return a hashmap, like we currently do.

<details>
<summary><h4>Exercise 5</h4></summary>
<div markdown="1" class="exercise">
Here's a simplified implementation of `State`:

{% highlight haskell %}
newtype State s a = State { runState :: s -> (s, a) }
{% endhighlight %}

Implement `Functor`, `Applicative`, `Monad`, `get`, `put`, and `modify`:

{% highlight haskell %}
instance Functor (State s) where
  fmap :: (a -> b) -> State s a -> State s b
  fmap = undefined -- TODO

instance Applicative (State s) where
  pure :: a -> State s a
  pure = undefined -- TODO

  (<*>) :: State s (a -> b) -> State s a -> State s b
  (<*>) = undefined -- TODO

instance Monad (State s) where
  (>>=) :: State s a -> (a -> State s b) -> State s b
  (>>=) = undefined -- TODO

get :: State s s
get = undefined -- TODO

put :: s -> State s ()
put = undefined -- TODO

modify :: (s -> s) -> State s ()
modify = undefined -- TODO
{% endhighlight %}

<details>
<summary>Solution</summary>
<div markdown="1" class="solution">
{% highlight haskell %}
instance Functor (State s) where
  fmap :: (a -> b) -> State s a -> State s b
  fmap f (State ma) = State $ \s0 ->
    let (s1, a) = ma s0
    in  (s1, f a)

instance Applicative (State s) where
  pure :: a -> State s a
  pure a = State $ \s0 -> (s0, a)

  (<*>) :: State s (a -> b) -> State s a -> State s b
  State mf <*> State ma = State $ \s0 ->
    let
      (s1, f) = mf s0
      (s2, a) = ma s1
    in
      (s2, f a)

instance Monad (State s) where
  (>>=) :: State s a -> (a -> State s b) -> State s b
  State ma >>= f = State $ \s0 ->
    let
      (s1, a) = ma s0
    in
      runState (f a) s1

get :: State s s
get = State $ \s -> (s, s)

put :: s -> State s ()
put s = State $ const (s, ())

modify :: (s -> s) -> State s ()
modify f = do
  s <- get
  put $ f s
{% endhighlight %}

</div>
</details>
</div>
</details>
<p />

### Limitation

We've seen how the `Reader`, `Writer`, `State`, and `Either` monads can help us
structure our code: each provides a unique "capability" that makes our code
simpler, by moving all the tedious chaining to the background. There is,
however, a catch: a `do` block is in one specific monad. It's in `State`, or
it's in `Either`... So, it looks like we have to choose which monad we are
using, which capability we really need, and manually deal with everything else
manually, right?

## Composition

Of course, no, we don't have to choose: there are ways for us to create one big
monad that combines all of the capabilities of the monads we have already seen,
allowing us to use all of them at once.

### Amalgam

One approach is to create our own monad, that matches exactly our
needs. Something like this:

{% highlight haskell %}
newtype AppMonad a = AppMonad (
  AppConfig -> Variables -> Either Text (Variables, Seq Text, a)
)
{% endhighlight %}

This would solve our needs, but would require a lot of code: we would need to
reimplement `ask`, `tell`, `get`, `modify`... And we would also need to write
our own instance of `Monad`, which, for this type, would look like this:

{% highlight haskell %}
instance Monad AppMonad where
  AppMonad ma >>= f = AppMonad $ \appConfig variables0 ->
    case ma appConfig variables0 of
      Left errorMsg -> Left errorMsg
      Right (variables1, output1, a) ->
        let AppMonad mb = f a in
          case mb appConfig variables1 of
            Left errorMsg -> Left errorMsg
            Right (variables2, output2, b) ->
              (variables2, output1 <> output2, b)
{% endhighlight %}

This approach works, and is better than what we had before: all the complexity
is in one place, this implementation of `>>=`, and the rest of the code can be
built in terms of `AppMonad`. But it is a bit rigid, and requires a lot of
manual code. Thankfully, there's an even more elegant solution: monad
transformers.

### Transformers

Monad transformers are building blocks, that we can use to create new
monads. Their implementation details do not belong in this post but in an
hypothetical part 2, so we'll only cover the basics here. The gist of the idea
is this: a monad transformer "transforms" a base monad by adding its capability
on top of it, creating a new monad that combines them. It is possible to stack
several of them this way, creating more and more complex monads as the stack
grows. Many monads define a transformer variant, commonly denoted by a `T`
suffix: `StateT`, `ReaderT`, and so on. In fact, combining `Reader`, `Writer`,
and `State` is common enough that there's already a monad that combines all
three of them, simply called
[`RWS`](https://hackage-content.haskell.org/package/mtl-2.3.2/docs/Control-Monad-RWS-Lazy.html)
(or `RWST` for its transformer version).

This means that instead of defining our `AppMonad` manually, we can define it by
combining all the monads we have seen so far:

{% highlight haskell %}
type AppMonad =
  -- the reader capability, with our app config, on top of
  ReaderT AppConfig (
    -- the writer capability, for our logs, on top of
    WriterT (Seq Text) (
      -- the state capability, for our variables, on top of
      StateT Variables (
         -- the either capability, for our errors
         Either Text
  )))
{% endhighlight %}

If you were to expand all those types one by one, using the simplified
implementation provided in the exercises, you'd obtain something extremely
similar to our custom amalgam:

{% highlight haskell %}
type AppMonad a
  =  Variables
  -> AppConfig
  -> Either Text (Variables, (Seq Text, a))
{% endhighlight %}

And thanks to some implementation details that we won't get into, our resulting
`AppMonad` automatically has *all of the combined capabilities* of its
individual parts, and is already a monad by construction. It means we don't have
to implement `>>=`, we can use `ask` to retrieve the `AppConfig` without passing
it around manually, we can `modify` the variables without passing them around
manually, we can `tell` a debug log line without doing any concatenation, and we
can even `throwError` to short-circuit with a `Left` value whenever we need!

### Putting it all together

We can now put everything we've seen together, and finally write versions of
`execute` and `evaluate` that are simple and readable:

{% highlight haskell %}
evaluate :: Expression -> AppMonad Int
evaluate expression = case expression of
  Multiplication lhs rhs -> do
    lhsValue <- evaluate lhs
    rhsValue <- evaluate rhs
    let
      result  = lhsValue * rhsValue
      logLine = printf ": %d * %d = %d" lhsValue rhsValue result
    debugLog logLine
    pure result
  Division lhs rhs -> do
    lhsValue <- evaluate lhs
    rhsValue <- evaluate rhs
    when (rhsValue == 0) $
      throwError "division by zero"
    let
      result  = lhsValue `div` rhsValue
      logLine = printf ": %d / %d = %d" lhsValue rhsValue result
    debugLog logLine
    pure result
  _ -> error "TODO"
  where
    debugLog :: String -> AppMonad ()
    debugLog line = do
      appConfig <- ask
      when (debugMode appConfig) $
        tell $ Seq.singleton $ Text.pack line

execute :: Statement -> AppMonad ()
execute statement = case statement of
  SetVariable name expression -> do
    value <- evaluate expression
    modify $ HashMap.insert name value
  ComputeExpression expression -> do
    value <- evaluate expression
    tell $ Seq.singleton $ Text.pack $ show value
{% endhighlight %}

And I hope that this last example convinces you of the usefulness and beauty of
this monadic structure. Look at our recursive calls to `evaluate`: they only
take one argument! No manual bookkeeping whatsoever. The `AppConfig` is
implicitly made available to anyone who `ask`s (like the `debugLog` helper
function), debug logs are concatenated for us without needing to do more than
just `tell`ing what we want to output, and all short-circuiting on error is
handled for us by `Either`.

Finally, dear reader, one last exercise: draw the rest of the owl! :3

<details>
<summary><h4>Exercise 6</h4></summary>
<div markdown="1" class="exercise">
Implement all the missing parts of `evaluate`! Each `undefined` will cause a
panic and needs to be replaced with the correct implementation.

{% highlight haskell %}
evaluate :: Expression -> AppMonad Int
evaluate expression = case expression of
  Literal lit -> do
    undefined
  Variable varName -> do
    variables <- undefined
    case undefined of
      Nothing ->
        throwError $ "variable not found: " <> varName
      Just value -> do
        undefined
  Addition lhs rhs -> do
    undefined
  Subtraction lhs rhs -> do
    undefined
  Multiplication lhs rhs -> do
    lhsValue <- evaluate lhs
    rhsValue <- evaluate rhs
    let
      result  = lhsValue * rhsValue
      logLine = printf ": %d * %d = %d" lhsValue rhsValue result
    debugLog logLine
    pure result
  Division lhs rhs -> do
    lhsValue <- evaluate lhs
    rhsValue <- evaluate rhs
    when (rhsValue == 0) $
      throwError "division by zero"
    let
      result  = lhsValue `div` rhsValue
      logLine = printf ": %d / %d = %d" lhsValue rhsValue result
    debugLog logLine
    pure result
  Modulo lhs rhs -> do
    undefined
  where
    debugLog :: String -> AppMonad ()
    debugLog line = do
      config <- ask
      when (debugMode config) $
        tell $ Seq.singleton $ Text.pack line
{% endhighlight %}

<details>
<summary>Solution</summary>
<div markdown="1" class="solution">
{% highlight haskell %}
evaluate :: Expression -> AppMonad Int
evaluate expression = case expression of
  Literal lit ->
    pure lit
  Variable varName -> do
    variables <- get
    case HashMap.lookup varName variables of
      Nothing ->
        throwError $ "variable not found: " <> varName
      Just value -> do
        debugLog $ printf ": %s = %d" varName value
        pure value
  Addition lhs rhs -> do
    lhsValue <- evaluate lhs
    rhsValue <- evaluate rhs
    let
      result  = lhsValue + rhsValue
      logLine = printf ": %d + %d = %d" lhsValue rhsValue result
    debugLog logLine
    pure result
  Subtraction lhs rhs -> do
    lhsValue <- evaluate lhs
    rhsValue <- evaluate rhs
    let
      result  = lhsValue - rhsValue
      logLine = printf ": %d - %d = %d" lhsValue rhsValue result
    debugLog logLine
    pure result
  Multiplication lhs rhs -> do
    lhsValue <- evaluate lhs
    rhsValue <- evaluate rhs
    let
      result  = lhsValue * rhsValue
      logLine = printf ": %d * %d = %d" lhsValue rhsValue result
    debugLog logLine
    pure result
  Division lhs rhs -> do
    lhsValue <- evaluate lhs
    rhsValue <- evaluate rhs
    when (rhsValue == 0) $
      throwError "division by zero"
    let
      result  = lhsValue `div` rhsValue
      logLine = printf ": %d / %d = %d" lhsValue rhsValue result
    debugLog logLine
    pure result
  Modulo lhs rhs -> do
    lhsValue <- evaluate lhs
    rhsValue <- evaluate rhs
    when (rhsValue == 0) $
      throwError "division by zero"
    let
      result  = lhsValue `div` rhsValue
      logLine = printf ": %d % %d = %d" lhsValue rhsValue result
    debugLog logLine
    pure result
  where
    debugLog :: String -> AppMonad ()
    debugLog line = do
      config <- ask
      when (debugMode config) $
        tell $ Seq.singleton $ Text.pack line
{% endhighlight %}

</div>
</details>
</div>
</details>

## Conclusion

I really hope this example highlights the practical aspect of monads: how we can
use them to structure our code, how each of them provides a "capability", and
how we can compose them to get all of their benefits at once. Obviously, this
post glosses over many details: we don't explain how monad transformers actually
work, we don't cover the use of typeclasses for genericity of capabilities in
monadic code, we don't cover some of the drawbacks and trade-offs (such as
performance concerns), we don't mention the problem of stack ordering... There's
still some ground to cover: this is just the start of the journey!

But I hope this was useful nonetheless! :)

You can find the full code for this trivial calculator [on
GitHub](https://gist.github.com/nicuveo/af683137a8ad29c59339ab8145a87687). Additionally,
I'd like to thank [Jack Kelly](http://jackkelly.name) for his in-depth review of
this post!
