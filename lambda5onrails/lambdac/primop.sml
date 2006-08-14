
structure Primop =
struct

    datatype compare =
        PEq
      | PNeq
      | PLess
      | PLesseq
      | PGreater
      | PGreatereq

    (* things of int * int -> _ *)
    datatype binop =
        PTimes
      | PPlus
      | PMinus
      | PDiv
      | PMod
      | PAndb
      | PXorb
      | POrb
      | PShl
      | PShr
      | PCmp of compare

    datatype primop =
      (* primitive arithmetic stuff *)
        B of binop
      | PNeg

      (* string concatenation: string * string -> string *)
(*      | PConcat *)

      (* non-int compares *)
      | PEqs

      | PNotb

      (* is it zero? *)
      | PNull (* two branches: yes-null/not-null *)

      (* references: can compile these as 1-length arrays *)
      | PSet
      | PGet
      | PRef

      (* arrays and vectors use these *)
      | PArray
      | PArray0
      | PSub
      | PUpdate
      | PArraylength

      | PJointext

      | PPrint

      (* no-op, just bind *)
      | PBind

      (* UM I/O *)
      | PPutc
      | PGetc

      (* generate an exception tag, sequentially *)
      | PNewtag
      (* store and retrieve exception handler fn *)
      | PSethandler
      | PGethandler

      (* no run-time effect; just produces compiletime
         warning if not dead *)
      | PCompileWarn of string

      (* read from dynamic region *)
      | PDynamic

      (* Done *)
      | PHalt

      (* DEBUGGING! *)
      | PShowval

    type cpsprimop = primop

    (* nb: all operations are UNSIGNED, including comparisons *)
    (* XXX this should probably be factored out *)
    fun tostring (B PTimes) = "Times"
      | tostring (B PPlus) = "Plus"
      | tostring (B PMinus) = "Minus"
      | tostring (B PDiv) = "Div"
      | tostring (B PMod) = "Mod"
      | tostring (B (PCmp PEq)) = "Eq"
      | tostring (B (PCmp PNeq)) = "Neq"
      | tostring (B (PCmp PLess)) = "Less"
      | tostring (B (PCmp PLesseq)) = "Lesseq"
      | tostring (B (PCmp PGreater)) = "Greater"
      | tostring (B (PCmp PGreatereq)) = "Greatereq"

      | tostring (PNull) = "Null"

      | tostring (B PAndb) = "Andb"
      | tostring (B PXorb) = "Xorb"
      | tostring (B POrb) =  "Orb"
      | tostring (B PShl) = "Shl"
      | tostring (B PShr) = "Shr"

      | tostring PNotb = "Notb"

      | tostring PEqs = "Eqs"

      | tostring PPrint = "Print"

      | tostring PNeg = "Neg"

      | tostring PSet = "Set"
      | tostring PGet = "Get"
      | tostring PRef = "Ref"

(*      | tostring PConcat = "Concat" *)

      | tostring PArray = "Array"
      | tostring PArray0 = "Array0"
      | tostring PSub = "Sub"
      | tostring PUpdate = "Update"
      | tostring PArraylength = "Arraylength"
      | tostring PJointext = "Jointext"

      | tostring PBind = "Bind"
      | tostring PNewtag = "Newtag"
      | tostring PGethandler = "Gethandler"
      | tostring PSethandler = "Sethandler"

      | tostring (PCompileWarn s) = "Warn(" ^ s ^ ")"
      | tostring PDynamic = "Dynamic"

      | tostring PPutc = "Putc"
      | tostring PGetc = "Getc"

      | tostring PHalt = "Halt"

      | tostring PShowval = "(DEBUG:ShowVal)"

end