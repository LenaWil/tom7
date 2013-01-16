
(* Reads a textformat description, turning it in to the
   data structure. *)
structure DescriptionParser (* XXX sig *) =
struct

  exception DescriptionParser of string

  structure ST = SimpleTok

  datatype token =
      SYMBOL of string
    | MESSAGE
    | FIELD
    | LPAREN
    | RPAREN
    | COLON
    | EQUALS
    | ASTERISK
    | LIST
    | OPTION
    | INT
    | STRING

  val tokenizer =
      let val t = ST.empty () : token ST.tokenizer
          val t = ST.settokens t [("message", MESSAGE),
                                  ("field", FIELD),
                                  ("(", LPAREN),
                                  (")", RPAREN),
                                  (":", COLON),
                                  ("=", EQUALS),
                                  ("*", ASTERISK),
                                  ("list", LIST),
                                  ("int", INT),
                                  ("string", STRING),
                                  ("option", OPTION)]
          val t = ST.setsep t (Char.contains "()=*:")
          val t = ST.setother t SYMBOL
          val t = ST.setcomment t [ST.CSBracketed ("(*", "*)")]
      in
          ST.parser t
      end

  datatype typ =
      Int
    | String
    | List of typ
    | Tuple of typ list
    | Option of typ
    | Message of string

  datatype description =
      D of message list

  and message =
      (* TODO: explicitly retired fields *)
      (* TODO: layout hints *)
      M of { token : string, name : string, fields : field list }

  and field =
      F of { token : string, name : string, typ : typ }

  local
    open Parsing
    infixr 4 << >>
    infixr 3 &&
    infix  2 -- ##
    infix  2 wth suchthat return guard when
    infixr 1 ||

    fun **(s, p) = p ##
        (fn pos => raise DescriptionParser ("@" ^ Pos.toString pos ^ ": " ^ s))
    infixr 4 **

    (* as `KEYWORD -- punt "expected KEYWORD KEYWORD2" *)
    fun punt msg _ = msg ** fail

    val ` = literal

    val symbol = maybe (fn (SYMBOL s) => SOME s | _ => NONE)

    fun innertyp () =
        alt [`INT return Int,
             `STRING return String,
             symbol wth Message,
             `LPAREN && `RPAREN return Tuple nil,
             `LPAREN >> $typ << `RPAREN]

    and typ () =
        (* Avoid exponential parse (I think?) with left recursion *)
        $innertyp --
        (fn t =>
         alt
         [repeat1 (`ASTERISK >> $typ) wth (fn l => Tuple (t :: l)),
          `LIST return List t,
          `OPTION return Option t,
          succeed t])

    fun field () = `FIELD >>
        symbol &&
        opt (`LPAREN >> symbol << `RPAREN) &&
        (`COLON >>
         $typ) wth
        (fn (token, (name, typ)) =>
         let val name = case name of NONE => token | SOME n => n
         in F { token = token, name = name, typ = typ }
         end)
        || (`FIELD --
            punt "expected symbol [LPAREN symbol RPAREN] COLON typ after FIELD")

    val message = `MESSAGE >>
        symbol &&
        opt (`LPAREN >> symbol << `RPAREN) &&
        (`EQUALS >>
         repeat ($field)) wth
        (fn (token, (name, fields)) =>
         let val name = case name of NONE => token | SOME n => n
         in M { token = token, name = name, fields = fields }
         end)
      || (`MESSAGE --
          punt "expected symbol [LPAREN symbol RPAREN] EQUALS fields after MESSAGE")

  in
    val parser = message
  end

  structure SM = SplayMapFn(type ord_key = string
                            val compare = String.compare)

  (* Check that there are no duplicates (message or field tokens).
     Check that any Message type refers to a message defined in this bundle.
     TODO: This can be relaxed. Field names only need to be unique within
     a message.
     TODO: Support retired fields, check that too. *)
  fun check nil = raise DescriptionParser ("Currently there must be at least " ^
                                           "one message.")
    | check (ms : message list) =
    let
        val messagenames : unit SM.map ref = ref SM.empty
        fun insertunique what (m, s) =
            case SM.find (!m, s) of
                NONE => m := SM.insert (!m, s, ())
              | SOME () =>
                    raise DescriptionParser ("Duplicate " ^ what ^
                                             ": " ^ s)

        val messagetokens : unit SM.map ref = ref SM.empty

        fun checktype Int = ()
          | checktype String = ()
          | checktype (Tuple ts) = app checktype ts
          | checktype (Option t) = checktype t
          | checktype (List t) = checktype t
          | checktype (Message m) =
            case SM.find (!messagenames, m) of
                SOME () => ()
              | NONE => raise DescriptionParser
                    ("Unknown message name " ^ m ^
                     " in type (must be defined in this description).")

        fun onefield (F { name, token, typ }) =
            let
                val tokens : unit SM.map ref = ref SM.empty
                val names  : unit SM.map ref = ref SM.empty
            in
                insertunique "field token" (tokens, token);
                insertunique "field name" (names, token);
                checktype typ
            end

        fun onemessage (M { name, token, fields }) =
            let in
                insertunique "message token" (messagetokens, token);
                app onefield fields
            end
    in
        (* Get these up front because they are used for checking types.
           All other duplicate checking just happens the second time
           we see that symbol. *)
        app (fn M { name, ... } =>
             insertunique "message name" (messagenames, name)) ms;
        app onemessage ms
    end

  fun tokenize (s : string) =
    let
        val s = ST.stringstream s
        val s = Pos.markstream s
        val s = Parsing.transform tokenizer s
    in
        Stream.tolist s
    end

  fun parse (s : string) =
    let
        val s = ST.stringstream s
        val s = Pos.markstream s
        val s = Parsing.transform tokenizer s
        (* XXX should report original file positions! *)
        val s = Pos.markany s
        val s : message Stream.stream = Parsing.transform parser s
        val messages = Stream.tolist s
    in
        check messages;
        D messages
    end

end
