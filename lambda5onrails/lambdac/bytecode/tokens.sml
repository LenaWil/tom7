
structure ByteTokens =
struct

    datatype token =
        ID of string
      | INT of IntConst.intconst
      | CHAR of char
      | FLOAT of real
      | STRING of string
      | BAD of char

      | BIND | END | JUMP | CASE | ERROR | RETURN
      | RECORD | PROJ | PRIMCALL | CALL | FUNDEC | ONEDEC | ABSENT
      | TNONE | TSOME | PROGRAM | INJ | GO | MARSHAL | PRIMOP

      | DCONT | DCONTS | DADDR | DDICT | DINT | DSTRING | DVOID | DAA | DREF | DW
      | DP | DREC | DSUM | DEXISTS | DALL | DMU | DLOOKUP | DAT | DSHAM

    (* only for "basic" tokens, not constant-wrappers *)
    fun eq (BIND, BIND) = true
      | eq (END, END) = true
      | eq (RETURN, RETURN) = true
      | eq (JUMP, JUMP) = true
      | eq (CASE, CASE) = true
      | eq (ERROR, ERROR) = true
      | eq (RECORD, RECORD) = true
      | eq (PROJ, PROJ) = true
      | eq (PRIMCALL, PRIMCALL) = true
      | eq (CALL, CALL) = true
      | eq (FUNDEC, FUNDEC) = true
      | eq (ONEDEC, ONEDEC) = true
      | eq (ABSENT, ABSENT) = true
      | eq (TNONE, TNONE) = true
      | eq (TSOME, TSOME) = true
      | eq (PROGRAM, PROGRAM) = true
      | eq (INJ, INJ) = true
      | eq (GO, GO) = true
      | eq (MARSHAL, MARSHAL) = true
      | eq (PRIMOP, PRIMOP) = true

      | eq (DCONT, DCONT) = true
      | eq (DCONTS, DCONTS) = true
      | eq (DADDR, DADDR) = true
      | eq (DAA, DAA) = true
      | eq (DDICT, DDICT) = true
      | eq (DINT, DINT) = true
      | eq (DSTRING, DSTRING) = true
      | eq (DVOID, DVOID) = true
      | eq (DREF, DREF) = true
      | eq (DP, DP) = true
      | eq (DREC, DREC) = true
      | eq (DSUM, DSUM) = true
      | eq (DEXISTS, DEXISTS) = true
      | eq (DALL, DALL) = true
      | eq (DMU, DMU) = true
      | eq (DLOOKUP, DLOOKUP) = true
      | eq (DAT, DAT) = true
      | eq (DW, DW) = true
      | eq (DSHAM, DSHAM) = true

      | eq _ = false

end