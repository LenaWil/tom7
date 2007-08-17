
signature ASTARG =
sig

  type var
  val var_eq : var * var -> bool
  val var_cmp : var * var -> order
  val var_vary : var -> var

  (* can be anything. uninterpreted *)
  type leaf
  val leaf_cmp : leaf * leaf -> order

  (* layouts? *)

end

signature AST =
sig

  (* from arg *)
  type var
  type leaf

  structure VM : ORD_MAP where type Key.ord_key = var

  datatype 'ast front =
    $ of leaf
    (* bind, bind list *)
  | \ of var * 'ast
  | B of var list * 'ast
    (* sequence, sequence list *)
  | / of 'ast * 'ast
  | S of 'ast list
  | V of var

  (* infixr \ / *)

  type ast
  (* arbitrary but consistent ordering, observing alpha equivalence *)
  val ast_cmp : ast * ast -> order
  (* XXX also fast eq? *)

  val look   : ast -> ast front
  val look2  : ast -> ast front front
  val look3  : ast -> ast front front front
  val look4  : ast -> ast front front front front
  val look5  : ast -> ast front front front front front

  val hide   : ast front -> ast

  (* substitute [ast/var] ast.
     this is "cheap" *)
  val sub : ast -> var -> ast -> ast
    
  (* number of occurrences for each var.
     these are constant time. *)
  val freevars : ast -> int VM.map
  val isfree   : ast -> var -> bool

  (* injective constructors *)
  val $$ : leaf -> ast
  val \\ : var * ast -> ast
  val // : ast * ast -> ast
  val SS : ast list -> ast
  val BB : var list * ast -> ast
  val VV : var -> ast

end
