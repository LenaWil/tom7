
(* trivial recursive descent parser for sexps. *)
structure Parse =
struct

  exception Parse of string

  fun parse s =
    let

      datatype tok = << | >> | S of string | I of int | Q | A of string
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

      fun readstring () = raise Parse "unimplemented"
      fun readnum n =
        if !pos < size s
        then 
          let val c = (String.sub(s, !pos))
          in
            if numspec c
            then (pos := !pos + 1; readnum (n * 10 + (ord c - ord #"0")) )
            else n
          end
        else n

      fun readatom s =
        if !pos < size s
        then
          let val c = String.sub(s, !pos)
          in
            if atomspec c
            then (pos := !pos + 1; readatom (s ^ implode[c]))
            else s
          end
        else s

      (* reads the next token, advancing pos *)
      fun token () =
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
               then I (readnum 0)
               else if atomspec c
                    then A (readatom "")
                    else raise Parse "bad char")
          else NONE
        end

    in
      0
    end


end