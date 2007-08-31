(* This version of the AST uses de Bruijn indices
   to represent bound variables. Free variables are
   still represented by name. *)

(* TODO: de Bruijn
         use vectors instead of lists?
         hash cons?
         hash for quick equality tests 
         delayed substitutions

         compliance suite for this; it is surprisingly easy
         to make mistakes (esp. with delayed free variable
         sets, etc.). *)

functor ASTFn(A : ASTARG) :> AST where type var  = A.var
                                   and type leaf = A.leaf =
struct
  open A

  fun I x = x
  fun K x y = x
  infixr 9 `
  fun a ` b = a b

  structure VM = SplayMapFn(type ord_key = var
                            val compare = var_cmp)

  datatype 'ast front =
    $ of leaf
    (* bind, bind list *)
  | \ of var * 'ast
  | B of var list * 'ast
    (* sequence, sequence list *)
  | / of 'ast * 'ast
  | S of 'ast list
  | V of var

  infixr / \

  (* exception AST of string *)
  val AST = Exn

  val ltov = Vector.fromList
  fun vtol v = Vector.foldr op:: nil v

  datatype term =
      Leaf of leaf
      (* if bool is true, then the vector contains
         a single element.
         the variables in the vector are only for
         the purpose of creating new named variables
         with the same base name as the original lams;
         it is the length of the vector that determines
         the number of nameless de Bruinj bindings. *)
    | Lam of bool * var vector * term
      (* if boolean is true, then the vector contains
         exactly two terms. *)
    | Agg of bool * term vector
    | Var of var
    | Subst of term vector * int * term
      (* 0-based, non-negative *)
    | Index of int

  fun hide (V v) = Var v
    | hide ($ l) = Leaf l
    | hide (a1 / a2) = Agg (true, ltov [a1, a2])
    | hide (S al) = Agg (false, ltov al)
    | hide (v \ a) = Lam (true, ltov [v], bind 0 [v] a)
    | hide (B (vl, a)) = Lam (false, ltov vl, bind 0 (rev vl) a)

  (* find named variables in 'vars'. replace them with de bruinj
     indices, assuming we are at given depth. The variables should
     appear in such that the first variable in the list is the
     innermost bound. *)
  and bind depth vars tm =
    (case tm of
       Leaf _ => tm
     | Index _ => tm
     | Agg (b, v) => Agg (b, Vector.map (bind depth vars) v)
     | Lam (b, vs, a) => Lam (b, vs, bind (depth + Vector.length vs) vars a)
     | Subst (tv, sh, t) => Subst (Vector.map (bind depth vars) tv,
                                   sh,
                                   bind depth vars t)
     | Var v =>
         let
           fun rep _ nil = Var v
             | rep n (vv :: rest) = if var_eq (v, vv)
                                    then Index n
                                    else rep (n + 1) rest
         in
           rep depth vars
         end)

  (* apply the substitution (tv,sh) to t one level.
     sh is the shift, meaning that any variable less than
     this gets the identity substitution. *)
  fun push tv sh t =
    (case t of
       (* this is probably possible *)
       Subst _ => raise Exn "subst hit subst?"
     | Index i => if i <= sh
                  then t
                  else Vector.sub(tv, i - sh)
     | Var _ => t
     | Leaf _ => t
     | Agg (b, v) => Agg (b, Vector.map (fn tm => Subst(tv, sh, tm)) v)
     (* shifts the substitution up in the body of the lambda, as
        well as within the substituted terms. *)
     | Lam (b, vs, t) => Lam (b, vs, Subst(Vector.map (fn tm => tv, 
                                           sh + Vector.length vs,
                                           t))
         )

  fun looky self tm =
    (case tm of
       Leaf l => $l
     | Var v => V v
     | Index _ => raise Exn "bug: looked at index!"
     | Agg (true, v)  =>
         let val a = Vector.sub(v, 0)
             val b = Vector.sub(v, 1)
         in
           self a / self b
         end
     | Agg (false, v) => S (map (vtol (self v)))
     | Subst (tv, sh, t) => looky self (push tv sh t)
)

  type ast = term

  fun ast_cmp _ = raise Exn "unimplemented"
  fun sub _ = raise Exn "unimplemented"
  fun freevars _ = raise Exn "unimplemented"
  fun count _ = raise Exn "unimplemented"
  fun isfree _ = raise Exn "unimplemented"
  fun looky self _ = raise Exn "unimplemented"

(*
  fun looky self (A { m = _, f }) = 
    (case f of
       $l => $l
     | V v => V v
     | a1 / a2 => self a1 / self a2
     | S al => S (map self al)
     | v \ a =>
       let val v' = var_vary v
           val a = rename [(v, v')] a
       in v' \ self a
       end
     | B (vl, a) =>
       let val subst = ListUtil.mapto var_vary vl
           val a = rename subst a
       in
         B (map #2 subst, self a)
       end)
*)
       
(*
  and astl_cmp (nil, nil) = EQUAL
    | astl_cmp (nil, _ :: _) = LESS
    | astl_cmp (_ :: _, nil) = GREATER
    | astl_cmp (h1 :: t1, h2 :: t2) =
       (case ast_cmp (h1, h2) of
          LESS => LESS
        | GREATER => GREATER
        | EQUAL => astl_cmp (t1, t2))
*)       

  fun look ast = looky I ast
  fun look2 ast = looky look ast
  fun look3 ast = looky look2 ast
  fun look4 ast = looky look3 ast
  fun look5 ast = looky look4 ast

  val $$ = hide o $
  val \\ = hide o op \
  val // = hide o op /
  val SS = hide o S
  val BB = hide o B
  val VV = hide o V

end
