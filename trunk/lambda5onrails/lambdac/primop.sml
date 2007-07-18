
structure Primop =
struct

    datatype compare =
        PEq
      | PNeq
      | PLess
      | PLesseq
      | PGreater
      | PGreatereq

    (* nb: all operations are UNSIGNED, including comparisons
       (XXX5 actually we have not resolved this for ML5)
       *)

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

  (* base types that describe arguments to and return values from primops *)
  datatype potype =
    PT_INT | PT_STRING | PT_REF of potype | PT_UNITCONT | PT_BOOL | PT_VAR of Variable.var
  | PT_UNIT

end