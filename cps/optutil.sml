
structure CPSOptUtil :> CPSOPTUTIL =
struct

    open CPS
    open Primop

    exception CPSOptUtil of string

    fun noeffect p =
        case p of
          (* compares are not effect-free, since they choose 
             one of two continuations to follow! *)
            PGethandler => true
          | PBind => true
          | PGet => true

          | PNewtag => true

          (* perhaps add the effectless arithmetic operations, if we
             decide on arbitrary-precision arithmetic. *)

          (* since I don't do overflow checking, everything but
             div and mod are indeed effect-free *)

          | _ => false

    (* bogus, because we should check for overflow and div/0 *)
    fun evalints po (a : CPS.intconst) b =
        case po of
            PPlus => SOME (Int (a + b))
          | PTimes => SOME (Int (a * b))
          | PDiv => if b = 0w0 then NONE 
                    else SOME (Int (a div b))
          | PMinus => SOME (Int (a - b))

          | _ => NONE

    fun evalcmp po (a : CPS.intconst) b =
        case po of
            PEq => a = b
          | PNeq => a <> b
          | PLess => a < b
          | PLesseq => a <= b
          | PGreater => a > b
          | PGreatereq => a >= b

end