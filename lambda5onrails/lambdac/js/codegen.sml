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

   A local reference is represented as an object with a field v, containing the value.
   A remote reference is represented as an integer.

   Dictionaries are represented as follows
 
    { w : tag, ... } where 

      tag (string)
      DP       p : c, C, a, d, i, s, v, r, or A, w
      DR       v : array of { l : String, v : Object }
      DS       v : array of { l : String, v : Object (maybe missing) }
      DM       m : Number, v : array of { s : String, v : Object }
      DE       d : String, v : array of Object
      DL       s : String  (lookup this var for typedict)
      DW       s : String  (lookup this var for worlddict)
      DA       s : array of String, w : array of String, v : Object
      D@       v : Object, a : String
      DH       d : bound String,  v : Object

   World dictionaries are represented as strings.
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
  structure P = Primop

  (* n.b. these must agree with runtime *)
  val codeglobal = Id.fromString "globalcode"
  (* val enqthread  = Id.fromString "lc_enq_thread" *)
  val enqthread = Id.fromString "lc_enq_yield"
  (* val yield      = Id.fromString "lc_yield" *)
  val recsleft   = Id.fromString "lc_recsleft"
  val go_mar     = Id.fromString "lc_go_mar"
  val marshal    = Id.fromString "lc_marshal"
  val saveentry  = Id.fromString "lc_saveentry"
  val runentry   = "lc_enter"
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

         (* assuming these are all small *)
         | C.WDict s => k ` String ` String.fromString s
         | C.Dict d => 
             let
(*

   Dictionaries are represented as follows
 
    { w : tag, ... } where 

      tag (string)
      DP       p : c, C, a, d, i, s, v, r, or A, w, e
      DR       v : array of { l : String, v : Object }
      DS       v : array of { l : String, v : Object (maybe missing) }
      DM       m : Number, v : array of { s : String, v : Object }
      DE       d : String, v : array of Object
      DL       s : String  (lookup this var for typedict)
      DW       s : String  (lookup this var for worlddict)
      DA       s : array of String, w : array of String, v : Object
      D@       v : Object, a : String
      DH       d : bound String,  v : Object
*)

               val s = String o String.fromString
                
               fun dict which rest = Object ` % (prop "w" (s which) ::
                                                 map (fn (a, b) => prop a b) rest)


               (* this is the set of locally bound dictionary variables.
                  we'll turn these into string lookups if we see them. *)

               val G = V.Set.empty
               fun cd G (C.Shamrock ((_, wd), t)) = 
                 let 
                   val G = V.Set.add(G, wd)
                 in
                   dict "DH" [("d", String ` vtos wd),
                              ("v", cdict G t)]
                 end
                 | cd G (C.Cont _)  = dict "DP" [("p", s"c")]
                 | cd G (C.Conts _) = dict "DP" [("p", s"C")]
                 | cd G (C.At (t, w)) = dict "D@" [("v", cdict G t),
                                                   ("a", cwdict G w)]
                 | cd G (C.Primcon (C.REF, [_])) = dict "DP" [("p", s"r")]
                 | cd G (C.Primcon (C.INT, nil)) = dict "DP" [("p", s"i")]
                 | cd G (C.Primcon (C.EXN, nil)) = dict "DP" [("p", s"e")]
                 | cd G (C.Primcon (C.STRING, nil)) = dict "DP" [("p", s"s")]
                 (* don't care what t is; all dicts represented the same way *)
                 | cd G (C.Primcon (C.DICTIONARY, [t])) = dict "DP" [("p", s"d")]
                 | cd G (C.TWdict _) = dict "DP" [("p", s"w")]
                 | cd G (C.Addr _) = dict "DP" [("p", s"a")]
                 | cd G (C.Mu (i, bdl)) =
                     let
                       (* all vars bound in all arms. *)
                       val G = foldl (fn (((_, v), _), G) => V.Set.add(G, v)) G bdl
                     in
                       dict "DM"
                       [("m", RealNumber ` real i),
                        ("v", Array ` % ` 
                         map (fn ((_, v), d) =>
                              SOME `
                              Object ` % [prop "s" ` String ` vtos v,
                                          prop "v" ` cdict G d]) bdl)]
                     end

                 | cd G (C.Sum stil) =
                   dict "DS"
                   [("v", Array ` % ` map (fn (l, d) =>
                                           SOME `
                                           Object ` % ((prop "l" ` s l) ::
                                                       (case d of
                                                          IL.NonCarrier => nil
                                                        | IL.Carrier { carried = d, ... } =>
                                                            [prop "v" ` cdict G d]))) stil)]
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

                 (* If static, then we just need to keep track of the type and world
                    variables that are bound. (Types are just for cleanliness at 
                    runtime. We should never have to marshal e.g. /\a. (int * a)) *)

                 | cd G (C.AllArrow {worlds, tys, vals = nil, body }) =
                         let
                           val worlds = map #2 worlds
                           val tys = map #2 tys
                           val G = foldl (fn (v, G) => V.Set.add(G, v)) G (worlds @ tys)
                         in
                           dict "DA" [("w", Array ` % ` map (SOME o String o vtos) worlds),
                                      ("s", Array ` % ` map (SOME o String o vtos) tys),
                                      ("v", cdict G body)]
                         end

                 (* if it is not static, then it is always represented as an int
                    (index into globals) *)
                 | cd G (C.AllArrow {worlds = _, tys = _, vals = _, body = _}) = dict "DP" [("p", s"A")]

                 | cd _ d = 
                 let in
                   print "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\n";
                   print "JSCG: unimplemented val\n";
                   Layout.print (CPSPrint.vtol ` C.Dict' d, print);
                   print "\nXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\n";

                   s"unimplemented"
                 end

               and cwdict G e =
                 case C.cval e of
                   C.WDict s => String ` String.fromString s
                 | C.UVar u => 
                         if V.Set.member (G, u)
                         then dict "DW" [("s", String ` vtos u)]
                         else Id ` vtoi u
                 | _ => raise JSCodegen "when converting dict, expected to see just wdicts and vars"

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

         | C.Inline va => cvtv va k

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

         | C.AllApp { f, worlds = _, tys = _, vals } => 
             (* f must be an integer; the index of a function in the globals that
                returns a value *)
             cvtv f
             (fn f =>
              cvtvs vals
              (fn vals =>
               wi (fn p => Bind (p, Call { func = Sele (Id codeglobal) f,
                                           args = %vals }) :: k ` Id p)))

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
         | C.WDictfor _ => raise JSCodegen "should not see wdictfor in js codegen"
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

             )


      and cvtvs (values : C.cval list) (k : Exp.t list -> Statement.t list) : Statement.t list =
           case values of 
             nil => k nil
           | v :: rest => cvtv v (fn (ve : Exp.t) =>
                                  cvtvs rest (fn (vl : Exp.t list) => k (ve :: vl)))

      val jstrue  = Object ` %[ Property { property = pn "t",
                                           value = String ` String.fromString "true" }]
      val jsfalse = Object ` %[ Property { property = pn "t",
                                           value = String ` String.fromString "false" }]

      fun primexp (P.B bo) [a, b] =
        let
          fun num bo = Binary {lhs = a, rhs = b, oper = bo}
          fun boo bo = Cond { test  = Binary {lhs = a, rhs = b, oper = bo},
                              thenn = jstrue,
                              elsee = jsfalse }
        in
          case bo of
             P.PTimes => num B.Mul
           | P.PPlus => num B.Add
           | P.PMinus => num B.Sub
           | P.PDiv => num B.Div
           | P.PMod => num B.Mod
           | P.PAndb => num B.BitwiseAnd
           | P.PXorb => num B.BitwiseXor
           | P.POrb => num B.BitwiseOr
           | P.PShl => num B.LeftShift
           | P.PShr => raise JSCodegen "is shr signed or unsigned?"
           | P.PCmp c =>
               (case c of
                  (* all numeric (ints), returning bool *)
                  P.PEq => boo B.StrictEquals
                | P.PNeq => boo B.StrictNotEquals
                | P.PLess => boo B.LessThan
                | P.PLesseq => boo B.LessThanEqual
                | P.PGreater => boo B.GreaterThan
                | P.PGreatereq => boo B.GreaterThanEqual)
        end
        | primexp (P.B _) _ = raise JSCodegen "wrong number of args to binary native primop"

        (* string operations *)
        | primexp P.PStringSubstring [s, start, len] = 
        (* substr is start/length, substring is start/end *)
        Call { func = Sel s "substr",
               args = %[start, len] }

        | primexp P.PStringReplace [s, d, t] =
        Call { func = Id ` $"lc_replace",
               args = %[s, d, t] }

        | primexp P.PStringSub [s, off] =
        Call { func = Sel s "charCodeAt",
               args = %[off] }
        (* length is a magic builtin property *)
        | primexp P.PStringLength [s] = Sel s "length"
        | primexp (P.PJointext 0) nil = String ` String.fromString ""
        | primexp (P.PJointext 1) [s] = s
        | primexp (P.PJointext n) (first :: rest) =
        (* (* PERF maybe would be better for 2? *)
             foldl (fn (next, sleft) => Binary { lhs = sleft, 
                                                 rhs = next, 
                                                 oper = B.Add (* is also string concat, sigh *) }) 
                   first rest
                   *)
        (* this should be faster: *)
        Call { func = Sel first "concat",
               args = % rest }

        | primexp P.PIntToString [i] = Call { func = Id ` $"lc_itos",
                                              args = %[i] }

        | primexp (P.PCompileWarn s) [] =
        let in
          print ("Warning: " ^ s ^ "\n");
          Object ` %nil
        end

        | primexp (P.PJointext _) _ = raise JSCodegen "jointext argument length mismatch"
        | primexp P.PEqs [s1, s2] = 
                   Cond { test  = Binary {lhs = s1, rhs = s2, oper = B.StrictEquals},
                          thenn = jstrue,
                          elsee = jsfalse }

        (* we don't actually yield (we'd need to grab the continuation to do
           so); we just set the recursion count to zero so the next yield is major *)
        | primexp P.PYield [] = Assign { lhs = Id recsleft, oper = AssignOp.Equals, rhs = RealNumber 0.0 }

        (* references *)
        | primexp P.PRef [init] = Object ` %[prop "v" init]
        | primexp P.PGet [obj]  = Sel obj "v"
        | primexp P.PSet [obj, va] = Assign { lhs = Sel obj "v", oper = AssignOp.Equals, rhs = va }

        | primexp po _ = raise JSCodegen ("unimplemented native primop " ^ Primop.tostring po)

      fun cvte exp : Statement.t list =
           (case C.cexp exp of
              C.Halt => [Return NONE]

            | C.ExternVal (var, lab, _, _, e) =>
                (* assume these are global javascript properties *)
                (Var ` %[(vtoi var, SOME (Id ` Id.fromString lab))]) :: cvte e

            | C.Letsham (v, va, e)    => cvtv va (fn ob => Bind (vtoi v, ob) :: cvte e)
            | C.Leta    (v, va, e)    => cvtv va (fn ob => Bind (vtoi v, ob) :: cvte e)
            | C.WUnpack (_, v, va, e) => cvtv va (fn ob => Bind (vtoi v, ob) :: cvte e)
            | C.Put     (v, va, e)    => cvtv va (fn ob => Bind (vtoi v, ob) :: cvte e)

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

            | C.Native {var = v, po, args, bod = e, ... } => 
                cvtvs args
                (fn args =>
                 Bind (vtoi v, primexp po args) :: cvte e)

            | C.Primcall { var = v, sym, args, bod = e, ... } =>
                cvtvs args
                (fn args =>
                 (* assuming sym has the name of some javascript function. *)
                 (* note: javascript "X -> unit" functions actually return
                    undefined. We might want to bind {} here if the domain
                    is unit. *)
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

            | C.Primop _ => raise JSCodegen "unimplemented or bad primop"

            | C.Say _ => raise JSCodegen "shouldn't see say in js codgen"
            | C.Say_cc (v, imps, k, e) =>
                cvtv k
                (* k is a closure:
                   { d  : dictionary (not used)
                     v0 : env
                     v1 : continuation } 

                   the continuation expects one argument (a javascript variable in scope here) 
                   for each of the imports.
                   *)
                (fn k =>
                 wi (fn f =>
                 wi (fn env =>
                 wi (fn c =>
                     Bind(env, Sel k "v0") ::
                     Bind(f,   Sel k "v1") ::
                     (* c is the identifier (int) for this delayed call *)
                     (* we could maybe use marshaling here to create the string,
                        but it is cheaper to just save it in a table and use
                        an integer to identify it, since this shouldn't leave the world. *)
                     Bind(c, 
                          Call { func = Id saveentry,
                                 args = %[Sel (Id f) "g",
                                          Sel (Id f) "f",
                                          (* give just the environment; call site will give other args *)
                                          Id env] }) ::
                     (* Array ` %[SOME ` Id env, SOME ` Object ` %nil]] }) :: *)
                     let
                       infix ++ 
                       fun a ++ b = Binary { lhs = a, rhs = b, oper = B.Add }
                     in
                       Bind(vtoi v, (String ` String.fromString (runentry^"(")) ++ 
                                    (* then, the integer that results from evaluating this variable *)
                                    (Id c) ++ 
                                    (String ` 
                                     String.fromString (",{" ^
                                                        StringUtil.delimit "," 
                                                        (ListUtil.mapi (fn ((s, t), i) =>
                                                                        "l" ^ Int.toString (i + 1) ^ ":" ^ s)
                                                         (* Note: once this handler returns, the event
                                                            dies (loses its properties). we can't copy out
                                                            the whole object, because 'for i in' is 
                                                            NS_NOT_IMPLEMENTED in Firefox. So we need to
                                                            grab exactly those fields that we want, right here. 
                                                            
                                                            Now we pull event.keyCode (etc.) as the imports
                                                            rather than the event itself.  - 20 Sep 2007
                                                            *)
                                                         imps) ^ "})")
                                     ))
                     end :: cvte e

                     ))))

            | C.Go_mar { w = _, addr, bytes } =>
                cvtv addr
                (fn addr =>
                 cvtv bytes
                 (fn bytes =>
                  (* implemented in runtime. *)
                  [Exp ` Call { func = Id go_mar,
                                args = %[addr, bytes] }]
                  ))

            | C.Intcase (va, iel, def) => 
                cvtv va
                (fn va =>
                 [Switch { test = va,
                           clauses = %(map (fn (i, e) =>
                                            (* silly that we have to go through real numbers here,
                                               but they can represent all of the 32-bit values... *)
                                            (SOME ` RealNumber ` IntConst.toReal i,
                                             %[Block ` % ` (cvte e @ [Break NONE])])) iel @
                                       [(NONE, %[Block ` % ` (cvte def @ [Break NONE])])]) }
                 ])

            | C.Case (va, v, sel, def) => 
                cvtv va
                (fn va =>
                 (* bind variable to inner value first. If there's no value (because it's a
                    nullary constructor) then it just failceeds and the variable will have
                    value "undefined" 

                    NOTE: we rely on 'v' not being free in the default.

                    XXX: if this is exhaustive, we should not generate the default
                    (it generates compile-time warnings and larger code)
                    *)
                [Bind(vtoi v, Sel va "v"),
                 Switch { test = Sel va "t",
                          clauses = %(map (fn (s, e) =>
                                           (SOME ` String ` String.fromString s,
                                            %[Block ` % ` (cvte e @ [Break NONE])])) sel @
                                      [(NONE, %[Block ` % ` (cvte def @ [Break NONE])])]) }
                 ]
                 )

            (* we don't care about the type, but we'll need its dictionary. *)
            | C.ExternType (_, _, NONE, _) => raise JSCodegen ("externtype w/o dict?")
            | C.ExternType (_, _, SOME (var, lab), e) =>
                (Var ` %[(vtoi var, SOME (Id ` Id.fromString lab))]) :: cvte e

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
                                         Array ` % ` map SOME ` ae] }
                   (*
                   ,
                   (* must yield since threadcount has increased *)
                   (* XXX maybe this should be in enqthread? *)
                   Exp ` Call { func = Id yield,
                                args = %[] }
                   *)
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
         (* always a static wrapper, maybe empty *)
         C.AllLam { worlds = _, tys = _, vals = nil, body } =>
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

            | C.AllLam { worlds = _, tys =_, vals, body } => 
                Function { args = % ` map (vtoi o #1) vals,
                           name = NONE,
                           body = % ` cvtv body (fn v => [Return ` SOME v]) }

            | _ => raise JSCodegen ("expected label " ^ gen_lab ^ 
                                    " to be alllam then lams/alllam"))

         | _ => raise JSCodegen ("expected label " ^ gen_lab ^ 
                                 " to be a (possibly empty)" ^ 
                                 " static AllLam"))
    end
    | generate _ (lab, NONE) = 
    Function { args = %[],
               name = NONE,
               body = %[Throw ` String ` 
                        String.fromString "wrong world"] }

end