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

    (* cps convert the IL expression e and
       
       *)
    fun cvte (e : IL.exp) (k : cval -> CPS.exp) : CPS.exp =
      (case e of
         I.Seq (e1, e2) => cvte e1 (fn _ => cvte e2 k)
       | _ => raise ToCPS "unimplemented")


    and cvtd (d : IL.dec) (k : unit -> CPS.exp) : CPS.exp =
      (case d of
         I.Do e => cvte e (fn _ => k ())
       | _ => raise ToCPS "unimplemented dec in tocps")
      
    and cvtv ? = raise ToCPS "unimplemented"

    (* convert a unit *)
    fun cvtds nil () = Halt
      | cvtds (d :: r) () = cvtds d (cvtds r)

    fun convert (Unit(decs, _ (* exports *))) = cvtds decs ()

    (* needed? *)
    fun clear () = ()
end
