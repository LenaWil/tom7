(* Per-song records and medals *)
signature RECORD =
sig
    exception Record of string

    datatype recordtype =
        Misses of int
        (* only strummed up for the whole song *)
      | UpStrum
        (* never hammered a note (hard to measure?) *)
      | AuthenticStrummer
        (* never strummed a hammer note *)
      | AuthenticHammer
      | Percent of int

    (* ty, seconds since epoch *)
    type record = recordtype * IntInf.int

    (* XXX serialize *)
    val tostring : record -> string
    val fromstring : string -> record
end