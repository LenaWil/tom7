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

    type env = int list (* XXX *)

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
                                 in Primop' (BIND, [Unroll' v], [vv], k (G, Var' vv))
                                 end)
       | _ => 
         let in
           print "ToCPSe unimplemented:";
           Layout.print (ILPrint.etol e, print);
           raise ToCPS "unimplemented"
         end)


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
       (* | I.ExternVal (lab, v,  =>  *)
       | _ => 
         let in
           print "ToCPSd unimplemented:";
           Layout.print (ILPrint.dtol d, print);
           raise ToCPS "unimplemented dec in tocps"
         end)
      
    and cvtv (G : env) (v : IL.value) : CPS.cval = 
      (case v of
         I.Int i => Int' i
       | I.String s => String' s
       | _ => 
         let in
           print "ToCPSv unimplemented:";
           Layout.print (ILPrint.vtol v, print);
           raise ToCPS "unimplemented"
         end)

    (* convert a unit *)
    fun cvtds nil G = Halt'
      | cvtds (d :: r) G = cvtd G d (cvtds r)

    fun convert (I.Unit(decs, _ (* exports *))) = cvtds decs []

    (* needed? *)
    fun clear () = ()
end
