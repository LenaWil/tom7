
(* Dictionary-passing transformation. 

   This pass transforms polymorphic code to insert dictionaries at
   'Get' expressions. A dictionary maps abstract type variables to
   a pair of values that allow marshalling and unmarshalling that
   type. A compiled 'Get' needs to marshall a closure built from
   the environment of the body of the Get (and its evaluation context).
   At this point in the compiler we have not generated the closures
   yet, so we don't know what they'll contain (and so what types will
   need to be marshalled). So, we record all the abstract types currently
   in scope along with the marshalling functions for them in the dictionary.

   Abstract types are introduced in two ways: Polymorphic abstraction
   (which, at the IL level, can occur only at Fun and Val bindings), and
   Extern types. In order to ensure that we have a dictionary entry for every
   type in scope, we must arrange for such values to accompany these abstract
   types in the places in which they are introduced.
   
   For polymorphic abstraction, we rewrite the abstraction sites to
   add one value argument for each type argument. The only kind of
   abstraction site is the polymorphic Val binding, and the only kind
   of instantiation site is the PolyVar. (Actually, there are also
   bindings and occurrences for valid variables, and we need to carry
   out the same translation there.)

   For each type variable bound in a Val binding, we wrap the value
   with a VLam binding a dictionary associated with that type variable.
   We keep these associations in our translation context.

   When reaching a PolyVar, we use VApp to apply the abstracted value
   to the appropriate dictionaries. We have the types that the polyvar
   is instantiated with, so this is just a matter of looking up those
   types' dictionaries in the translation context.

   
   For extern types, we introduce an additional ExternVal for each
   ExternType. For types of kind 0, the value has type t dict, where t
   is the extern type. If the extern type has kind > 0 (e.g. if it is
   ('a, 'b) t) then its dictionary will have the form 'a dict -> 'b
   dict -> t dict. We must also export such dictionaries. These are
   simply added along side each exported type. 

   
   This translation also has the side-effect of setting all unset
   existential type variables that appear in the code to unit,
   and all unset existential world variables to home.

   We do not need to translate mono types at all in this translation,
   because it only affects type type abstraction in polytypes.

*)

structure ILDict :> ILDICT =
struct

  infixr 9 `
  fun a ` b = a b

  open IL
  structure V = Variable

  exception ILDict of string

  (* the context is an association list of abstract type variable to
     value variable standing for the dictionary at that type *)
  val initial = nil
  (* gives back the dictionary value for the type t. *)
  fun dictfor G t = VDict (t, G)

  fun te G e =
    (case e of
       Value v => Value ` tv G v
     | Roll (t, e) => Roll (t, te G e)
     | Inject (t, l, eo)  => Inject (t, l, Option.map (te G) eo)
     | App (e1, el) => App(te G e1, map (te G) el)
     | Record lel => Record ` ListUtil.mapsecond (te G) lel
     | Raise (t, e) => Raise (t, te G e)
     | Handle (e, v, e') => Handle (te G e, v, te G e')
     | Seq (e, e') => Seq (te G e, te G e')
     | Let (d, e) => 
         let
           val (G, d) = td G d
         in
           Let(d, te G e)
         end
     | Unroll e => Unroll ` te G e

     | Get { dlist = SOME _, ... } => raise ILDict "get already has dictionary!"
     | Get { addr, typ, dlist = NONE, body} =>
         Get { addr = te G addr, typ = typ, dlist = SOME G, body = te G body }
(*

      | Throw of exp * exp
      | Letcc of var * typ * exp

      (* tag v with t *)
      | Tag of exp * exp
      (* tagtype, object, var (for all arms), branches, def *)
      | Tagcase of typ * exp * var * (var * exp) list * exp

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

     | _ => Value ` Polyvar{worlds=nil, tys=nil, var=V.namedvar "dictexp_unimplemented"}
         )
       
  and tv G v =
    (case v of
       (* instantiation takes place at polyvars *)
       Polyvar {tys, worlds, var} =>
         let
           fun applydict nil = Polyvar {tys = tys, worlds = worlds, var = var}
             | applydict (t :: rest) =
             VApp(applydict rest, dictfor G t)
         in
           (* first type in forall is outermost (last) application *)
           applydict (rev tys)
         end
     (* more or less the same thing for uvars .. *)
     | Polyuvar {tys, worlds, var} =>
         let
           fun applydict nil = Polyuvar {tys = tys, worlds = worlds, var = var}
             | applydict (t :: rest) =
             VApp(applydict rest, dictfor G t)
         in
           (* first type in forall is outermost (last) application *)
           applydict (rev tys)
         end

       (* needs vvapp? *)
     (* | PolyUVar {tys, worlds, var} =>  *)
      | Int _ => v
      | String _ => v
      | VRecord lvl => VRecord (ListUtil.mapsecond (tv G) lvl)
      | VRoll (t, v) => VRoll (t, tv G v)
      | VInject (t, l, vo)  => VInject (t, l, Option.map (tv G) vo)
      | Fns fl => Fns `
                  map (fn { name, arg, dom, cod, body, inline, recu, total } =>
                       { name = name, arg = arg, dom = dom, cod = cod,
                         body = te G body,
                         inline = inline,
                         recu = recu,
                         total = total }) fl
      | FSel (i, v) => FSel (i, tv G v)
      (* probably shouldn't see this yet... *)
      | VApp (v1, v2) => VApp(tv G v1, tv G v2)
      | VLam (x, t, v) => VLam (x, t, tv G v)
      | VDict (t, dlist) => VDict (t, ListUtil.mapsecond (tv G) dlist)

                  )

  and td G d =
    (case d of
      Val (Poly({worlds=nil, tys=nil}, (v, t, e))) => 
        (G, Val (Poly ({worlds=nil, tys = nil}, (v, t, te G e))))
        
    (* abstraction happens at Val decls *)
    | Val (Poly({worlds, tys}, (v, t, Value va))) =>
       let
         val vars = map (fn x => (x, V.namedvar (V.basename x ^ "_d"))) tys

         fun mkt nil = t
           | mkt (a :: rest) = VArrow(Dict (TVar a), mkt rest)

         fun mkv nil = 
           tv (ListUtil.mapsecond Var vars @ G) va
           | mkv ((t, tv) :: rest) = VLam(tv, Dict (TVar t), mkv rest)

       in
         (G (* we translate all polyvars so no need to change this.. *),
          Val (Poly({worlds=worlds, tys=tys},
                    (v, mkt tys, Value (mkv vars)))))
       end
   | Val _ => raise ILDict ("generalized non-value: " ^ Layout.tostring (ILPrint.dtol d))

   | ExternVal(Poly ({worlds, tys}, (l, v, t, wo))) =>
       let 
         fun mkt nil = t
           | mkt (a :: rest) = VArrow(Dict (TVar a), mkt rest)
       in
         (G, ExternVal(Poly({worlds=worlds,tys=tys}, (l, v, mkt tys, wo))))
       end

   | Do e => (G, Do (te G e))

   | _ => (G,Do ` Value ` Polyvar{worlds=nil, tys=nil, var=V.namedvar "dict_unimplemented"})
       )

  and tx G x = 
    (case x of
       _ => ExportWorld ("dict_unimplemented", WVar (V.namedvar "dict_unimplemented")))
         
  fun transform (Unit(ds, xs)) = 
    let
      fun tds G nil = (G, nil)
        | tds G (d :: ds) =
        let
          val (G, d) = td G d
          val (G, ds) = tds G ds
        in
          (G, d :: ds)
        end

      val (G, ds) = tds initial ds
    in
      Unit(ds, map (tx G) xs)
    end handle Match => raise ILDict "dict not finished"
    

end