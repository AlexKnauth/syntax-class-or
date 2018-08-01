# syntax-class-or

Combining a list of variants into one syntax class.

```racket
(require syntax/parse/syntax-class-or)
```

```racket
(define-syntax-class/or* head
  #:attributes [attr-arity-decl ...]
  reified-classes-expr)

        head = name-id
             | (name-id parameters)
  parameters = parameter ...
             | parameter ... . rest-id
   parameter = param-id
             | [param-id default-expr]
             | #:keyword param-id
             | #:keyword [param-id default-expr]
```

Normally, there needs to be one syntax-class containing
all the variants, in one centralized place. Even when you
divide the the work into helper syntax classes, you're
limited to the variants that were already written that
the parsing can depend on. The number of variants is
limited by the syntax at compile time.

The syntax-parse reflection interface (`~reflect`) allows
you to fill in a syntax class at runtime, which lets you
leave a variant to be filled in from somewhere else.
However, the `~reflect` pattern only allows one syntax
class, and that syntax class must include all the
non-built-in variants, still limiting it to what some
centralized parser can depend on. And still the number of
new variants is limited to fixed number at compile time.

The `define-syntax-class/or*` form allows you to define
a syntax class that combines a list of arbitrarily many
variants into one parser. The list of variants can be
computed at run time (relative to the parser) or can be
passed in as arguments.
