(* Representations:

   There is a vector of all of the globals in the program.
   Labels are indices into this vector.
   Global FunDecs are themselves vectors, one for each fn in the bundle.

   A function value is a pair of integers: the first is the index of
   the global and the second is the index of the fn within the bundle.
   So function values are records with fields g and f (integers).

   A value of type lams is just an integer, as is a value of type AllLam
   when there is at least one value arg.

   Static constructors are not represented at all, by definition. This includes
   At, Shamrock, WExists, ...

   A TPack agglomerates a dictionary and n values, so it is represented as
   a record { d , v0, ..., v(n-1) }

   A record with labels s1...sn is represented a record with fields ls1 .. lsn.
   We prepend an 'l' to labels for compatibility with the javascript representation.

   Inj is Inj, straightforwardly
     
*)
structure ByteCodegen :> BYTECODEGEN =
struct

  infixr 9 `
  fun a ` b = a b

  exception ByteCodegen of string

  structure C = CPS
  structure SM = StringMap
  structure V = Variable
  open Bytecode

  (* maximum identifier length of 65536... if we have identifiers longer than that,
     then increasing this constant is the least of our problems. *)
  fun vartostring v = StringUtil.harden (fn #"_" => true | _ => false) #"$" 65536 ` V.tostring v

  val itos = Int.toString
  fun vtoi v = vartostring v

  fun wi f = f ` vtoi ` V.namedvar "x"

  fun generate { labels, labelmap } hostname (gen_lab, SOME gen_global) =
    let

      (* convert the "value" value and send the result (exp) to the continuation k *)
      fun cvtv value (k : exp -> statement) : statement =
        (case C.cval value of
           C.Var v => k ` Var ` vtoi v

         | C.UVar v => k ` Var ` vtoi v

         | C.Hold (_, va) => cvtv va k
         | C.Sham (_, va) => cvtv va k
         | C.WPack (_, va) => cvtv va k
         | C.Unroll va => cvtv va k
         | C.Roll (_, va) => cvtv va k
         (* if there are no vals, these are purely static *)
         | C.AllLam { worlds, tys, vals = nil, body } => cvtv body k
         | C.AllApp { worlds, tys, vals = nil, f } => cvtv f k

         | C.WDict d => k ` String d
         | C.Dict d => 
             let
               (* this is the set of locally bound dictionary variables.
                  we'll turn these into string lookups if we see them. *)
               val G = V.Set.empty
               fun cd G (C.Cont _)  = Dp Dcont
                 | cd G (C.Conts _) = Dp Dconts
                 | cd G (C.At (t, w)) = Dat { d = cdict G t,
                                              a = cwdict G w }
                 | cd G (C.Primcon (C.INT, nil)) = Dp Dint
                 | cd G (C.Primcon (C.STRING, nil)) = Dp Dstring
                 (* don't care what t is; all dicts represented the same way *)
                 | cd G (C.Primcon (C.DICTIONARY, [t])) = Dp Ddict
                 (* ditto. *)
                 | cd G (C.Primcon (C.REF, [_])) = Dp Dref
                 (* always represented the same way, regardless of which world *)
                 | cd G (C.Addr _) = Dp Daddr
                 | cd G (C.TWdict _) = Dp Dw
                 | cd G (C.Product stl) = Drec ` 
                             map (fn (l, e) => ("l" ^ l, cdict G e)) stl
                 | cd G (C.Shamrock ((_, wd), t)) =
                         let 
                           val G = V.Set.add(G, wd)
                         in
                           Dsham { d = vtoi wd, v = cdict G t }
                         end

                 | cd G (C.TExists ((_, v), tl)) = 
                         let
                           val G = V.Set.add(G, v)
                         in
                           Dexists {d = vtoi v, a = map (cdict G) tl}
                         end

                 (* If static, then we just need to keep track of the type variables
                    that are bound. (But just for cleanliness at runtime. We should
                    never have to marshal e.g.  /\a. (int * a)) *)
                 | cd G (C.AllArrow {worlds = _, tys, vals = nil, body }) =
                         let
                           val tys = map #2 tys
                           val G = foldl (fn (v, G) => V.Set.add(G, v)) G tys
                         in
                           Dall (map vtoi tys, cdict G body)
                         end

                 (* if it is not static, then it is always represented as an int
                    (index into globals) *)
                 | cd G (C.AllArrow {worlds = _, tys = _, vals = _, body = _}) = Dp Daa
                 | cd _ d = 
                 let in
                   print "BCG: unimplemented val\n";
                   Layout.print (CPSPrint.vtol ` C.Dict' d, print);
                   print "\n";

                   raise ByteCodegen
                     "oops, convert dict front unimplemented"
                 end

               and cwdict G e =
                 case C.cval e of
                   C.WDict s => String s
                 | C.UVar u => 
                     if V.Set.member (G, u)
                     then raise ByteCodegen "DW unimplemented"
                     (*dict "DW" [("s", String ` vtos u)] *)
                     else Var ` vtoi u
                 | _ => raise ByteCodegen "when converting dict, expected to see just wdicts and vars"

               and cdict G e =
                 case C.cval e of
                   C.Dict d => cd G d
                 | C.UVar u => 
                         if V.Set.member (G, u)
                         then Dlookup ` vtoi u
                         else Var ` vtoi u
                 | _ => raise ByteCodegen 
                     "when converting dict, expected to see just dicts and vars"

             in
               wi (fn p => Bind (p, cd G d, k ` Var p))
             end


         | C.Int ic => k ` Int ic
         | C.String s => wi (fn p => Bind (p, String s, k ` Var p))
         | C.Codelab s =>
             (case SM.find (labelmap, s) of
                NONE => raise ByteCodegen ("couldn't find codelab " ^ s)
              | SOME i => k ` Int ` IntConst.fromInt i)

         (* PERF we perhaps should have canonicalized these things a long time ago so
            that we can use more efficient representations. This probably means putting
            a type annotation in Project. *)
         | C.Record svl =>
             let
               val (ss, vv) = ListPair.unzip svl
             in
               cvtvs vv
               (fn vve =>
                let val svl = ListPair.zip (ss, vve)
                in
                  wi (fn p => 
                      Bind (p, Record `
                            map (fn (s, v) => ("l" ^ s, v)) svl,
                            k ` Var p))
                end)
             end

         | C.Fsel (va, i) =>
             (* just a pair of the global's label and the function id within the bundle *)
             cvtv va
             (fn va =>
              wi (fn p => Bind (p, Record[("g", va), ("f", Int ` IntConst.fromInt i)],
                                k ` Var p)))

         | C.Proj (s, va) => 
             cvtv va
             (fn va => wi (fn p => Bind (p, Project("l" ^ s, va), k ` Var p)))


         | C.Inj _ => Error "inj unimplemented"
             (* wi (fn p => Bind (p, String "inj unimplemented", k ` Var p)) *)

         | C.AllApp { f, worlds = _, tys = _, vals = vals as _ :: _ } => 
             cvtv f
             (fn f =>
              cvtvs vals
              (fn vals =>
               wi (fn p => Bind (p, Call (f, vals), k ` Var p))))

         (* weird? *)
         | C.VLetsham (v, va, c) =>
             cvtv va
             (fn va =>
              Bind (vtoi v, va, cvtv c k))

         | C.VLeta (v, va, c) =>
             cvtv va
             (fn va =>
              Bind (vtoi v, va, cvtv c k))

         | C.Dictfor _ => raise ByteCodegen "should not see dictfor in codegen"
         | C.WDictfor _ => raise ByteCodegen "should not see wdictfor in codegen"
         | C.Lams _ => raise ByteCodegen "should not see lams except at top level in codegen"
         | C.AllLam { vals = _ :: _, ... } => 
             raise ByteCodegen "should not see non-static alllam in codegen"

         | C.TPack (_, _, vd, vl) =>
             cvtv vd 
             (fn (vde : exp) =>
              cvtvs vl 
              (fn (vle : exp list) =>
               wi (fn p =>
                   Bind (p, Record
                         (("d", vde) ::
                          ListUtil.mapi (fn (e, idx) => ("v" ^ itos idx, e)) vle),
                         k ` Var p))))

         | C.VTUnpack (_, dv, cvl, va, vbod) =>
             cvtv va
             (fn ob =>
              (* select each component and bind... *)
              Bind(vtoi dv, Project ("d", ob),
                   let fun binds _ nil = cvtv vbod k
                         | binds i ((cv, _)::rest) =
                     Bind(vtoi cv, Project("v" ^ itos i, ob), binds (i + 1) rest)
                   in
                     binds 0 cvl
                   end)
              )

             )

      and cvtvs (values : C.cval list) (k : exp list -> statement) : statement =
           case values of 
             nil => k nil
           | v :: rest => cvtv v (fn (ve : exp) =>
                                  cvtvs rest (fn (vl : exp list) => k (ve :: vl)))

      fun cvte exp : statement =
           (case C.cexp exp of
              C.Halt => End

            | C.ExternVal (var, lab, _, _, e) =>
            (* XXX still not really sure how we interface with things here... *)
                Bind(vtoi var, Var lab, cvte e)

            | C.Letsham (v, va, e)    => cvtv va (fn ob => Bind (vtoi v, ob, cvte e))
            | C.Leta    (v, va, e)    => cvtv va (fn ob => Bind (vtoi v, ob, cvte e))
            | C.WUnpack (_, v, va, e) => cvtv va (fn ob => Bind (vtoi v, ob, cvte e))

            | C.TUnpack (_, dv, cvl, va, e) =>
                cvtv va
                (fn ob =>
                 (* select each component and bind... *)
                 Bind(vtoi dv, Project("d", ob),
                      let
                        fun eat _ nil = cvte e
                          | eat n ((cv, _) :: rest) =
                          Bind(vtoi cv, Project ("v" ^ itos n, ob), eat (n + 1) rest)
                      in
                        eat 0 cvl
                      end))

            | C.Go _ => raise ByteCodegen "shouldn't see go in codegen"
            | C.Go_cc _ => raise ByteCodegen "shouldn't see go_cc in codegen"
            | C.ExternWorld _ => raise ByteCodegen "shouldn't see externworld in codegen"

            | C.Primcall { var = v, sym, args, bod = e, ... } => 
                cvtvs args
                (fn args =>
                 Bind (vtoi v, Primcall (sym, args), cvte e))

            | C.Primop ([v], C.BIND, [va], e) =>
                cvtv va
                (fn va =>
                 Bind (vtoi v, va,  cvte e))

            | C.Primop (_, C.BIND, _, _) => raise ByteCodegen "bad bind"

            | C.Primop ([v], C.MARSHAL, [vd, vv], e) =>
                cvtv vd
                (fn vd =>
                 cvtv vv
                 (fn vv =>
                  Bind(vtoi v, Marshal(vd, vv), cvte e) ))

            | C.Primop (_, C.MARSHAL, _, _) => raise ByteCodegen "bad marshal"

            | C.Primop (_, C.SAY, _, _) => raise ByteCodegen "should not see SAY in codegen"
            | C.Primop ([v], C.SAY_CC, [va], e) => raise ByteCodegen "SAY_CC unimplemented on server (??)"
            | C.Primop (_, C.SAY_CC, _, _) => raise ByteCodegen "bad SAY_CC"

            | C.Primop ([v], C.LOCALHOST, nil, e) => Bind(vtoi v, String hostname, cvte e)

            | C.Primop (_, C.LOCALHOST, _, _) => raise ByteCodegen "bad localhost"

            | C.Native { var = v, args, bod = e, po, ... } => 
                (* XXX could check arity *)
                cvtvs args
                (fn args =>
                 Bind (vtoi v, Primop (po, args), cvte e))

            | C.Go_mar { w = _, addr, bytes } =>
                cvtv addr
                (fn addr =>
                 cvtv bytes
                 (fn bytes =>
                  Go (addr, bytes)))

            | C.Put (v, va : C.cval, e : C.cexp) =>
                (* just marks its universality; no effect *)
                cvtv va
                (fn va =>
                 Bind (vtoi v, va, cvte e))

            | C.Case (va, v, sel, def) =>
                cvtv va
                (fn va =>
                 Case { obj = va, 
                        var = vtoi v,
                        arms = ListUtil.mapsecond cvte sel,
                        def = cvte def })

            | C.ExternType (_, _, vso, e) => raise ByteCodegen "unimplemented externtype"

            | C.Call (f, args) => 
            (* XXX should instead put this on our thread queue. *)
                cvtv f 
                (fn fe =>
                 cvtvs args
                 (fn ae =>
                  Jump ( Project ("g", fe),
                         Project ("f", fe),
                         ae )))

                )

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
                FunDec ` Vector.fromList `
                map (fn (_, args, e) =>
                     (map (vtoi o #1) args,
                      cvte e)) fl

              | C.AllLam { worlds = _, tys =_, vals, body } => 
                OneDec (map (vtoi o #1) vals,
                        cvtv body Return)

            | _ => raise ByteCodegen ("expected label " ^ gen_lab ^ 
                                      " to be alllam then lams/alllam"))
              
       | _ => raise ByteCodegen ("expected label " ^ gen_lab ^ 
                                 " to be a (possibly empty) AllLam"))
    end
    | generate _ _ (lab, NONE) = Absent

end