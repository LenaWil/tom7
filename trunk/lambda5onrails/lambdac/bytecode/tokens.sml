
structure ByteTokens =
struct

    datatype token =
        ID of string
      | INT of IntConst.intconst
      | CHAR of char
      | FLOAT of real
      | STRING of string
      | BAD of char

      | BIND | END | JUMP | CASE | ERROR
      | RECORD | PROJ | PRIMCALL | FUNDEC | ABSENT 
      | TNONE | TSOME | PROGRAM | INJ

    (* only for "basic" tokens, not constant-wrappers *)
    fun eq (BIND, BIND) = true
      | eq (END, END) = true
      | eq (JUMP, JUMP) = true
      | eq (CASE, CASE) = true
      | eq (ERROR, ERROR) = true
      | eq (RECORD, RECORD) = true
      | eq (PROJ, PROJ) = true
      | eq (PRIMCALL, PRIMCALL) = true
      | eq (FUNDEC, FUNDEC) = true
      | eq (ABSENT, ABSENT) = true
      | eq (TNONE, TNONE) = true
      | eq (TSOME, TSOME) = true
      | eq (PROGRAM, PROGRAM) = true
      | eq (INJ, INJ) = true
      | eq _ = false

end