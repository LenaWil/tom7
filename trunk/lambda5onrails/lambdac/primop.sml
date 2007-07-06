
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

      (* string equality *)
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

      | PJointext of int

      | PPrint

      (* no-op, just bind *)
      | PBind

      (* UM I/O *)
      | PPutc
      | PGetc

      (* generate an exception tag, sequentially *)
      | PNewtag
      (* store and retrieve exception handler fn 
         (these need to be relativized to the current thread) *)
      | PSethandler
      | PGethandler

      (* no run-time effect; just produces compiletime
         warning if not dead *)
      | PCompileWarn of string

      (* Done *)
      | PHalt

      (* DEBUGGING! *)
      | PShowval

end