(* This version of the AST uses de Bruijn indices
   to represent bound variables. Free variables are
   still represented by name. 

   We bias the representation to make 'looking' at
   a term more efficient than creating a term. *)

(* TODO: de Bruijn
         use vectors instead of lists?
         hash cons?
         hash for quick equality tests 
         delayed substitutions

         compliance suite for this; it is surprisingly easy
         to make mistakes (esp. with delayed free variable
         sets, etc.). *)

functor AST1(A : ASTARG) (* : (* XXX :> *) AST_BASE where type var  = A.var
                                                   and type leaf = A.leaf = *)
 =
struct
  open A

  fun I x = x
  fun K x y = x
  infixr 9 `
  fun a ` b = a b

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
    | Subst of subst * term
      (* 0-based, non-negative *)
    | Index of int

  (* A substitution consists of two operations to be carried out on a de
     Bruin index.

     If the index is less than 'skip', it is unaffectd. When we push a
     substitution into a binder, we increment its skip, since it
     cannot have any effect on that bound variable. (If it is not less
     than skip, we subtract skip from it before indexing into the
     vector. Otherwise, the first skip elements of the replacement
     vector are always wasted.)

     This subtracted index is either in the domain of the
     substitution, or too high (larger than or equal to the length of
     the vector). If it is too high we return the index plus 'up'. (Up
     is always at least as large as the length of the vector.) When a
     substitution is pushed under a binder, we apply to its codomain a
     new substitution 'up' because any de Bruin indices in there now
     look past the binder we've just pushed it under.

     Otherwise, we simply select the element from the substitution
     vector. The vector [t0, t1, t2 ... tn] is taken to mean t0/0,
     t1/1, t2/2 ... tn/n and the identity for any other index. *)

  withtype subst = { r  : term vector,
                     up : int,
                     skip : int }


  fun hide (V v) = Var v
    | hide ($ l) = Leaf l
    | hide (a1 / a2) = Agg (true, ltov [a1, a2])
    | hide (S al) = Agg (false, ltov al)
    | hide (v \ a) = Lam (true, ltov [v], bind 0 [v] a)
    | hide (B (vl, a)) = Lam (false, ltov vl, bind 0 (rev vl) a)

  (* find named variables in 'vars'. replace them with de bruinj
     indices, assuming we are at given depth. The variables should
     appear in such that the first variable in the list is the
     innermost bound. We do this eagerly, since our delayed
     substitutions can only substitute for de Bruinj variables. *)
  and bind depth vars tm =
    (case tm of
       Leaf _ => tm
     | Index _ => tm
     | Agg (b, v) => Agg (b, Vector.map (bind depth vars) v)
     | Lam (b, vs, a) => Lam (b, vs, bind (depth + Vector.length vs) vars a)
(* simpler to just push the substitution,
   especially since we are doing a linear traversal. 
     | Subst ({ r, up, skip }, t) => 
         Subst ({ (* still at the same scope -- right? *)
                  r = Vector.map (bind depth vars) tv,
                  up = up,
                  skip = skip },
                bind depth vars t)
*)
     | Subst (s, t) => bind depth vars (push s t)
     | Var v =>
         let
           fun rep _ nil = Var v
             | rep n (vv :: rest) = if var_eq (v, vv)
                                    then Index n
                                    else rep (n + 1) rest
         in
           rep depth vars
         end)

  (* apply the substitution s to t one level. *)
  and push (s as { r, up, skip }) t =
    (case t of
       Subst (ss, tt) => 
         let in
           (* PERF the whole point of doing it this
              way is that we can compose substitutions!
              this way makes linear chains of pushes... *)
           (* print "subst hit subst\n"; *)
           push s (push ss tt)
         end
     | Index i => if i < skip
                  then t
                  else let val i = i - skip
                       in
                         if i >= Vector.length r
                         then Index (i + up)
                         else Vector.sub(r, i)
                       end
     | Var _ => t
     | Leaf _ => t
     | Agg (b, v) => Agg (b, Vector.map (fn tm => Subst(s, tm)) v)
     (* shifts the substitution up in the body of the lambda, as
        well as within the substituted terms. *)
     | Lam (b, vs, t) => Lam (b, vs, 
                              Subst( { (* increment the codomain *)
                                       r = Vector.map (fn tm =>
                                                       Subst ({ r = Vector.fromList nil,
                                                                up = Vector.length vs,
                                                                skip = 0 },
                                                              tm)) r,
                                       (* maintain the same initial shift ? *)
                                       up = up,
                                       (* ignore the lowest bindings *)
                                       skip = skip + Vector.length vs }, t))
         )

  fun looky self tm =
    (case tm of
       Leaf l => $l
     | Var v => V v
     | Index _ => raise Exn "bug: looked at index!"
     | Lam (b, vs, t) =>
         let 
           val vs = Vector.map var_vary vs
           val vsub = Vector.map Var vs
         in
           if b
           then (Vector.sub (vs, 0) \ self ` Subst ( { r = vsub, up = 0, skip = 0 }, t ))
           else B (vtol vs, self ` Subst( { r = vsub, up = 0, skip = 0 }, t))
         end
     | Agg (true, v)  =>
         let val a = Vector.sub(v, 0)
             val b = Vector.sub(v, 1)
         in
           self a / self b
         end
     | Agg (false, v) => S (map self (vtol v))
     | Subst (s, t) => looky self (push s t))

  type ast = term
(*
  fun ast_cmp _ = raise Exn "unimplemented"
  fun sub _ = raise Exn "unimplemented"
  fun freevars _ = raise Exn "unimplemented"
  fun count _ = raise Exn "unimplemented"
  fun isfree _ = raise Exn "unimplemented"
  fun looky self _ = raise Exn "unimplemented"
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

functor ASTFn(A : ASTARG) : (* XXX :> *) AST where type var  = A.var
                                               and type leaf = A.leaf =
struct
  structure B = AST1(A)
  structure C = FreeAST(structure A = A
                        structure B = B)

  open C
  open B
end
