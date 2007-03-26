(* Very simple optimization pass that just drops unused, non-effectful bindings. *)
structure ILUnused :> ILUNUSED =
struct

  infixr 9 `
  fun a ` b = a b
  
  open IL
  structure V = Variable

  exception Unused of string

  (* just value vars. *)
  datatype fvset = F of { var : V.Set.set,
                          uvar : V.Set.set }

  val empty = F { var = V.Set.empty, uvar = V.Set.empty }

  fun --  (s as F { var, uvar }, v) = (F { var = V.Set.delete (var, v), uvar = uvar }) handle _ => s
  fun --- (s as F { var, uvar }, v) = (F { uvar = V.Set.delete (uvar, v), var = var }) handle _ => s
  fun ++  (s as F { var, uvar }, v) = (F { var = V.Set.add (var, v), uvar = uvar })
  fun +++ (s as F { var, uvar }, v) = (F { uvar = V.Set.add (uvar, v), var = var })
                                       
  fun ??  (s as F { var, uvar }, v) = V.Set.member (var, v)
  fun ??? (s as F { var, uvar }, v) = V.Set.member (uvar, v)

  fun ||  (F { var, uvar}, F { var = var2, uvar = uvar2 }) = F { var = V.Set.union (var, var2),
                                                                 uvar = V.Set.union (uvar, uvar2) }

  fun unionl l = foldl || empty l

  infix -- --- ++ +++ ?? ??? ||

  fun uval value =
    case value of
      Polyvar  { var, ... } => (empty ++ var, value)
    | Polyuvar { var, ... } => (empty +++ var, value)
    | Int _ => (empty, value)
    | String _ => (empty, value)
    | VRecord lvl => 
        let val (l, vl) = ListPair.unzip lvl
            val (fvl, vl) = ListPair.unzip ` map uval vl
        in
          (unionl fvl, VRecord ` ListPair.zip (l, vl))
        end
    | VRoll (t, v) => let val (fv, v) = uval v
                      in
                        (fv, VRoll (t, v))
                      end
    | VInject (t, l, NONE) => (empty, value)
    | VInject (t, l, SOME v) => let val (fv, v) = uval v
                                in
                                  (fv, VInject(t, l, SOME v))
                                end

    | Fns fl =>
                                let val (fv, names, fl) = ListUtil.unzip3 ` 
                                  map (fn {name, arg, dom, cod, body, inline, recu, total} =>
                                       let
                                         val (fv, body) = uexp body
                                       in
                                         (foldl (fn (v, fv) => fv -- v) fv arg,
                                          name,
                                          (* PERF could update 'recu' here but we don't
                                             use it elsewhere.. *)
                                          {name = name, arg = arg, dom = dom, cod = cod,
                                           body = body, inline = inline, recu = recu,
                                           total = total})
                                       end) fl
                                in
                                   (* subtract all rec names *)
                                  (foldl (fn (v, fv) => fv -- v) (unionl fv) names,
                                   Fns fl)
                                end

(*
      | Fns of 
        { name : var,
          arg  : var list,
          dom  : typ list,
          cod  : typ,
          body : exp,
          (* should always inline? *)
          inline : bool,
          (* these may be conservative estimates *)
          recu : bool,
          total : bool } list

        
      (* select one of the functions in a bundle *)
      | FSel of int * value

      (* XXX no longer representing dictionaries at the IL level *)

      (* apply (total)value to value *)
      | VApp of value * value
      | VLam of var * typ * value

      (* the dictionary for this type, assuming dlist gives
         the dictionaries for the abstract type variables. *)
      | VDict of typ * (var * value) list
*)

  and uexp exp =
    case exp of
      Value v => let val (fv, v) = uval v
                 in (fv, Value v)
                 end
    | App (e, el) => let val (fv1, e) = uexp e
                         val (fvs, el) = ListPair.unzip ` map uexp el
                     in
                       (fv1 || unionl fvs, App(e, el))
                     end
(*       
      (* application is n-ary *)
      | App of exp * exp list

      | Record of (label * exp) list
      (* #lab/typ e *)
      | Proj of label * typ * exp
      | Raise of typ * exp
      (* var bound to exn value within handler *)
      | Handle of exp * var * exp

      | Seq of exp * exp
      | Let of dec * exp
      | Unroll of exp
      | Roll of typ * exp

      | Get of { addr : exp,
                 dest : world,
                 typ  : typ,
                 (* dlist : (var * value) list option, *)
                 body : exp }

      | Throw of exp * exp
      | Letcc of var * typ * exp

      (* tag v with t *)
      | Tag of exp * exp

      | Untag of { typ : typ,
                   obj : exp,
                   target : exp,
                   bound : var, (* within yes *)
                   yes : exp,
                   no : exp }

      (* apply a primitive to some expressions and types *)
      | Primapp of Primop.primop * exp list * typ list

      (* sum type, object, var (for all arms), branches, default.
         the label/exp list need not be exhaustive.
         *)
      | Sumcase of typ * exp * var * (label * exp) list * exp
      | Inject of typ * label * exp option

      (* for more efficient treatment of blobs of text. *)
      | Jointext of exp list
*)

  (* given free vars needed below, generate the
     new list of decs and free vars needed above *)
  fun udecs fv decs = raise Unused "unimplemented"
    

  fun fvexports nil = (empty, nil)
    | fvexports (ExportWorld (l, w) :: rest) =
                                       let val (fv, rest) = fvexports rest
                                       in (fv, ExportWorld (l, w) :: rest)
                                       end
    | fvexports (ExportType (k, l, v) :: rest) =
                                       let val (fv, rest) = fvexports rest
                                       in (fv, ExportType (k, l, v) :: rest)
                                       end
    | fvexports (ExportVal (Poly(p, (l, t, wo, va))) :: rest) =
                                       let val (fv, rest) = fvexports rest
                                           val (fv2, va) = uval va
                                       in
                                         (fv || fv2, ExportVal (Poly(p, (l, t, wo, va))) :: rest)
                                       end

  fun unused (Unit (decs, exports)) =
    let
      (* exports are always all kept *)
      val (fv, exports) = fvexports exports

      val (fv, decs) = udecs fv decs
    in
      (* fv should be empty, aside from prims.. *)
      Unit (decs, exports)
    end
    
end
