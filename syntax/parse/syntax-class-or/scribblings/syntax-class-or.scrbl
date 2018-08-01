#lang scribble/manual

@(require scribble/example
          (for-label racket
                     syntax/parse
                     syntax/parse/experimental/reflect
                     syntax/parse/syntax-class-or))

@(define (make-ev)
   (define ev (make-base-eval))
   (ev '(require racket
                 syntax/parse
                 syntax/parse/experimental/reflect
                 syntax/parse/syntax-class-or))
   ev)

@title{Combining syntax classes together as multiple variants}

@defmodule[syntax/parse/syntax-class-or]

@defform[(define-syntax-class/or* head
           #:attributes [attr-arity-decl ...]
           reified-classes-expr)
         #:grammar
         ([head name-id
                (name-id parameters)]
          [parameters (code:line parameter ...)
                      (code:line parameter ... @#,racketparenfont{.} rest-id)]
          [parameter (code:line param-id)
                     (code:line [param-id default-expr])
                     (code:line #:keyword param-id)
                     (code:line #:keyword [param-id default-expr])]
          [attr-arity-decl attr-name-id
                           [attr-name-id depth]])
         #:contracts
         ([reified-classes-expr (listof reified-syntax-class?)])]{
Normally, there needs to be one syntax-class containing
all the variants, in one centralized place. Even when you
divide the the work into helper syntax classes, you're
limited to the variants that were already written that
the parsing can depend on. The number of variants is
limited by the syntax at compile time.

The syntax-parse reflection interface (@racket[~reflect]) allows
you to fill in a syntax class at runtime, which lets you
leave a variant to be filled in from somewhere else.
However, the @racket[~reflect] pattern only allows one syntax
class, and that syntax class must include all the
non-built-in variants, still limiting it to what some
centralized parser can depend on. And still the number of
new variants is limited to fixed number at compile time.

The @racket[define-syntax-class/or*] form allows you to define
a syntax class that combines a list of arbitrarily many
variants into one parser. The list of variants can be
computed at run time (relative to the parser) or can be
passed in as arguments.

@examples[
  #:eval (make-ev)
  #:escape UNEXAMPLES
  (require syntax/parse
           syntax/parse/experimental/reflect
           syntax/parse/syntax-class-or)
  (define-syntax-class addition
    #:datum-literals [+]
    [pattern [{~and a {~not +}} ... {~seq + {~and b {~not +}} ...} ...+]
      #:with op #'+
      #:with [sub ...] #'[[a ...] [b ...] ...]])
  (define-syntax-class multiplication
    #:datum-literals [*]
    [pattern [{~and a {~not *}} ... {~seq * {~and b {~not *}} ...} ...+]
      #:with op #'*
      #:with [sub ...] #'[[a ...] [b ...] ...]])
  (define-syntax-class exponentiation
    #:datum-literals [^]
    [pattern [{~and a {~not ^}} ... ^ b ...]
      #:with op #'expt
      #:with [sub ...] #'[[a ...] [b ...]]])

  (define-syntax-class/or* infix
    #:attributes [op [sub 1]]
    (list (reify-syntax-class addition)
          (reify-syntax-class multiplication)
          (reify-syntax-class exponentiation)))
  (define (parse stx)
    (syntax-parse stx
      [e:infix #`(e.op #,@(map parse (attribute e.sub)))]
      [[a] #'a]))
  (parse #'[x])
  (parse #'[a * x ^ 2 + b * x + c])
  (parse #'[a ^ b * c + 2 * d + 3])
  (parse #'[2 ^ 10 ^ x + -1 * y])
]}
