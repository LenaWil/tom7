
structure TFCompiler =
struct
  fun eprint s = TextIO.output(TextIO.stdErr, s)

  exception TFCompiler of string

  (* Everything in this file assumes the descriptions parsed
     have been checked for duplicates, dangling types, etc. *)
  structure D = DescriptionParser

  (* Generates the datatype declarations for the messages, which
     appear in both the signature and structure. *)
  fun gentypes l =
    let
        fun typetos D.Int = "int"
          | typetos D.String = "string"
            (* XXX can often leave out parens. *)
          | typetos (D.List t) = "(" ^ typetos t ^ ") list"
          | typetos (D.Option t) = "(" ^ typetos t ^ ") option"
          | typetos (D.Tuple nil) = "unit"
          | typetos (D.Tuple ts) =
            StringUtil.delimit " * " (map typetos ts)
          | typetos (D.Message m) = m

        fun onefield (D.F { name, token, typ }) =
            "      " ^ name ^ " : " ^ typetos typ

        fun one connective (D.M { name, token, fields } :: rest) =
            connective ^ " " ^ name ^ " = " ^ token ^ " of {\n" ^
            StringUtil.delimit ",\n" (map onefield fields) ^
            "\n    }\n\n" ^ one "  and" rest
          | one connective nil = ""
    in
        one "  datatype" l
    end

  (* Generate the structure declarations for the signature. *)
  fun genstructsigs l =
    let
       fun onestruct (D.M { name, token, fields }) =
         "  structure " ^ token ^ " :\n" ^
         "  sig\n" ^
         "    type t = " ^ name ^ "\n" ^
         "    val tostring : t -> string\n" ^
         "    val fromstring : string -> t\n" ^
         "    val maybefromstring : string -> t option\n" ^
         "\n" ^
         "    val tofile : string -> t -> unit\n" ^
         "    val fromfile : string -> t\n" ^
         "    val maybefromfile : string -> t option\n" ^
         "\n" ^
         "    val default : t\n" ^
         "  end\n"
    in
       StringUtil.delimit "\n" (map onestruct l)
    end

  fun genstructstructs l =
    let
       fun onestruct (D.M { name, token, fields }) =
         let
           (* Matches an instance of t, binds all its
              fields *)
           (* XXX this could shadow something we use inside tostring.
              maybe should rename them? *)
           val pattern = "(" ^ token ^ " { " ^
               StringUtil.delimit ", " (map (fn (D.F {name, ...}) => name) fields)
               ^ " })"
         in
           "\n" ^
           "  structure " ^ token ^ " =\n" ^
           "  struct\n" ^
           "    type t = " ^ name ^ "\n" ^
           "    fun tostring (" ^ pattern ^ " : t) : string =\n" ^
           "      raise Parse \"unimplemented\"\n" ^

           "\n" ^
           "    fun fromstring (s : string) : t =\n" ^
           "      raise Parse \"unimplemented\"\n" ^

           "\n" ^
           "    (* derived *)\n" ^
           "    val maybefromstring = maybefromstringwith fromstring\n" ^
           "    val tofile = tofilewith tostring\n" ^
           "    val fromfile = fromfilewith fromstring\n" ^
           "    val maybefromfile = maybefromfilewith fromstring\n" ^
           "    val default = raise Parse \"unimplemented\" \n" ^
           "  end\n"

         end
    in
       StringUtil.delimit "\n" (map onestruct l)
    end

  fun genexns () =
      "  exception Parse of string\n\n"

  fun geninternal () =
      "  (* Internal utilities. *)\n" ^
      "  fun readfile f =\n" ^
      "    let val l = TextIO.openIn f\n" ^
      "        val s = TextIO.inputAll l\n" ^
      "    in TextIO.closeIn l; s\n" ^
      "    end\n" ^
      "  fun writefile f s =\n" ^
      "   let val l = TextIO.openOut f\n" ^
      "   in  TextIO.output (l, s);\n" ^
      "       TextIO.closeOut l\n" ^
      "   end\n" ^

      (* We just need tostring and fromstring to implement the others. *)
      "  fun maybefromstringwith fs s =\n" ^
      "    (SOME (fs s)) handle Parse _ => NONE\n" ^
      "  fun fromfilewith fs f = fs (readfile f)\n" ^
      "  fun maybefromfilewith fs f =\n" ^
      "    (SOME (fs (readfile f))) handle Parse _ => NONE\n" ^
      "  fun tofilewith ts f t = writefile f (ts t)\n" ^
      "\n" ^

      (* Since we always have to be able to skip fields we don't
         know, basic parsing doesn't depend on the description.
         Start by turning it into this internal representation,
         then use the description to massage it into the concrete
         type. *)
      "  structure S = Substring\n" ^
      "  datatype fielddata' =\n" ^
      "      Int' of int\n" ^
      "    | String' of string\n" ^
      "    | List' of fielddata' list\n" ^
      "    | Message' of string * (string * fielddata') list\n" ^
      "  datatype token' =\n" ^
      "      LBRACE' | RBRACE' | LBRACK' | RBRACK'\n" ^
      "    | COMMA' | INT' of int | STRING' of string\n" ^
      "    | SYMBOL' of S.substring\n" ^
      "  type field' = string * fielddata'\n" ^

      (* Read fields from the head of the string; return them
         and anything that remains in the string. *)
      "  fun readfields (str : S.substring) : field' list * S.substring =\n" ^
      "    let\n" ^

      (* Any whitespace. *)
      "      fun whitespace #\" \" = true\n" ^
      "        | whitespace #\"\\n\" = true\n" ^
      "        | whitespace #\"\\t\" = true\n" ^
      "        | whitespace _ = false\n" ^

      "      fun isletter c = (ord c >= ord #\"a\" andalso ord c <= ord #\"z\")\n" ^
      "          orelse (ord c >= ord #\"A\" andalso ord c <= ord #\"Z\")\n" ^

      (* Digits or minus sign. *)
      "      fun numeric #\"-\" = true\n" ^
      "        | numeric c = ord c >= ord #\"0\" andalso ord c <= ord #\"9\"\n" ^

      (* Letters and digits. *)
      "      fun symbolic c = isletter c orelse\n" ^
      "        ord c >= ord #\"0\" andalso ord c <= ord #\"9\"\n" ^

      (* Read an int token. Assumes first character is - or digit. *)
      "      fun readint (s : S.substring) : token' * S.substring =\n" ^
      "        let val (f, s) = case S.sub (s, 0) of\n" ^
      "               #\"-\" => (~, S.triml 1 s)\n" ^
      (* Assume numeral. *)
      "             | _ => ((fn x => x), s)\n" ^
      "            val (intpart, rest) = S.splitl numeric s\n" ^
      "        in case Int.fromString (S.string intpart) of\n" ^
      "             NONE => raise Parse (\"Expected integer\")\n" ^
      "           | SOME i => (INT' (f i), rest)\n" ^
      "        end\n" ^

      (* Parse a symbol, assuming it starts with a letter. *)
      "      fun readsym (s : S.substring) : token' * S.substring =\n" ^
      "        let val (sympart, rest) = S.splitl symbolic s\n" ^
      "        in (SYMBOL' sympart, rest)\n" ^
      "        end\n" ^

      (* Read a string, assuming s starts with double quote *)
      "      fun readstring (s : S.substring) : token' * S.substring =\n" ^
      "        raise Parse \"unimplemented\"\n" ^

      (* Get the token at the head of the substring, or return NONE.
         Raises parse if a parse error is evident (like unclosed string). *)
      "      fun get_token (s : S.substring) :\n" ^
      "            (token' * S.substring) option =\n" ^
      "        let val s = S.dropl whitespace s\n" ^
      "        in if S.isEmpty s then NONE\n" ^
      "           else SOME (case S.sub (s, 0) of\n" ^
      "                  #\"}\" => (RBRACE', S.triml 1 s)\n" ^
      "                | #\"{\" => (LBRACE', S.triml 1 s)\n" ^
      "                | #\"]\" => (RBRACK', S.triml 1 s)\n" ^
      "                | #\"[\" => (LBRACK', S.triml 1 s)\n" ^
      "                | #\",\" => (COMMA', S.triml 1 s)\n" ^
      "                | #\"\\\\\" => readstring s\n" ^ (* " *)
      "                | c => if isletter c\n" ^
      "                       then readsym s\n" ^
      "                       else if numeric c\n" ^
      "                       then readint s\n" ^
      "                       else raise Parse (\"Unexpected character '\" ^\n" ^
      "                                         implode [c] ^ \"'\"))\n" ^
      "        end\n" ^
      "     in\n" ^
      "       raise Parse \"unimplemented\"\n" ^
      "     end\n"

  fun gensig ms =
      gentypes ms ^
      genexns () ^
      genstructsigs ms

  fun genstruct ms =
      gentypes ms ^
      genexns () ^
      geninternal () ^
      genstructstructs ms

  fun splitext s =
      StringUtil.rfield (StringUtil.ischar #".") s

  (* TODO: in dashed-filename, generate DashedFilename *)
  (* TODO: allow the description to specify this *)
  fun capitalize s =
      case explode s of
          h :: t => if ord h >= ord #"A" andalso
                       ord h <= ord #"Z"
                    then s
                    else if ord h >= ord #"a" andalso
                            ord h <= ord #"z"
                         then implode (chr (ord h - 32) :: t)
                         else raise TFCompiler ("The filename " ^ s ^
                                                " must start with a letter," ^
                                                " since it is used to generate" ^
                                                " the structure name.")
        | _ => raise TFCompiler "The file basename may not be empty (??)"

  fun go file =
    let
        val (base, ext) = splitext file
        val s = StringUtil.readfile file
        val () = eprint ("Parsing " ^ s ^ "\n")
        val (D.D messages) = D.parse s
        val () = eprint ("Parsed ok\n")

        val strname = capitalize base

        val s =
        "(* Generated from " ^ file ^ " by tfcompiler. Do not edit! *)\n\n" ^
        "structure " ^ strname ^ " :>\n" ^
        "sig\n" ^
        gensig messages ^
        "\nend =\n" ^
        "\n\n(* Implementation follows. *)\n" ^
        "struct\n" ^
        genstruct messages ^
        "\nend\n"
    in
        (* XXX *)
        print s;
        StringUtil.writefile (base ^ "-tf.sml") s
    end


  val () = Params.main1 "Takes a single argument, the input .tfdesc file." go
  handle e =>
      let in
          eprint ("unhandled exception " ^
                  exnName e ^ ": " ^
                  exnMessage e ^ ": ");
          (case e of
               D.DescriptionParser s => eprint s
             | SimpleTok.SimpleTok s => eprint s
             | TFCompiler s => eprint s
             | _ => ());
          eprint "\nhistory:\n";
          app (fn l => eprint ("  " ^ l ^ "\n")) (Port.exnhistory e);
          eprint "\n";
          OS.Process.exit OS.Process.failure
      end

end
