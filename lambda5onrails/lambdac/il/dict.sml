
(* Note: obsolete! We do this in the CPS phase now. *)

(* Dictionary-passing transformation. 

   This pass transforms polymorphic code to insert dictionaries at
   'Get' expressions. A dictionary maps abstract type variables to
   a pair of values that allow marshalling and unmarshalling that
   type. A compiled 'Get' needs to marshal a closure built from
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

  (* For a type labeled l, derive the label that
     will stand for its dictionary. *)
  fun dictbar l = l ^ ";dict"

  fun list x = [x]

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
           val (G, ds) = td G d
         in
           foldr Let (te G e) ds
         end
     | Unroll e => Unroll ` te G e

     | Get { dlist = SOME _, ... } => raise ILDict "get already has dictionary!"
     | Get { addr, typ, dlist = NONE, body} =>
         Get { addr = te G addr, typ = typ, dlist = SOME G, body = te G body }
     | Tag (e1, e2) => Tag (te G e1, te G e2)
     | Tagcase (t, e, v, vel, def) => 
         Tagcase (t, te G e, v, ListUtil.mapsecond (te G) vel, te G def)
     (* Assuming these don't need marshalling functions, though we
        could put them here... *)
     | Primapp (po, el, tl) => Primapp (po, map (te G) el, tl)
     | Throw (e1, e2) => Throw (te G e1, te G e2)
     | Letcc (v, t, e) => Letcc (v, t, te G e)
     | Sumcase (t, e, v, lel, def) =>
         Sumcase(t, te G e, v, ListUtil.mapsecond (te G) lel, te G def)

     | Jointext el => Jointext ` map (te G) el
     | Proj (l, t, e) => Proj (l, t, te G e)

(*     | _ => Value ` Polyvar{worlds=nil, tys=nil, var=V.namedvar "dictexp_unimplemented_exp"} *)
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
        (G, list ` Val (Poly ({worlds=nil, tys = nil}, (v, t, te G e))))
        
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
          list `
          Val (Poly({worlds=worlds, tys=tys},
                    (v, mkt tys, Value (mkv vars)))))
       end
   | Val _ => raise ILDict ("generalized non-value: " ^ Layout.tostring (ILPrint.dtol d))

   | ExternVal(Poly ({worlds, tys}, (l, v, t, wo))) =>
       let 
         fun mkt nil = t
           | mkt (a :: rest) = VArrow(Dict (TVar a), mkt rest)
       in
         (G, list ` ExternVal(Poly({worlds=worlds,tys=tys}, (l, v, mkt tys, wo))))
       end

   | ExternWorld(l, v) => (G, list ` ExternWorld (l, v))

   | ExternType(0, l, v) =>
       let
         val vd = V.namedvar (V.basename v ^ "_impd")
       in
         ((v, Var vd) :: G,
          [ExternType(0, l, v),
           ExternVal(Poly ({worlds=nil, tys=nil}, (dictbar l, vd, Dict (TVar v), NONE)))])
       end

   | ExternType _ => raise ILDict "saw extern type of kind > 0"

   | Do e => (G, list ` Do (te G e))

   | _ => (G, [Do ` Value ` Polyvar{worlds=nil, tys=nil, var=V.namedvar "dict_unimplemented_dec"}])
       )

  and tx G x = 
    (case x of
       ExportWorld (l, w) => list ` ExportWorld (l, w)
     | ExportType (nil, l, t) => 
         [ExportType (nil, l, t),
          (* and dictionary for it.. *)
          ExportVal (Poly ({worlds=nil, tys=nil}, (dictbar l, Dict t, NONE, dictfor G t)))]
     | ExportType _ => raise ILDict "export type of kind > 0"
     | _ => list ` ExportWorld ("dict_unimplemented", WVar (V.namedvar "dict_unimplemented_export")))
         
  fun transform (Unit(ds, xs)) = 
    let
      fun tds G nil = (G, nil)
        | tds G (d :: ds) =
        let
          val (G, d) = td G d
          val (G, ds) = tds G ds
        in
          (G, d @ ds)
        end

      val (G, ds) = tds initial ds
    in
      Unit(ds, List.concat ` map (tx G) xs)
    end handle Match => raise ILDict "dict not finished"
    

end