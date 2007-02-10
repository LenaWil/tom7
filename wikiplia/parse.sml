
(* trivial recursive descent parser for sexps. *)
structure Parse =
struct

  exception Parse of string

  fun parse s =
    let

      datatype tok = << | >> | S of string | I of IntInf.int | Q | A of string
      val numspec = StringUtil.charspec "0-9"
      val atomspec = StringUtil.charspec "A-Za-z-"

      val pos = ref 0
      (* eat whitespace, advancing pos *)
      fun whites () =
        if !pos < size s
        then (if StringUtil.whitespec (String.sub(s, !pos))
              then (pos := !pos + 1; whites ())
              else ())
        else ()

      fun readstring () =
        let
          val () = pos := !pos + 1
          val start = !pos
          fun reading () =
            if !pos < size s
            then
              let in
                print ("string [" ^ (String.substring(s, start, !pos - start)) ^ "] @ " ^ 
                                     Int.toString (!pos) ^ "\n");
              case String.sub(s, !pos) of
                #"\"" (* " *) => (case String.fromString (String.substring(s, start, !pos - start)) of
                                    NONE => raise Parse "bad string (escapes?)"
                                  | SOME str => (pos := !pos + 1; str))
              | #"\\" => (pos := !pos + 2; reading ())
              | c => (pos := !pos + 1; reading ())
              end
            else raise Parse "unclosed string"
        in
          reading ()
        end
        
      fun readnum n =
        if !pos < size s
        then 
          let val c = (String.sub(s, !pos))
          in
            if numspec c
            then (pos := !pos + 1; readnum (n * (IntInf.fromInt 10) + (IntInf.fromInt (ord c - ord #"0"))) )
            else n
          end
        else n

      fun readatom acc =
        if !pos < size s
        then
          let val c = String.sub(s, !pos)
          in
             print ("atom [" ^ acc ^ "] @ " ^ Int.toString (!pos)^ "\n");
            if atomspec c
            then (pos := !pos + 1; readatom (acc ^ implode[c]))
            else acc
          end
        else acc

      local
        val queue = ref nil
      in
          (* reads the next token, advancing pos *)
          fun token () =
            (* eat from replacement queue *)
            case !queue of
              h :: rest => (queue := rest; SOME h)
            | nil =>
                (* eat whitespace *)
                let in
                  whites ();
                  if !pos < size s
                  then
                    SOME
                    (case String.sub(s, !pos) of
                       #"(" => (pos := !pos + 1; <<)
                     | #")" => (pos := !pos + 1; >>)
                     | #"'" => (pos := !pos + 1; Q)
                     | #"\"" => S (readstring ()) (* " *)
                     | c =>
                       if numspec c
                       then I (readnum (IntInf.fromInt 0))
                       else if atomspec c
                            then A (readatom "")
                            else raise Parse "bad char")
                  else NONE
                end

          fun push t = queue := t :: !queue
      end

      (* parse an expression *)
      fun exp () =
        case token () of
          SOME (S s) => Bytes.String s
        | SOME Q => Bytes.Quote (exp ())
        | SOME (A s) =>
            (case ListUtil.Alist.find op= Bytes.prims s of
               NONE => raise Parse ("not a primitive: [" ^ s ^ "]")
             | SOME p => Bytes.Prim p)
        | SOME << =>
            (* eat expressions until >> *)
            let
              fun eat () =
                case token () of
                  SOME >> => nil
                | NONE => raise Parse "unbalanced parens"
                | SOME t => (push t; exp () :: eat ())
            in
              Bytes.List (eat ())
            end
        | SOME (I n) => Bytes.Int n
        | SOME >> => raise Parse "expected expression, got )"
        | NONE => raise Parse "unexpected end of stream.."

    in
      exp ()
    end

end