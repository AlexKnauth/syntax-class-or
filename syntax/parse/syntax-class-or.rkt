#lang racket/base

(provide define-syntax-class/or*)

(require racket/match
         syntax/parse
         syntax/parse/experimental/reflect
         syntax/parse/define)
(module+ test
  (require rackunit))

;; ---------------------------------------------------------

;; Combining A List of Variants into one Syntax Class

;; (define-syntax-class/or* head
;;   #:attributes [attr-arity-decl ...]
;;   reified-classes-expr)
;;       head = name-id
;;            | (name-id parameters)
;; parameters = parameter ...
;;            | parameter ... . rest-id
;;  parameter = param-id
;;            | [param-id default-expr]
;;            | #:keyword param-id
;;            | #:keyword [param-id default-expr]

;; Normally, there needs to be one syntax-class containing
;; all the variants, in one centralized place. Even when you
;; divide the the work into helper syntax classes, you're
;; limited to the variants that were already written that
;; the parsing can depend on. The number of variants is
;; limited by the syntax at compile time.

;; The syntax-parse reflection interface (`~reflect`) allows
;; you to fill in a syntax class at runtime, which lets you
;; leave a variant to be filled in from somewhere else.
;; However, the `~reflect` pattern only allows one syntax
;; class, and that syntax class must include all the
;; non-built-in variants, still limiting it to what some
;; centralized parser can depend on. And still the number of
;; new variants is limited to fixed number at compile time.

;; The `define-syntax-class/or*` form allows you to define
;; a syntax class that combines a list of arbitrarily many
;; variants into one parser. The list of variants can be
;; computed at run time (relative to the parser) or can be
;; passed in as arguments.

(define-simple-macro
  (define-syntax-class/or* {~and head {~or name:id
                                           (name:id . _)}}
    #:attributes [attr-decl ...]
    reified-classes:expr)
  (begin
    (define sc-nothing
      (let ()
        (define-syntax-class name #:attributes [attr-decl ...])
        (reify-syntax-class name)))
    (define (sc-or2 a b)
      (define-syntax-class name #:attributes [attr-decl ...]
        [pattern {~reflect || (a) #:attributes [attr-decl ...]}]
        [pattern {~reflect || (b) #:attributes [attr-decl ...]}])
      (reify-syntax-class name))
    (define (sc-or* classes)
      (match classes
        ['() sc-nothing]
        [(list a) a]
        [(list a b) (sc-or2 a b)]
        [(cons a bs) (sc-or2 a (sc-or* bs))]))
    (define-syntax-class head
      #:attributes [attr-decl ...]
      [pattern {~reflect || ((sc-or* reified-classes))
                         #:attributes [attr-decl ...]}])))

;; ---------------------------------------------------------

(module+ test
  (test-case "range"
    ;; A RangeSC is a syntax class with the attributes:
    ;;  * min         : [Maybe Syntax]
    ;;  * max         : [Maybe Syntax]
    ;;  * min-closed? : Bool
    ;;  * max-closed? : Bool

    (define-syntax-class/or* (rng rng-classes)
      #:attributes [min max min-closed? max-closed?]
      rng-classes)

    (define-syntax-class rng-lt
      #:datum-literals [< _]
      [pattern (min < _)
        #:attr max #f
        #:attr min-closed? #f
        #:attr max-closed? #f]
      [pattern (_ < max)
        #:attr min #f
        #:attr min-closed? #f
        #:attr max-closed? #f]
      [pattern (min < _ < max)
        #:attr min-closed? #f
        #:attr max-closed? #f])

    (define-syntax-class rng-le
      #:datum-literals [<= _]
      [pattern (min <= _)
        #:attr max #f
        #:attr min-closed? #t
        #:attr max-closed? #f]
      [pattern (_ <= max)
        #:attr min #f
        #:attr min-closed? #f
        #:attr max-closed? #t]
      [pattern (min <= _ <= max)
        #:attr min-closed? #t
        #:attr max-closed? #t])

    (define-syntax-class rng-lt-le
      #:datum-literals [< <= _]
      [pattern (min <= _ < max)
        #:attr min-closed? #t
        #:attr max-closed? #f]
      [pattern (min < _ <= max)
        #:attr min-closed? #f
        #:attr max-closed? #t])

    ;; The variants can be defined separately, reified into
    ;; values, and then passed in as a list.

    (define rng-syntax-classes
      (list (reify-syntax-class rng-lt)
            (reify-syntax-class rng-le)
            (reify-syntax-class rng-lt-le)))

    (define (f stx)
      (syntax-parse stx
        [{~var r (rng rng-syntax-classes)}
         (format "~a~a, ~a~a"
                 (if (attribute r.min-closed?) "[" "(")
                 (syntax-e (or (attribute r.min) #'"-∞"))
                 (syntax-e (or (attribute r.max) #'"+∞"))
                 (if (attribute r.max-closed?) "]" ")"))]))

    (check-equal? (f #'(1 < _)) "(1, +∞)")
    (check-equal? (f #'(2 <= _)) "[2, +∞)")
    (check-equal? (f #'(_ <= 3)) "(-∞, 3]")
    (check-equal? (f #'(_ < 10)) "(-∞, 10)")
    (check-equal? (f #'(4 <= _ < 9)) "[4, 9)")
    (check-equal? (f #'(5 < _ <= 8)) "(5, 8]")
    (check-equal? (f #'(6 <= _ <= 7)) "[6, 7]")
    (check-equal? (f #'(11 < _ < 88)) "(11, 88)")
    ))

