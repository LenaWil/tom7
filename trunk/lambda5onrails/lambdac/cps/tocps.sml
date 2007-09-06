(* Convert a finalized IL unit to CPS form.
   A finalized IL unit is allowed to make imports (from the "basis"),
   but these will not be higher order so they will be treated as primitive
   (direct-style leaf calls) during CPS conversion.

   A finalized IL unit's exports are meaningless, however, so we will
   discard those.

   This continuation-based CPS conversion algorithm is based on
   Appel's "Compiling with Continuations." It does not produce
   administrative redices because it uses the meta language to encode
   administrative continuations.

   We do "double-barreled CPS" to implement exceptions. We do this by
   maintaining an invariant that a modal variable called "handler" is
   always in scope at the current world. It is an exn continuation.
   Jumping to it invokes the nearest enclosing exception handler.
   
   *)

structure ToCPS :> TOCPS =
struct

    exception ToCPS of string

    open CPS
    structure I = IL
    structure V = Variable
    open CPSTypeCheck
    val nv = V.namedvar

    infixr 9 `
    fun a ` b = a b

    type env = context

    val handlervar = nv "handler"
    val handlerty = Cont' [Zerocon' EXN]

    fun primtype v =
      if V.eq(v, Initial.intvar) then Primcon'(INT, nil)
      else if V.eq(v, Initial.exnvar) then Primcon'(EXN, nil)
      else if V.eq(v, Initial.stringvar) then Primcon'(STRING, nil)
      else if V.eq(v, Initial.charvar) then Primcon'(INT, nil) (* chars become ints. *)
      else raise ToCPS ("unbound type variable " ^ V.tostring v)

    fun cvtw (G : env) (w : IL.world) : CPS.world =
      (case w of
         I.WEvar (ref (I.Bound w)) => cvtw G w
       | I.WEvar _ => raise ToCPS "unset world evar"
       | I.WVar v => W' v
       | I.WConst l => WC' l)

    fun cvtt (G : env) (t : IL.typ) : CPS.ctyp =
      case t of
        I.TVar v => 
          (* if this type is not bound, it had better be a prim *)
          ((ignore ` gettype G v;
            TVar' v) handle TypeCheck _ => primtype v)

      | I.Evar (ref (I.Bound t)) => cvtt G t
      | I.Evar _ => raise ToCPS "tocps/unset evar"
      | I.TAddr w => Addr' ` cvtw G w
      | I.Sum lal => Sum' (map (fn (l, NonCarrier) => (l, NonCarrier)
                                 | (l, Carrier { definitely_allocated,
                                                 carried }) =>
                                (l, Carrier { definitely_allocated=
                                              definitely_allocated,
                                              carried=cvtt G carried }))
                           lal)
      | I.TVec t => Primcon'(VEC, [cvtt G t])
      | I.TRec ltl => Product' ` ListUtil.mapsecond (cvtt G) ltl
      | I.Mu (i, vtl) => 
          let
            (* XXX for the purposes of cps conversion, we don't
               care if types are mobile, because we're not doing type-checking, right? *)
            val thismob = false
            val G = foldr (fn ((v, _), G) => bindtype G v thismob) G vtl
          in
            Mu' (i, map (fn (v, t) => (v, cvtt G t)) vtl)
          end
      | I.TCont t => Cont' [cvtt G t]
      | I.Arrow (_, dom, cod) => 
          Cont' (map (cvtt G) dom @ [Cont' [cvtt G cod], handlerty])
      | I.Arrows tl => 
          Conts' ` map (fn (_, dom, cod) => 
                        map (cvtt G) dom @ [Cont' [cvtt G cod], handlerty]) tl
      | I.TRef t => Primcon' (REF, [cvtt G t])

      | _ => 
          let in
            print "\nToCPSt unimplemented:";
            Layout.print (ILPrint.ttol t, print);
            raise ToCPS "unimplemented cvtt"
          end

    fun swap f = (fn (x, y) => f(y, x))

    (* idiomatically, $G ` exp
       returns exp along with the current world in G *)
    fun $G thing = (thing, worldfrom G)


    (* cps convert the IL expression e and pass the
       resulting value (along with its type and world) 
       to the continuation k to produce the final expression.
       *)
    fun cvte (G : env) (e : IL.exp) (k : env * cval * ctyp * world -> cexp) : cexp =
      (case e of
         I.Seq (e1, e2) => cvte G e1 (fn (G, _, _, _) => cvte G e2 k)
       | I.Let (d, e) => cvtd G d (fn G => cvte G e k)
       | I.Proj (l, _, e) => cvte G e (fn (G, v, rt, w) =>
                                       let val vv = nv "proj"
                                       in 
                                         case ctyp rt of
                                            Product ltl =>
                                              (case ListUtil.Alist.find op= ltl l of
                                                 NONE => raise ToCPS ("label " ^ l ^ 
                                                                      " not in product!")
                                               | SOME tt => 
                                                   let val G = bindvar G vv tt w
                                                   in
                                                     EProj' (vv, l, v, k (G, Var' vv, tt, w))
                                                   end)
                                          | _ => raise ToCPS "project from non-product"
                                       end)

       | I.Unroll e => cvte G e (fn (G, v, rt, w) =>
                                 (* for this kind of thing, we could just pass along
                                    Unroll' v to k, but that could result in code
                                    explosion if v is not small. Safer to just bind it... *)
                                 let val vv = nv "ur"
                                 in 
                                   case ctyp rt of
                                     Mu(i, vtl) =>
                                       (* ... *)
                                       let val t = unroll (i, vtl)
                                       in
                                         Bind' (vv, Unroll' v, 
                                                k (bindvar G vv t w, Var' vv, t, w))
                                       end
                                   | _ => raise ToCPS "unroll non-mu"
                                 end)

       | I.Letcc (v, t, e) =>
         let
           val t = cvtt G t
           val ka = nv "cc_arg"
         in
           (* reify the continuation as a lambda,
              called 'v' as the cont is *)
           Bind' (v, Lam' (nv "letcc_nonrec", 
                           (* one arg; the cont's input *)
                           [(ka, t)],
                           let
                             val G = bindvar G ka t ` worldfrom G
                           in
                             (* lam is continuation *)
                             k (G, Var' ka, t, worldfrom G)
                           end),
                  (* proceed, then throw to named continuation *)
                  let
                    val G = bindvar G v (Cont' [t]) ` worldfrom G
                    (* XXX handler? not obvious what to do here. *)
                    fun k (_, va, _, _) = Call' (Var' v, [va])
                  in
                    cvte G e k
                  end)
         end

       | I.Throw (ev, ek) =>
         cvte G ev (fn (G, vv, tv, wv) =>
                    cvte G ek
                    (fn (G, vk, tk, wk) =>
                     Call' (vk, [vv]) ))

       | I.Say e =>
         cvte G e (fn (G, v, _, w) =>
                   let val s = nv "s"
                   in Say' (s, v, k (bindvar G s (Zerocon' STRING) w,
                                     Var' s, Zerocon' STRING, w))
                   end)

       | I.Roll (t, e) => cvte G e (fn (G, v, rt, w) =>
                                    let 
                                        val t = cvtt G t
                                        val vv = nv "r"
                                    in 
                                      Bind' (vv, Roll'(t, v),
                                              k (bindvar G vv t w, Var' vv, t, w))
                                    end)

       | I.Inject (t, l, NONE) => let val vv = nv "inj_null"
                                      val w  = worldfrom G
                                      val t  = cvtt G t
                                  in Bind' (vv, Inj'(l, t, NONE),
                                            k (bindvar G vv t w, Var' vv, t, w))
                                  end
       | I.Inject (t, l, SOME e) =>
                                  cvte G e
                                  (fn (G, v, tt, w) =>
                                   let val vv = nv "inj"
                                       val t  = cvtt G t
                                   in
                                       Bind' (vv, Inj'(l, t, SOME v),
                                              k (bindvar G vv t w, Var' vv, t, w))
                                   end)
       (* PERF also bind? *)
       | I.Value v => 
              let val (va, t, w) = cvtv G v
              in k (G, va, t, w)
              end

       | I.App (e, el) =>
              let val cv = nv "call_res"
              in
                cvte G e
                (fn (G, v, ft, fw) =>
                 case ctyp ft of
                      Cont nil => raise ToCPS "nullary cont?"
                    | Cont l =>
                        (* the second to last argument is the continuation.
                           (the last is the dynamic handler). What type does it expect? *)
                          (case ctyp ` hd ` tl ` rev l of
                               Cont [kt] =>
                                   cvtel G el
                                   (fn (G, vsl) =>
                                    let val G = bindvar G cv kt fw
                                    in
                                        Call' (v, 
                                               map #1 vsl @ 
                                               (* nb. don't even bind unused arg. *)
                                               [Lam'(nv "k_nonrec", [(cv, kt)],
                                                     k (G, Var' cv, kt, fw)),
                                                (* and our current dynamic handler *)
                                                Var' handlervar])
                                    end)
                             | _ => 
                                   let in
                                     print "oops, in app:\n";
                                     Layout.print (CPSPrint.vtol v, print);
                                     print "\n\nlast arg should be cont:\n";
                                     Layout.print (Layout.listex "[" "]" "," (map CPSPrint.ttol l), print);
                                     print "\n";
                                     raise ToCPS "last arg should be cont!"
                                   end)
                    | _ => 
                             let in
                               print "Oops, not a cont:\n";
                               Layout.print (CPSPrint.ttol ft, print);
                               raise ToCPS "call non-cont"
                             end)
              end

       | I.Record lel =>
              let
                val (labs, exps) = ListPair.unzip lel
                val vv = nv "record"
              in
                cvtel G exps
                (fn (G, vtwl) =>
                 let 
                     val (vl, tl, _) = ListUtil.unzip3 vtwl
                     val rt = Product' ` ListPair.zip (labs, tl)
                     val rw = worldfrom G
                     val G = bindvar G vv rt rw
                 in
                     Bind' (vv, Record' ` ListPair.zip (labs, vl),
                            k (G, Var' vv, rt, rw))
                 end)
              end

       (* bind a new handler *)
       | I.Handle (e1, t, v, e2) =>
         let
           val joinv = nv "handle-join"
           val joina = nv "handle-res"
           val joint = cvtt G t
         in
           Bind' (joinv,
                  Lam'(nv "handle-join-nonrec",
                       [(joina, joint)],
                       k (G, Var' joina, joint, worldfrom G)),
                  (* Then, the new handler, which is v.e2 *)
                  Bind' (handlervar,
                         Lam'(nv "handler-nonrec",
                              [(v, Zerocon' EXN)],
                              cvte (bindvar G v (Zerocon' EXN) ` worldfrom G) e2
                                  (fn (_, hv, _, _) =>
                                   Call' (Var' joinv, [hv]))),
                         (* then, continue as usual *)
                         cvte G e1 (fn (_, rv, _, _) =>
                                    Call' (Var' joinv, [rv]))))
         end

       | I.Raise (_, e) =>
          cvte G e
          (fn (G, v, ft, fw) => 
           let in
             Call'(Var' handlervar, [v])
           end)

       (* this one is special because it does not return *)
       | I.Primapp (Primop.PHalt, [], _) => Halt'

       (* treat every primapp as an extern primcall with a source/source
          translation. *)
       (* XXX perhaps these should be translated in some IL phase...? *)
       | I.Primapp (po, el, tl) =>
              let
                (* assuming all prims are valid, otherwise we need an
                   optional world here. also, assuming all prims have
                   function type. *)
                val { worlds, tys, dom, cod } = Podata.potype po
                val vp = nv ("pores_" ^ Primop.tostring po)

                val tl = map (cvtt G) tl

                (* won't need dom again, don't bother fixing it *)
                val dom = ()
                (* but if this is polymorphic, need to get the actual return
                   type *)
                val cod = 
                  let
                    val G = foldr (fn (tv, G) => bindtype G tv false) G tys
                    val s = ListUtil.wed tys tl
                    val cod = cvtt G ` ElabUtil.ptoil cod
                  in
                    (* carry out substitutions *)
                    foldr (fn ((tv,t), cod) =>
                           CPS.subtt t tv cod) cod s
                  end
              in
                (* can support it easily, but there's no place in NATIVE
                   currently to supply arguments... *)
                if not (List.null worlds) 
                then raise ToCPS "unimplemented: primops with world args"
                else ();

                (* we end up generating a new import and lambda abstraction every time,
                   but this is fine since we'd probably like to inline it. *)
                cvtel G el
                (fn (G, vwtl) =>
                 (* PERF inline? *)
                 Native' { var = vp,
                           po = po, tys = tl,
                           args = map #1 vwtl, 
                           bod = 
                             (* if return type is unit, bind an actual unit
                                value (it will almost always be optimized away)
                                since we allow unit-returning primapps to
                                return nonsense results (javascript returns
                                undefined) *)
                             (case ctyp cod of
                                Product nil => 
                                  Bind' (vp, Record' nil,
                                         k (G, Var' vp, cod, worldfrom G))
                              | _ => k (G, Var' vp, cod, worldfrom G)) })
              end

       | I.Intcase (exp, arms, def) =>
           cvte G exp
           (fn (G, va, _, iw) =>
            let
              val joinv = V.namedvar "intcasejoin"
              val joina = V.namedvar "r"
                
              (* see below. *)
              val joint = ref (NONE : CPS.ctyp option)
              val def = cvte G def (fn (_, dv, t, dw) =>
                                    let in
                                      joint := SOME t;
                                      Call' (Var' joinv, [dv])
                                    end)
              val arms = map (fn (i, e) =>
                              (i, 
                               cvte G e
                               (fn  (_, ev, et, ew) =>
                                Call' (Var' joinv, [ev])))) arms
              val joint = 
                (case !joint of
                   NONE => raise ToCPS "intcase typ?!?"
                 | SOME tj => tj)
            in
              Bind' (joinv,
                     Lam' (V.namedvar "nonrec_intcase",
                           [(joina, joint)],
                           k (G, Var' joina, joint, iw)),
                     Intcase' (va, arms, def))
            end)

       | I.Sumcase (I.Sum t, exp, v, arms, def) => 
           cvte G exp
           (fn (G, va, sum, sw) =>
            let
              val joinv = V.namedvar "casejoin"
              val joina = V.namedvar "r"

              (* hmm... need to create join function, but we can't know its argument's type
                 until we know the type of the case arms. *)
              val joint = ref (NONE : CPS.ctyp option)
              (* the default expression; v not in scope there *)
              val def = cvte G def (fn (_, dv, t, dw) =>
                                    let in
                                      joint := SOME t;
                                      Call' (Var' joinv, [dv])
                                    end)
              val arms = map (fn (s, e) =>
                              let
                                (* we might bind the var v... *)
                                val G' = 
                                  (case ListUtil.Alist.find op= t s of
                                     NONE => raise ToCPS "branch not found in sumcase"
                                   | SOME I.NonCarrier => G
                                   | SOME (I.Carrier { carried, ... }) => 
                                       bindvar G v (cvtt G carried) (worldfrom G))
                              in
                                (s,
                                 cvte G' e
                                 (fn (_, ev, et, ew) =>
                                  (* could check et is same as in joint.. *)
                                  Call' (Var' joinv, [ev])))
                              end) arms

              val joint = 
                (case !joint of
                   NONE => raise ToCPS "sumcase typ?!?"
                 | SOME tj => tj)
            in
              Bind' (joinv,
                     Lam' (V.namedvar "nonrec_sumcase",
                           [(joina, joint)],
                           k (G, Var' joina, joint, sw)),
                     Case' (va, v, arms, def))
            end)

       (* XXX exceptions! *)
       | I.Get { addr, dest : IL.world, typ, body } =>
              let
                val dest = cvtw G dest
                val retah = nv "ret_addr_here"
                val reta = nv "ret_addr"
                val pv = nv "get_res"
                val mobtyp = cvtt G typ
                val srcw = worldfrom G
              in
                cvte G addr
                (fn (G, va, at, aw) =>
                 (* no check that at = Addr dest *)
                 Primop'([retah], LOCALHOST, nil, 
                         Put'(reta, Var' retah,
                              Go' (dest, va,
                                   let 
                                     val G = bindu0var G reta (Addr' srcw)
                                     val G = setworld G dest
                                   in
                                     cvte G body
                                     (fn (G, res, rest, resw) =>
                                      (* no check that resw = dest or rest = mobtyp *)
                                      Put' (pv, res,
                                            let val G = setworld G srcw
                                              val G = bindu0var G pv mobtyp
                                            in
                                              Go' (srcw, UVar' reta,
                                                   k (G, UVar' pv, mobtyp, srcw))
                                            end))
                                   end))))
              end

       | _ => 
         let in
           print "\nToCPSe unimplemented:\n";
           Layout.print (ILPrint.etol e, print);
           raise ToCPS "unimplemented"
         end)

    and cvtel (G : env) (el : IL.exp list) 
              (k : env * (cval * ctyp * world) list -> cexp) : cexp =
      (case el of 
         nil => k (G, nil)
       | e :: rest => cvte G e (fn (G, v, t, w) => 
                                cvtel G rest (fn (G, vl) => k (G, (v, t, w) :: vl)))
           )

    and cvtd (G : env) (d : IL.dec) (k : env -> cexp) : cexp =
      (case d of
         (* XXX check that world matches? *)
         I.Do e => cvte G e (fn (G, _, _, _) => k G)

       | I.ExternType (0, lab, v) => ExternType' (v, lab, NONE, k ` bindtype G v false)
       | I.ExternWorld (lab, kind) => ExternWorld' (lab, kind, k ` bindworldlab G lab kind)

       (* need to treat specially external calls like
              js.alert : string -> unit
          we aren't going to cps convert them!

          Later on when we see it in application position,
          we need to know to generate a primcall, not a CPS call.
          
          (but if it escapes, then we are screwed)

          so we need to generate a CPS-converted function that
          does a primcall to the underlying import, here.
          *)
       | I.ExternVal (I.Poly ({worlds, tys}, (l, v, t, wo))) =>
         (* The external must be of the following types:

            base type, including abstract types.
            [b1 * ... * bn] -> b0     where b0..bn are base types.
            or           b1 -> b0

            In particular we do not allow higher-order externals,
            since they would need to be CPS converted in order to
            work with our calling convention. *)
         let
           fun base (I.TVar v) = true
             | base (I.Evar (ref (I.Bound t))) = base t
             | base (I.Evar _) = raise ToCPS "externval/unset evar"
             | base (I.TAddr _) = true
             | base _ = false

           val G = foldr (fn (w, G) => bindworld G w) G worlds
           val G = foldr (fn (v, G) => bindtype G v false) G tys
         in
           case ILUtil.unevar t of
             (* don't care if it's total *)
             I.Arrow(_, [arg], cod) =>
               let 
                   val av = nv "pcarg"
                   val dom = cvtt G arg

                   (* this is contorted because of the weird special case of unary records
                      not actually being records *)
                   val (flatdom, primargs) = 
                     case ctyp dom of
                        Product ltl =>
                          let
                            val itl = ListUtil.mapfirst (fn l =>
                                                         case Int.fromString l of
                                                           NONE => raise ToCPS ("externval: record must be tuple: " ^ l)
                                                         | SOME i => i) ltl
                            val itl = ListUtil.sort (ListUtil.byfirst Int.compare) itl
                            fun istuple _ nil = true
                              | istuple n ((i, _) :: rest) = n = i andalso istuple (n + 1) rest
                          in
                            if length itl <> 1 andalso istuple 1 itl
                            then 
                              ListPair.unzip ` map (fn (l, t) => (t, Proj'(Int.toString l, Var' av))) itl
                            else raise ToCPS "externval: tuple is missing fields or unary?"
                          end
                      | _ => ([dom], [Var' av])

                   val cod = cvtt G cod
                   val r = nv (l ^ "_res")
                   val kv = nv "ret"

                   val lam =
                     Lam' (nv (l ^ "_notrec"), 
                           (* takes one arg, but might be a tuple *)
                           (* also needs to take return continuation, and (for uniformity, since
                              we never call it) the dynamic handler. *)
                           (av, dom) :: [(kv, Cont' [cod]), (nv "externval-handler-unused", handlerty)],

                           Primcall' { var = r, sym = l, dom = flatdom, cod = cod,
                                       args = primargs,
                                       bod = Call' (Var' kv, [Var' r]) })
                   val (t, va) =
                       case (worlds, tys) of
                           (nil, nil) => (Cont' (dom :: [Cont'[cod], handlerty]),
                                          lam)
                         | _ => (AllArrow' { worlds = worlds, tys = tys,
                                             vals = nil, body = Cont' (dom :: [Cont'[cod], handlerty]) },
                                 
                                 AllLam' { worlds = worlds, tys = tys,
                                           vals = nil, body = lam })
               in
                   case Option.map (cvtw G) wo of
                       NONE => Lift' (v, va, k (bindu0var G v t))
                     | SOME w => 
                         (* only generate leta/hold if this is remote *)
                         if world_eq (worldfrom G, w)
                         then Bind' (v, va, k (bindvar G v t w))
                         else Bindat' (v, w, va, k (bindvar G v t w))
               end
           | I.Arrow _ => raise ToCPS ("expected extern val, if arrow, to take exactly one arg: " ^ l)

           | b =>
               let 
                 val t = 
                   case (worlds, tys) of
                     (* XXX should probably bind world and type vars here,
                        but cvtt doesn't currently need 'em *)
                     (nil, nil) => cvtt G t
                   | _ => AllArrow' { worlds = worlds, tys = tys, 
                                      vals = nil, body = cvtt G t }
               in
                 if base b 
                 then 
                   case Option.map (cvtw G) wo of
                     NONE => ExternVal'(v, l, t, NONE, k (bindu0var G v t))
                   | SOME ww => ExternVal'(v, l, t, SOME ww, k (bindvar G v t ww))
                 else raise ToCPS ("unresolvable extern val because it is not of base type: " ^ l)
               end
         end

       | I.Bind (I.Val, I.Poly ({worlds = nil, tys = nil}, (v, t, e))) =>
         (* no poly -- just a val binding *)
         let val _ = cvtt G t
         in
           cvte G e
           (fn (G, va, t, w) => Bind' (v, va, k (bindvar G v t w)))
         end

       | I.Bind (I.Put, I.Poly ({worlds = nil, tys = nil}, (v, t, e))) =>
         (* no poly -- just a put binding *)
         let val _ = cvtt G t
         in
           cvte G e
           (fn (G, va, t, w) => Put' (v, va, k (bindu0var G v t)))
         end


       | I.Bind (b, I.Poly ({worlds, tys}, (v, t, I.Value va))) =>
         (* poly -- must be a value then *)
         let
           val (va, tt, ww) = 
             let
               val G = foldr (fn (wv, G) => bindworld G wv) G worlds
               val G = foldr (fn (tv, G) => bindtype G tv false) G tys
             in
               cvtt G t;
               cvtv G va
             end
           val tt =
             AllArrow' { worlds = worlds, tys = tys, 
                         vals = nil, body = tt }
           val G = case b of 
                     I.Val => bindvar G v tt ww
                   | I.Put => bindu0var G v tt

           val f = case b of
                     I.Val => Bind'
                   | I.Put => Put'

         in
           f (v,
              AllLam' { worlds = worlds, tys = tys, vals = nil,
                        body = va }, k G)
         end

       | I.Bind (_, _) => raise ToCPS "bind decl is polymorphic but not a value!"

       (* Probably letsham could be another bind? *)
       | I.Letsham (I.Poly ({worlds = nil, tys = nil}, (v, t, va))) => 
         let
           val _ = cvtt G t
           val (va, tt, ww) = cvtv G va
         in
           case ctyp tt of
             Shamrock (wv, tt) =>
               let val G = binduvar G v (wv, tt)
               in Letsham' (v, va, k G)
               end
           | _ => raise ToCPS "letsham(nil) of non-shamrock"
         end

       | I.Letsham (I.Poly ({worlds, tys}, (v, t, va))) => 
         (* When the var v is used, it will be applied to worlds and tys,
            so it must have AllArrow type. It also must be valid. Here we
            have a value that's Shamrocked and also polymorphic.

            Instead we have to produce something like

            lift v : all worlds,tys . t = alllam ws, ts . --valid value--

            We wouldn't be able to write this directly in the IL, since we only
            have a shamrock value and all we can really do is letsham that.
            Fortunately we have VLetsham to let us do this:

            lift v : all worlds, tys . t = alllam ws, ts. letsham v' = va in v'

            Ultimately since lift is a sham and then letsham, we have a bit
            of finagling here to put the quantifiers in the right place, but
            this has no dynamic cost.

            (Note: Since  1 Aug 2007 I don't use Lift since shamrock now binds
             a world, but the principle is the same.)

            *)
         (case
            let
              val G = foldr (fn (wv, G) => bindworld G wv) G worlds
              val G = foldr (fn (tv, G) => bindtype G tv false) G tys
              val _ = cvtt G t (* but we'll use the actual type instead *)
              val (va, tt, ww) = cvtv G va
            in
              (va, ctyp tt, ww)
            end
            of
              (va, Shamrock (wv, tt), ww) =>
                let
                  (* XXX since we know worlds and tys are non-nil (nils handled
                     above), this is obsolete *)
                  (* by invariant, we don't make totally empty allarrows or alllams. *)
                  fun AllArrowMaybe { worlds = nil, tys = nil, vals = nil, body } = body
                    | AllArrowMaybe x = AllArrow' x
                  fun AllLamMaybe { worlds = nil, tys = nil, vals = nil, body } = body
                    | AllLamMaybe x = AllLam' x

                  val tt =
                    AllArrowMaybe { worlds = worlds, tys = tys, 
                                    vals = nil, body = tt }
                  val G = binduvar G v (wv, tt)
                  val v' = V.alphavary v
                in
                      Letsham' (v,
                                Sham' (wv, AllLamMaybe { worlds = worlds, tys = tys, vals = nil,
                                                         body = VLetsham' (v', va, UVar' v') }),
                                k G)
                end
            | _ => raise ToCPS "letsham on non-shamrock")

       | _ => 
         let in
           print "\nToCPSd unimplemented:\n";
           Layout.print (ILPrint.dtol d, print);
           raise ToCPS "unimplemented dec in tocps"
         end)
   
    and cvtv (G : env) (v : IL.value) : cval * ctyp * world = 
      (case v of
         I.Int i => (Int' i, Zerocon' INT, worldfrom G)
       | I.String s => (String' s, Zerocon' STRING, worldfrom G)

       | I.Fns (fl : { name : V.var,
                       arg  : V.var list,
                       dom  : I.typ list,
                       cod  : I.typ,
                       body : I.exp,
                       inline : bool,
                       recu : bool,
                       total : bool } list) =>
           (* Each function now takes a new parameter,
              the return continuation; and another new
              parameter, the current exception handler. *)
           let
             val inline = List.all #inline fl

             val fl = map (fn { name, arg, dom, cod, body, inline, recu, total } =>
                           { name = name, arg = arg, dom = map (cvtt G) dom,
                             cod = cvtt G cod, body = body }) fl

             (* all bodies get to see all recursive conts *)
             val G = foldr (fn ({ name, dom, cod, ... }, G) =>
                            bindvar G name (Cont' (dom @ [ Cont' [cod], handlerty ])) (worldfrom G)
                            ) G fl

             fun onelam { name, arg, dom, cod, body } =
               let
                 val vk = nv "ret"
                 val a = ListPair.zip (arg @ [ vk,          handlervar ],
                                       dom @ [ Cont' [cod], handlerty ])

                 val G = foldr (fn ((v, t), G) => bindvar G v t (worldfrom G)) G a

               in
                 if length dom <> length arg then raise ToCPS "dom/arg mismatch"
                 else ();
                   
                 (
                   ( name, 
                     a, cvte G body (fn (G, va, _, _) => 
                                     Call'(Var' vk, [va])) ),
                   
                   dom @ [ Cont' [cod], handlerty ]

                   )
                   
               end

             val (lams, conts) = ListPair.unzip ` map onelam fl
           in
             (if inline
              then Inline' ` Lams' lams
              else Lams' lams,
              Conts' conts,
              worldfrom G)
           end

       | I.FSel (i, v) => 
           let val (va, t, w) = cvtv G v
           in
             case ctyp t of
               Conts all => (Fsel' (va, i), Cont' ` List.nth (all, i), w)
             | _ => raise ToCPS "fsel of non-conts"
           end

       | I.Sham (v, va) =>
           let 
             val start = worldfrom G
             val G = bindworld G v
             val G = setworld G ` W' v
             val (va, t, w) = cvtv G va
           in
             (Sham' (v, va), Shamrock' (v, t), start)
           end

       (* mono case *)
       | I.Polyvar { tys=nil, worlds = nil, var } => 
           let
             val (tt, ww) = getvar G var
           in
             (Var' var, tt, ww)
           end

       | I.Polyvar { tys, worlds, var } =>
           let
             val (tt, ww) = getvar G var
           in
             (case ctyp tt of
                AllArrow { worlds = ws, tys = ts, vals = nil, body } =>
                  if length ws = length worlds andalso length ts = length tys
                  then 
                    let val tys = map (cvtt G) tys
                        val worlds = map (cvtw G) worlds
                        (* apply types *)
                        val body1 = 
                          foldr (fn ((tv, t), ty) => subtt t tv ty)
                          body ` ListPair.zip (ts, tys)
                        (* apply worlds *)
                        val body2 =
                          foldr (fn ((wv, w), ty) => subwt w wv ty)
                          body1 ` ListPair.zip (ws, worlds)
                    in
                        (AllApp' { f = Var' var,
                                   worlds = worlds,
                                   tys = tys,
                                   vals = nil }, 
                         body2,
                         ww)
                    end
                  else raise ToCPS "polyvar worlds/ts mismatch"
              | _ => raise ToCPS "polyvar is not allarrow type")
           end

       (* mono case *)
       | I.Polyuvar { tys=nil, worlds = nil, var } => 
           let val (wv, t) = getuvar G var
           in
             (UVar' var, subwt (worldfrom G) wv t, worldfrom G)
           end

       | I.Polyuvar { tys, worlds, var } =>
           let
             val (wv, tt) = getuvar G var
             val tt = subwt (worldfrom G) wv tt
           in
             (* repeats above; should be abstracted perhaps *)
             case ctyp tt of
                AllArrow { worlds = ws, tys = ts, vals = nil, body } =>
                  if length ws = length worlds andalso length ts = length tys
                  then 
                    let val tys = map (cvtt G) tys
                        val worlds = map (cvtw G) worlds
                        (* apply types *)
                        val body1 = 
                          foldr (fn ((tv, t), ty) => subtt t tv ty)
                          body ` ListPair.zip (ts, tys)
                        (* apply worlds *)
                        val body2 =
                          foldr (fn ((wv, w), ty) => subwt w wv ty)
                          body1 ` ListPair.zip (ws, worlds)
                    in
                        (AllApp' { f = UVar' var,
                                   worlds = worlds,
                                   tys = tys,
                                   vals = nil }, 
                         body2,
                         worldfrom G)
                    end
                  else raise ToCPS "polyuvar worlds/ts mismatch"
              | _ => raise ToCPS "polyuvar is not allarrow type"
           end

       | I.VRoll (t, v) => 
           let 
             (* not checking *)
             val (va, tt, ww) = cvtv G v
           in
             (Roll' (cvtt G t, va), cvtt G t, ww)
           end

       | I.VInject (t, l, vo) => 
           let val t = cvtt G t
           in 
             (Inj' (l, t, 
                    (case Option.map (cvtv G) vo of
                       NONE => NONE
                     | SOME (va, _, _) => SOME va)),
              t,
              worldfrom G)
           end

       | _ => 
         let in
           print "\nToCPSv unimplemented:\n";
           Layout.print (ILPrint.vtol v, print);
           raise ToCPS "unimplemented"
         end)

    (* convert a unit *)
    fun cvtds nil G = Halt'
      | cvtds (d :: r) G = cvtd G d (cvtds r)

    fun convert (I.Unit(decs, _ (* exports *))) (I.WConst world) = 
         let
           val G = empty ` WC' world
           val G = bindvar G handlervar handlerty ` WC' world
           val ce = cvtds decs G
         in
           (* FIXME need the handler that purports to be here! *)
           Bind'(handlervar, Lam' (nv "nonrec-toplevel",
                                   [(nv "unused-exn", Zerocon' EXN)],
                                   Native' { var = nv "warn-unused",
                                             po = Primop.PCompileWarn "no top level handler installed", 
                                             tys = nil, args = nil,
                                             bod = Halt' }),
                 ce)
         end
      | convert _ (I.WVar _) = raise ToCPS "expected toplevel world to be a constant"
      | convert _ _ = raise ToCPS "unset evar at toplevel world"

    (* needed? *)
    fun clear () = ()
end
