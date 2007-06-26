(* Representations:

   There is an array of all of the globals in the program.
   Labels are indices into this array.
   Global lams are themselves arrays, one for each fn in the bundle.
   
   A function value is a pair of integers: the first is the index of
   the global and the second is the index of the fn within the bundle.
   So function values are JS objects with prioperties g and f (integers).

   A value of type lams is just an integer, as is a value of type AllLam
   when there is at least one value arg.

   Static constructors are not represented at all, by definition. This includes
   At, Shamrock, WExists, ...

   A TPack agglomerates a dictionary and n values, so it is represented as
   a javascript object { d , v0, ..., v(n-1) }

   A record with labels s1...sn is represented as an object with properties ls1 .. lsn.
   The "l" is prepended so that labels that start with numbers (allowed in the CPS)
   become valid javascript identifiers.

   A sum is represented as an object { t, v } or { t } where t is the tag (as a string)
   and v is the embedded value, if any.

   Dictionaries are represented as follows
 
    { w : tag, ... } where 

      tag
      DP       p : c, C, a, d, i, s or v
      DR       v : array of { l : String, v : Object }
      DS       v : array of { l : String, v : Object (maybe missing) }
      DE       d : String, v : array of Object
      DL       s : String

*)
structure JSCodegen :> JSCODEGEN =
struct

  infixr 9 `
  fun a ` b = a b

  exception JSCodegen of string

  open JSSyntax

  structure C = CPS
  structure SM = StringMap
  structure V = Variable

  (* n.b. these must agree with runtime *)
  val codeglobal = Id.fromString "globalcode"
  val enqthread  = Id.fromString "lc_enq_thread"
  val yield      = Id.fromString "lc_yield"
  val go_mar     = Id.fromString "lc_go_mar"
  val marshal    = Id.fromString "lc_marshal"
  val homeaddr   = "home"

  (* maximum identifier length of 65536... if we have identifiers longer than that,
     then increasing this constant is the least of our problems. *)
  fun vartostring v = StringUtil.harden (fn #"_" => true | _ => false) #"$" 65536 ` V.tostring v

  val itos = Int.toString
  fun vtoi v = $(vartostring v)
  fun vtos v = String.fromString ` vartostring v

  val pn = PropertyName.fromString

  fun wi f = f ` vtoi ` V.namedvar "x"

  fun generate { labels, labelmap } (gen_lab, SOME gen_global) =
    let

      (* convert the "value" value and send the result (exp) to the continuation k *)
      fun cvtv value (k : Exp.t -> Statement.t list) : Statement.t list =
        (case C.cval value of
           C.Var v => k ` Id ` vtoi v

         | C.UVar v => k ` Id ` vtoi v

         | C.Hold (_, va) => cvtv va k
         | C.Sham (_, va) => cvtv va k
         | C.WPack (_, va) => cvtv va k
         | C.Unroll va => cvtv va k
         | C.Roll (_, va) => cvtv va k
         (* if there are no vals, these are purely static *)
         | C.AllLam { worlds, tys, vals = nil, body } => cvtv body k
         | C.AllApp { worlds, tys, vals = nil, f } => cvtv f k

         | C.Dict d => 
             let
(*

   Dictionaries are represented as follows
 
    { w : tag, ... } where 

      tag (string)
      DP       p : c, C, a, d, i, s or v
      DR       v : array of { l : String, v : Object }
      DS       v : array of { l : String, v : Object (maybe missing) }
      DE       d : String, v : array of Object
      DL       s : String
*)

               val s = String o String.fromString
                
               fun dict w rest = Object ` % (prop "w" (s w) ::
                                             map (fn (a, b) => prop a b) rest)


               (* this is the set of locally bound dictionary variables.
                  we'll turn these into string lookups if we see them. *)

               val G = V.Set.empty
               fun cd G (C.At (t, _)) = cdict G t
                 | cd G (C.Shamrock t) = cdict G t
                 | cd G (C.Cont _)  = dict "DP" [("p", s"c")]
                 | cd G (C.Conts _) = dict "DP" [("p", s"C")]
                 | cd G (C.Primcon (C.INT, nil)) = dict "DP" [("p", s"i")]
                 | cd G (C.Primcon (C.STRING, nil)) = dict "DP" [("p", s"s")]
                 | cd G (C.Primcon (C.DICTIONARY, nil)) = dict "DP" [("p", s"d")]
                 | cd G (C.Addr _) = dict "DP" [("p", s"a")]
                 | cd G (C.Product stl) = dict "DR" 
                 [("v", Array ` % ` map (fn (l, d) =>
                                         SOME `
                                         Object ` % [prop "l" ` s ("l" ^ l),
                                                     prop "v" ` cdict G d]) stl)]
                 | cd G (C.TExists ((_, v), tl)) = 
                         let
                           val G = V.Set.add(G, v)
                         in
                           dict "DE" [("d", String ` vtos v),
                                      ("v", Array ` % ` map (SOME o cdict G) tl)]
                         end

                 | cd _ d = 
                 let in
                   print "BCG: unimplemented val\n";
                   Layout.print (CPSPrint.vtol ` C.Dict' d, print);

                   s"unimplemented"
                 end

               and cdict G e =
                 case C.cval e of
                   C.Dict d => cd G d
                 | C.UVar u => 
                         if V.Set.member (G, u)
                         then dict "DL" [("s", String ` vtos u)]
                         else Id ` vtoi u
                 | _ => raise JSCodegen
                     "when converting dict, expected to see just dicts and vars"

             in
               wi (fn p => Bind (p, cd G d) :: k ` Id p)
             end

         | C.Int ic =>
             let val r = IntConst.toReal ic
             in k ` RealNumber r
             end
         | C.String s => wi (fn p => Bind (p, String ` String.fromString s) :: k ` Id p)
         | C.Codelab s =>
             (case SM.find (labelmap, s) of
                NONE => raise JSCodegen ("couldn't find codelab " ^ s)
              | SOME i => k ` Number ` Number.fromInt i)

         (* PERF we perhaps should have canonicalized these things a long time ago so
            that we always use the same label names. Though it's not obvious that arrays
            are even any more efficient than objects with property lists? *)
         | C.Record svl =>
             let
               val (ss, vv) = ListPair.unzip svl
             in
               cvtvs vv
               (fn vve =>
                let val svl = ListPair.zip (ss, vve)
                in
                  wi (fn p => 
                      Bind (p, Object ` % `
                            map (fn (s, v) =>
                                 Property { property = pn ("l" ^ s),
                                            value = v }) svl) :: 
                      k ` Id p)
                end)
             end

         | C.Fsel (va, i) =>
             (* just a pair of the global's label and the function id within the bundle *)
             cvtv va
             (fn va =>
              wi (fn p => Bind (p, Object ` %[ Property { property = pn "g",
                                                          value = va },
                                               Property { property = pn "f",
                                                          value = Number ` Number.fromInt i } ])
                  :: k ` Id p))
              
         | C.Proj (s, va) => 
             cvtv va
             (fn va => wi (fn p => Bind (p, Sel va ("l" ^ s)) :: k ` Id p))

         | C.Inj (s, _, NONE) =>
             wi (fn p => Bind (p, Object ` %[ Property { property = pn "t",
                                                         value = String ` String.fromString s }]) 
                 :: k ` Id p)

         | C.Inj (s, _, SOME va) =>
             cvtv va
             (fn va =>
             wi (fn p => Bind (p, Object ` %[ Property { property = pn "t",
                                                         value = String ` String.fromString s },
                                              Property { property = pn "v",
                                                         value = va }])
                 :: k ` Id p)
              )

         | C.AllApp _ => 
             wi (fn p => Bind (p, String ` String.fromString "allapp unimplemented") :: k ` Id p)

             (* weird? *)
         | C.VLetsham (v, va, c) =>
             cvtv va
             (fn va =>
              Bind (vtoi v, va) :: cvtv c k)

         | C.VLeta (v, va, c) =>
             cvtv va
             (fn va =>
              Bind (vtoi v, va) :: cvtv c k)

         | C.Dictfor _ => raise JSCodegen "should not see dictfor in js codegen"
         | C.Lams _ => raise JSCodegen "should not see lams except at top level in js codegen"
         | C.AllLam { vals = _ :: _, ... } => 
             raise JSCodegen "should not see non-static alllam in js codegen"

         | C.TPack (_, _, vd, vl) =>
             cvtv vd 
             (fn (vde : Exp.t) =>
              cvtvs vl 
              (fn (vle : Exp.t list) =>
               wi (fn p =>
                   Bind (p, Object ` % `
                         (Property { property = PropertyName.fromString "d",
                                     (* XXX requires that it is an identifier, num, or string? *)
                                     value = vde } ::
                          ListUtil.mapi (fn (e, idx) =>
                                         Property { property = PropertyName.fromString ("v" ^ itos idx),
                                                    value = e }) vle))
                   :: k ` Id p
                   )))
         | C.VTUnpack (_, dv, cvl, va, vbod) =>
             cvtv va
             (fn ob =>
              (* select each component and bind... *)
              Bind(vtoi dv, SelectId { object = ob, property = Id.fromString "d" }) ::
              (ListUtil.mapi (fn ((cv, _), i) =>
                             Bind(vtoi cv, SelectId { object = ob, property = Id.fromString ("v" ^ itos i) }))
                            cvl @
               cvtv vbod k)
              )

(*
         |  _ => 
             wi (fn p =>
                 Bind (p, String (String.fromString "unimplemented val")) ::
                 k ` Id p)
*)
             )

    (*       [Throw ` String ` String.fromString "unimplemented val"]) *)


      and cvtvs (values : C.cval list) (k : Exp.t list -> Statement.t list) : Statement.t list =
           case values of 
             nil => k nil
           | v :: rest => cvtv v (fn (ve : Exp.t) =>
                                  cvtvs rest (fn (vl : Exp.t list) => k (ve :: vl)))

      fun cvte exp : Statement.t list =
           (case C.cexp exp of
              C.Halt => [Return NONE]

            | C.ExternVal (var, lab, _, _, e) =>
            (* XXX still not really sure how we interface with things here... *)
                (Var ` %[(vtoi var, SOME (Id ` Id.fromString lab))]) :: cvte e

            | C.Letsham (v, va, e)    => cvtv va (fn ob => Bind (vtoi v, ob) :: cvte e)
            | C.Leta    (v, va, e)    => cvtv va (fn ob => Bind (vtoi v, ob) :: cvte e)
            | C.WUnpack (_, v, va, e) => cvtv va (fn ob => Bind (vtoi v, ob) :: cvte e)
            | C.Put     (v, _, va, e) => cvtv va (fn ob => Bind (vtoi v, ob) :: cvte e)

            | C.TUnpack (_, dv, cvl, va, e) =>
                cvtv va
                (fn ob =>
                 (* select each component and bind... *)
                 Bind(vtoi dv, Sel ob "d") ::
                 (ListUtil.mapi (fn ((cv, _), i) =>
                                 Bind(vtoi cv, Sel ob ("v" ^ itos i)))
                  cvl @
                  cvte e))

            | C.Go _ => raise JSCodegen "shouldn't see go in js codegen"
            | C.Go_cc _ => raise JSCodegen "shouldn't see go_cc in js codegen"
            | C.ExternWorld _ => raise JSCodegen "shouldn't see externworld in js codegen"

            | C.Primop ([v], C.PRIMCALL { sym, ... }, args, e) =>
                cvtvs args
                (fn args =>
                 (* assuming sym has the name of some javascript function. *)
                 Bind (vtoi v, Call { func = Id ` $sym, args = %args }) ::
                 cvte e)

            | C.Primop ([v], C.BIND, [va], e) =>
                cvtv va
                (fn va =>
                 Bind (vtoi v, va) :: cvte e)

            | C.Primop ([v], C.LOCALHOST, [], e) =>
                Bind (vtoi v, String ` String.fromString homeaddr) :: cvte e

            | C.Primop ([v], C.MARSHAL, [vd, va], e) =>
                cvtv vd
                (fn vd =>
                 cvtv va
                 (fn va =>
                  Bind (vtoi v, Call { func = Id marshal, args = %[vd, va] }) ::
                  cvte e))

            | C.Primop _ => [Throw ` String ` String.fromString "unimplemented primop"]

            | C.Go_mar { w = _, addr, bytes } =>
                cvtv addr
                (fn addr =>
                 cvtv bytes
                 (fn bytes =>
                  (* implemented in runtime. *)
                  [Exp ` Call { func = Id go_mar,
                                args = %[addr, bytes] }]
                  ))

            | C.Case (va, v, sel, def) => 
                cvtv va
                (fn va =>
                 (* bind variable to inner value first. If there's no value (because it's a
                    nullary constructor) then it just failceeds and the variable will have
                    value "undefined" 

                    NOTE: we rely on 'v' not being free in the default.
                    *)
                [Bind(vtoi v, Sel va "v"),
                 Switch { test = Sel va "t",
                          clauses = %(map (fn (s, e) =>
                                           (SOME ` String ` String.fromString s,
                                            %[Block ` % ` (cvte e @ [Break NONE])])) sel @
                                      [(NONE, %[Block ` % ` (cvte def @ [Break NONE])])]) }
                 ]
                 )

            | C.ExternType (_, _, vso, e) => [Throw ` String ` String.fromString "unimplemented externtype"]

(*
    | Primop of var list * primop * 'cval list * 'cexp
*)


            | C.Call (f, args) => 
               (* Rather than doing the call now, we put this on our thread queue
                  to be executed later. We also arrange for the scheduler to run
                  in a little while. We have to do this to support multitasking and
                  because tail calls use space in javascript. *)
                cvtv f 
                (fn fe =>
                 cvtvs args
                 (fn ae =>
                 
                  (* delayed call *)
                  [Exp ` Call { func = Id enqthread,
                                args = %[Sel fe "g",
                                         Sel fe "f",
                                         Array ` % ` map SOME ` ae] },
                   (* must yield since threadcount has increased *)
                   (* XXX maybe this should be in enqthread? *)
                   Exp ` Call { func = Id yield,
                                args = %[] }
                   ]
                  (* direct call
                  [Exp ` Call { func = Sele (Sele (Id codeglobal) (Sel fe "g")) (Sel fe "f"),
                                args = % ae }]
                  *)
                  )
                )
                
               ) (* big case *)


      (* Now, to generate code for this global... *)

      (* In this type-erasing translation there are a lot of things
         we'll ignore, including the difference between PolyCode and Code. *)
      val va = 
        (case C.cglo gen_global of
           C.PolyCode (_, va, _) => va
         | C.Code (va, _, _) => va)
    in
      (case C.cval va of
         C.AllLam { worlds = _, tys = _, vals, body } =>
           (case C.cval body of
              C.Lams fl =>
                Array ` % ` map SOME `
                map (fn (f, args, e) =>
                     let
                     in
                       Function { args = % ` map (vtoi o #1) args,
                                  name = NONE,
                                  body = % ` cvte e }
                     end) fl

            | C.AllLam _ => raise JSCodegen "hoisted alllam unimplemented"
            | _ => raise JSCodegen ("expected label " ^ gen_lab ^ 
                                    " to be alllam then lams/alllam"))

         | _ => raise JSCodegen ("expected label " ^ gen_lab ^ 
                                 " to be a (possibly empty) AllLam"))
    end
    | generate _ (lab, NONE) = 
    Function { args = %[],
               name = NONE,
               body = %[Throw ` String ` 
                        String.fromString "wrong world"] }

end