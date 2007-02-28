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
   
   *)

structure ToCPS :> TOCPS =
struct

    exception ToCPS of string

    open CPS
    structure I = IL
    structure V = Variable
    val nv = V.namedvar

    infixr 9 `
    fun a ` b = a b

    datatype env = Env of { world : CPS.world }
      
    fun cvtw (G : env) (w : IL.world) : CPS.world =
      (case w of
         I.WEvar (ref (I.Bound w)) => cvtw G w
       | I.WEvar _ => raise ToCPS "unset world evar"
       | I.WVar v => W v)

    fun cvtt (G : env) (t : IL.typ) : CPS.ctyp =
      case t of
        I.TVar v => TVar' v
      | I.Evar (ref (I.Bound t)) => cvtt G t
      | I.Evar _ => raise ToCPS "tocps/unset evar"
      | I.TAddr w => Addr' ` cvtw G w
      | I.Sum lal => Sum' (map (fn (l, NonCarrier) => (l, NonCarrier)
                                 | (l, Carrier { definitely_allocated,
                                                 carried}) =>
                                (l, Carrier { definitely_allocated=
                                              definitely_allocated,
                                              carried=cvtt G carried }))
                           lal)
      | I.TVec t => Primcon'(VEC, [cvtt G t])
      | I.TRec ltl => Product' ` ListUtil.mapsecond (cvtt G) ltl
      | I.Mu (i, vtl) => Mu' (i, ListUtil.mapsecond (cvtt G) vtl)
      | _ => 
          let in
            print "ToCPSt unimplemented:";
            Layout.print (ILPrint.ttol t, print);
            raise ToCPS "unimplemented cvtt"
          end

    fun swap f = (fn (x, y) => f(y, x))

    (* cps convert the IL expression e and pass the
       resulting value to the continuation k to produce
       the final expression.
       *)
    fun cvte (G : env) (e : IL.exp) (k : env * cval -> CPS.cexp) : CPS.cexp =
      (case e of
         I.Seq (e1, e2) => cvte G e1 (fn (G, _) => cvte G e2 k)
       | I.Let (d, e) => cvtd G d (fn G => cvte G e k)
       | I.Proj (l, t, e) => cvte G e (fn (G, v) =>
                                       let val vv = nv "proj"
                                       in Proj' (vv, l, v, k (G, Var' vv))
                                       end)
       | I.Unroll e => cvte G e (fn (G, v) =>
                                 (* for this kind of thing, we could just pass along
                                    Unroll' v to k, but that could result in code
                                    explosion. Safer to just bind it... *)
                                 let val vv = nv "ur"
                                 in Primop' ([vv], BIND, [Unroll' v], k (G, Var' vv))
                                 end)
       | I.Roll (t, e) => cvte G e (fn (G, v) =>
                                    let val vv = nv "r"
                                    in Primop' ([vv], BIND, [Roll'(cvtt G t, v)], 
                                                k (G, Var' vv))
                                    end)
       | I.Inject (t, l, NONE) => let val vv = nv "inj_null"
                                  in Primop' ([vv], BIND, [Inj'(l, cvtt G t, NONE)],
                                              k (G, Var' vv))
                                  end
       | I.Inject (t, l, SOME e) =>
                                  cvte G e 
                                  (fn (G, v) =>
                                   let val vv = nv "inj"
                                   in
                                     Primop' ([vv], BIND, [Inj'(l, cvtt G t, SOME v)],
                                              k (G, Var' vv))
                                   end)
       (* XX also bind? *)
       | I.Value v => k (G, cvtv G v)
       | I.App (e, el) =>
              let val cv = nv "call_res"
              in
                cvte G e
                (fn (G, v) =>
                 cvtel G el
                 (fn (G, vl) =>
                  Call' (v, vl @ [Lam'(nv "k_unused", [cv],
                                       k (G, Var' cv))])
                  ))
              end

       | I.Record lel =>
              let
                val (labs, exps) = ListPair.unzip lel
                val vv = nv "record"
              in
                cvtel G exps
                (fn (G, vl) =>
                 Primop' ([vv], BIND, [Record' ` ListPair.zip (labs, vl)],
                          k (G, Var' vv)))
              end

       (* treat every primapp as an extern primcall. *)
       (* perhaps these should be translated in some IL phase... *)
       | I.Primapp (po, el, tl) =>
              let
                (* assuming all prims are valid, otherwise we need an
                   optional world here. also, assuming all prims have
                   function type. *)
                val I.Poly({worlds, tys}, (dom, cod)) = Podata.potype po
                val l = Podata.polab po
                val vp = nv ("primapp_" ^ l)
              in
                (* can support it easily, but there's no place in Primapp
                   currently to supply arguments! *)
                if not (List.null worlds) 
                then raise ToCPS "uhh, this primitive takes world arguments?"
                else ();

                (* we end up generating a new import and lambda abstraction every time,
                   but this is fine since we'd probably like to inline it. *)
                cvte G
                   (I.Let(I.ExternVal(I.Poly({worlds=worlds, tys = tys},
                                             (l, vp, I.Arrow(false, dom, cod), NONE))),
                          I.App(I.Value ` I.Polyuvar { tys = tl, 
                                                       worlds = nil,
                                                       var = vp },
                                el))) k
              end

       (* XXX typ necessary? (yes for put) *)
       | I.Get { addr, dest : IL.world, typ, body } =>
              let
                val dest = cvtw G dest
                val reta = nv "ret_addr"
                val pv = nv "get_res"
                val mobtyp = cvtt G typ
                val srcw = worldfrom G
              in
                cvte G addr
                (fn (G, va) =>
                 Primop'([reta], LOCALHOST, nil, 
                          Go' (dest, va,
                               let val G = setworld G dest
                               in
                                 (* XXX change world in G *)
                                 cvte G body
                                 (fn (G, res) =>
                                  Put' (pv, mobtyp, res,
                                        Go' (srcw, UVar' reta,
                                             k (setworld G srcw, UVar' pv))))
                               end)))
              end

       | _ => 
         let in
           print "ToCPSe unimplemented:";
           Layout.print (ILPrint.etol e, print);
           raise ToCPS "unimplemented"
         end)

    and worldfrom (Env { world, ... }) = world

    and setworld (Env { world = _ }) world = Env { world = world }

    and cvtel (G : env) (el : IL.exp list) (k : env * cval list -> CPS.cexp) : CPS.cexp =
      (case el of 
         nil => k (G, nil)
       | e :: rest => cvte G e (fn (G, v) => cvtel G rest (fn (G, vl) => k (G, v :: vl)))
           )

    and cvtd (G : env) (d : IL.dec) (k : env -> CPS.cexp) : CPS.cexp =
      (case d of
         I.Do e => cvte G e (fn (G, _) => k G)
       | I.ExternType (0, lab, v) => ExternType' (v, lab, k G)
       | I.ExternWorld (lab, v) => ExternWorld' (v, lab, k G)

       (* XXX need to figure out how we convert
          e.g. js.alert : string -> unit.
          we aren't going to cps convert it!

          Later on when we see it in application position,
          we need to know to generate a primcall, not a CPS call.
          
          (but if it escapes, then we are screwed)

          so we need to generate a CPS-converted function that
          does a primcall to the underlying import, here.
          *)
       | I.ExternVal (I.Poly ({worlds, tys}, (l, v, t, wo))) =>
         (* The external must be of the following types:

            base type, including abstract types.
            [b1, ..., bn] -> b0     whre b0..bn are base types.
         
            In particular we do not allow higher-order externals,
            since they would need to be CPS converted in order to
            work with our calling convention. *)
         let
           fun base (I.TVar v) = true
             | base (I.Evar (ref (I.Bound t))) = base t
             | base (I.Evar _) = raise ToCPS "externval/unset evar"
             | base (I.TAddr _) = true
             | base _ = false
         in
           case ILUtil.unevar t of
             (* don't care if it's total *)
             I.Arrow(_, args, cod) =>
               let val dom = map (cvtt G) args
                   val cod = cvtt G cod
                   val av = map (fn _ => nv "pcarg") args
                   val r = nv (l ^ "_res")
                   val kv = nv "ret"

                   val lam =
                     Lam' (nv (l ^ "_unused"), av @ [kv],
                           Primop'([r], PRIMCALL { sym = l, dom = dom, cod = cod },
                                   map Var' av,
                                   Call' (Var' kv, [Var' r])))
               in
                 Primop'([v], BIND, [foldr WLam' (foldr TLam' lam tys) worlds],
                         k G)
               end
           | b =>
               let val t = cvtt G t
               in
                 if base b 
                 then ExternVal'(v, l, foldr WAll' (foldr TAll' t tys) worlds,
                                Option.map (cvtw G) wo, k G)
                 else raise ToCPS ("unresolvable extern val because it is not of base type: " ^ l)
               end
         end

       | I.Val (I.Poly ({worlds = nil, tys = nil}, (v, t, e))) =>
         (* no poly -- just a val binding *)
         cvte G e
         (fn (G, va) =>
          Primop' ([v], BIND, [va], k G))

       | I.Val (I.Poly ({worlds, tys}, (v, t, I.Value va))) =>
         (* poly -- must be a value then *)
         Primop' ([v], BIND,
                  [foldr WLam' (foldr TLam' (cvtv G va) tys) worlds], k G)

       | _ => 
         let in
           print "ToCPSd unimplemented:\n";
           Layout.print (ILPrint.dtol d, print);
           raise ToCPS "unimplemented dec in tocps"
         end)
   
    and cvtv (G : env) (v : IL.value) : CPS.cval = 
      (case v of
         I.Int i => Int' i
       | I.String s => String' s
       | I.Fns (fl : { name : V.var,
                       arg  : V.var list,
                       dom  : I.typ list,
                       cod  : I.typ,
                       body : I.exp,
                       inline : bool,
                       recu : bool,
                       total : bool } list) =>
           (* Each function now takes a new final parameter,
              the return continuation. *)
           let
             fun onelam { name, arg, dom=_, cod=_, body, inline=_, recu=_, total=_ } =
               let
                 val vk = nv "ret"
               in
                   ( name, arg @ [ vk ], cvte G body (fn (G, va) => 
                                                      Call'(Var' vk, [va])) )
               end
           in
             Lams' (map onelam fl)
           end
       | I.FSel (i, v) => Fsel' (cvtv G v, i)
       | I.VRoll (t, v) => Roll' (cvtt G t, cvtv G v)
       | I.Polyvar { tys, worlds, var } =>
         foldr (swap TApp') (foldr (swap WApp') (Var' var) (map (cvtw G) worlds)) (map (cvtt G) tys)
       | I.Polyuvar { tys, worlds, var } => 
         foldr (swap TApp') (foldr (swap WApp') (UVar' var) (map (cvtw G) worlds)) (map (cvtt G) tys)
       | I.VInject (t, l, vo) => Inj' (l, cvtt G t, Option.map (cvtv G) vo)

       | _ => 
         let in
           print "ToCPSv unimplemented:\n";
           Layout.print (ILPrint.vtol v, print);
           raise ToCPS "unimplemented"
         end)

    (* convert a unit *)
    fun cvtds nil G = Halt'
      | cvtds (d :: r) G = cvtd G d (cvtds r)

    fun convert (I.Unit(decs, _ (* exports *))) (I.WVar world) = 
      cvtds decs (Env { world = W world })
      | convert _ _ = raise ToCPS "unset evar at toplevel world"

    (* needed? *)
    fun clear () = ()
end
