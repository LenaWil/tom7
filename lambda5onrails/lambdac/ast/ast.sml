functor ASTFn(A : ASTARG) :> AST where type var = A.var
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

  exception AST of string

  (* First attempt. Just counting free vars. 
     invariant: the integer is strictly positive
     *)
  datatype ast =
    A of { m : unit -> (int VM.map),
           f : ast front }

  fun empty () = VM.empty

  fun sum l = foldr (VM.unionWith op+) VM.empty l

  (* memoize a unit -> 'a function so that it is only
     run the first time it is called. *)
  fun memoize f =
    let
      val r = ref NONE
    in
      (fn () =>
       case !r of
         NONE =>
           let val x = f ()
           in
             r := SOME x;
             x
           end
       | SOME x => x)
    end

  fun force f = f ()
  fun getmap (A { m, ... }) = m
  (* remove, even if it is not present *)
  fun remove v m = #1 (VM.remove (m, v)) handle _ => m

  fun hide ($ l) = A { m = empty,
                       f = $ l }
    | hide (V v) = A { m = K (VM.insert(VM.empty, v, 1)),
                       f = V v }
    | hide (S al) = A { m = memoize (fn () =>
                                     let val ms = map (force o getmap) al
                                     in sum ms
                                     end),
                        f = S al }
    | hide (a1 / a2) = A { m = memoize (fn () => sum [force ` getmap a1, force ` getmap a2]),
                           f = a1 / a2 }
    | hide (v \ a) = A { m = memoize (fn () => remove v (force ` getmap a)),
                         f = v \ a }
    | hide (B (vl, a)) = A { m = memoize (fn () => foldr (fn (v, m) => remove v m) (force ` getmap a) vl),
                             f = B (vl, a) }


  fun freevars (A { m, ... }) = force m

  fun isfree ast v =
    case VM.find(freevars ast, v) of
      NONE => false
    | SOME x => true

  (* PERF should delay substitutions and renamings. *)
  fun rename nil ast = ast
    | rename ((v,v') :: t) ast =
    let val ast = sub (hide ` V v') v ast
    in rename t ast
    end

  and sub obj v (ast as A { m, f }) =
    (* get out early *)
    if isfree ast v
    then 
      (* use precomputed freevar sets. *)
      let 
        val m = remove v (force m)
        val m = fn () => m
      in
        case f of
          $l => ast (* empty map *)
        | V v' => if var_eq (v, v')
                  then obj
                  else ast (* map didn't change *)
        | a1 / a2 => A { m = m,
                         f = sub obj v a1 / sub obj v a2 }
        | v' \ a => (* PERF can avoid renaming if v' doesn't appear in obj... *)
                    let val v'' = var_vary v'
                        val a = rename [(v, v'')] a
                    in
                      A { m = m,
                          f = v' \ sub obj v a }
                    end
        | S al => A { m = m,
                      f = S ` map (sub obj v) al }
        | B (vl, a) =>
                  let
                    (* PERF as above can avoid rename *)
                    val subst = ListUtil.mapto var_vary vl
                    val a = rename subst a
                  in
                    A { m = m,
                        f = B (map #2 subst, a) }
                  end
      end
    else ast

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

  fun ast_cmp (a1, a2) = raise AST "unimplemented"

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
