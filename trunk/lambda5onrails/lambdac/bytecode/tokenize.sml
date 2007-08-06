
(* This is based on the tokenizer in the frontend.
   It should be massively simplified since many of these constructs
   are unnecessary for the deliberately simple bytecode concrete syntax. *)

structure ByteTokenize :> BYTETOKENIZE =
struct

  open ByteTokens

  open Parsing

  infixr 4 << >>
  infixr 3 &&
  infix  2 -- ##
  infix  2 wth suchthat return guard when
  infixr 1 ||

  val quotc = #"\"" (* " *)

  fun list x = [x]

  (* Report an error with its position. *)
  (* XXX should raise exception? *)
  fun error s pos = print (Pos.toString pos ^ ": " ^ s ^ "\n")
  fun warn pos s  = print ("Warning: " ^ Pos.toString pos ^ 
                           ": " ^ s ^ "\n")

  (* Succeeds if p succeeds at the current point, but doesn't
     consume anything. *)

  fun ahead p = lookahead p (fn _ => succeed ())

  (* Ignores the result of p *)

  fun ignore p = p return ()

  fun midchar #"_" = true
    | midchar #"'" = true
    | midchar #"-" = true
    | midchar #"." = true
    | midchar #"$" = true
    | midchar _ = false

  val isSymbolic = Char.contains "!%&$#+-/:<=>@\\~`^|*._'-$"

  (* these never appear as part of a longer identifier *)
  val isSep = Char.contains "(),{}; "

  fun identstartchar c = Char.isAlpha c orelse isSymbolic c
  fun identchar c = identstartchar c orelse Char.isDigit c 


  (* inside text, can write backslash, then space, then newline,
     and this is treated as a non-character. *)
  fun text_line_ender () =
      (literal #"\n" return [#"\n"]) ||
      (literal #"\\" && (repeat (literal #" " ||
                                 literal #"\t")) && literal #"\n" return nil)

  (* probably should have \r, \t, \x05, etc. 
     allows [brackets] because it is also used for text 
     also allows an escaped literal newline to act as
     no character at all, for multi-line string constants
     with no extra spaces *)
  val escapechar = 
    ((literal #"\\" >> literal quotc) ||
     (literal #"\\" >> literal #"[") ||
     (literal #"\\" >> literal #"]") ||
     (literal #"\\" >> literal #"\\") ||
     (literal #"\\" && literal #"r" return #"\r") ||
     (literal #"\\" && literal #"t" return #"\t") ||
     (literal #"\\" && literal #"n" return #"\n")) wth list
     || $text_line_ender

  val getchar = (satisfy (fn x => x <> quotc andalso x <> #"\\") wth list ||
                 escapechar)

  fun fromhex acc nil = acc
    | fromhex acc (h :: t) =
    fromhex (acc * 0w16 + (Word32.fromInt (StringUtil.hexvalue h))) t

  (* XXX overflows *)
  (* XXX get from IntConst *)
  val decimal = 
    (repeat1 (satisfy Char.isDigit))
    wth (Word32.fromInt o Option.valOf o Int.fromString o implode)

  val integer = 
    alt [literal #"0" >> literal #"x" >>
         (repeat1 (satisfy Char.isHexDigit))
         wth (fromhex 0w0),
         decimal]

  val insidechars = (repeat getchar) wth (implode o List.concat)

  val stringlit = 
    (literal quotc) >>
    ((insidechars << (literal quotc)) 
      guard error "Unclosed string or bad escape.")

  val char = ((literal #"?" >> (satisfy (fn x => x <> #"\\"))) ||
              (literal #"?" >> escapechar when (fn [c] => SOME c | _ => NONE)))

  val float = ((repeat  (satisfy Char.isDigit)) <<
               (literal #".")) &&
                  (repeat1 (satisfy Char.isDigit))
                  wth (fn (a, b) =>
                       (Option.valOf (Real.fromString 
                                      ("0." ^ (implode b)))) +
                       (case a of 
                            nil => 0.0
                          | _ => Real.fromInt 
                                (Option.valOf (Int.fromString 
                                               (implode a)))))

  val number = integer || (literal #"~" >> decimal) wth op~

  fun comment () = string [#"(",#"*"]
      && (repeat ($insideComment) && string [#"*",#")"]
          guard error "Unterminated comment.")

  (* Either a nested comment or a single character (which is not
     start of a nested comment or the comment terminator). *)

  and insideComment () =
      ignore ($comment)
         || any -- (fn #"*" => ahead (satisfy (fn x => x <> #")"))
                     | #"(" => ahead (satisfy (fn x => x <> #"*"))
                     | _    => succeed ())

  (* White space. *)

  val space = repeat (ignore ($comment) || ignore (satisfy Char.isSpace))

  val keywords =
      [ 
       ("BIND", BIND), 
       ("END", END),
       ("JUMP", JUMP),
       ("CASE", CASE),
       ("ERROR", ERROR),
       ("RECORD", RECORD),
       ("PROJ", PROJ),
       ("PRIMCALL", PRIMCALL),
       ("FUNDEC", FUNDEC),
       ("ABSENT", ABSENT),
       ("NONE", TNONE),
       ("SOME", TSOME),
       ("PROGRAM", PROGRAM),
       ("GO", GO),
       ("INJ", INJ),
       ("MARSHAL", MARSHAL),

       ("DCONT", DCONT),
       ("DCONTS", DCONTS),
       ("DADDR", DADDR),
       ("DDICT", DDICT),
       ("DINT", DINT),
       ("DSTRING", DSTRING),
       ("DVOID", DVOID),
       ("DAA", DAA),
       ("DREF", DREF),

       ("DP", DP),
       ("DREC", DREC),
       ("DSUM", DSUM),
       ("DEXISTS", DEXISTS),
       ("DALL", DALL),
       ("DMU", DMU),
       ("DLOOKUP", DLOOKUP),
       ("DAT", DAT),
       ("DW", DW),
       ("DSHAM", DSHAM)

       ]

  (* PERF could use hash table or other sub-linear search structure *)
  fun ident s =
      let
          fun id nil = ID s
            | id ((a,b)::t) = if a = s then b else id t
      in
          id keywords
      end

  val letters = satisfy identstartchar && repeat (satisfy identchar) wth op::

  val word = 
      alt [letters wth implode,
           (satisfy isSep) wth Char.toString]

  fun goodtoken () = space >> !! (alt [char wth CHAR,
                                       float wth FLOAT,
                                       number wth INT,
                                       stringlit wth (fn s => STRING s),

                                       word wth ident
                                       ])


  val token = 
      alt [$goodtoken,
           !! (space >> any wth BAD)]

end
