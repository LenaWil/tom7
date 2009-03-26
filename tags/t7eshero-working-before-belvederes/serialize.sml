
(* Serialization utils. Generates and parses strings. *)
structure Serialize =
struct

    exception Serialize of string

    fun QQ #"?" = true
      | QQ _ = false

    fun uo f NONE = "-"
      | uo f (SOME x) = "+" ^ f x
    fun uno f "-" = NONE
      | uno f s =
        if CharVector.sub(s, 0) = #"+"
        then SOME (f (String.substring(s, 1, size s - 1)))
        else raise Serialize "bad option"

    val ue = StringUtil.urlencode
    val une = (fn x => case StringUtil.urldecode x of
               NONE => raise Serialize "bad urlencoded string"
             | SOME s => s)

    (* For readability of the serialized format, we can use different
       delimiters for different nested levels of lists. 
       
       A list serializer is
         * a non-alphanumeric separator string ss and nil string sn
           (sn is not a substring of ss nor vice versa)
         * a function f : string -> string and f' : string -> string 
           such that f(s) does not contain ss or sn for any s.
           and f'(f(s)) = s

       We can build such a serializer by specifying a ss and a
       non-alphanumeric escaping character ce (not appearing in ss)
       The single-character string ce becomes sn. In the encoded
       message, the escaping character indicates that a two-character
       hex sequence follows. *)

    fun list_serializer cs ce =
        let
            val cn = implode [ce]
            val () = if Option.isSome (StringUtil.find cn cs)
                     then raise Serialize "bad list serializer: ce in cs"
                     else ()

            (* to encode, we use the escape character to encode any substrings
               in the avoid list entirely as hex. (We only need to encode enough
               of the substring so that the substring doesn't appear, but it is
               somewhat trickier than that because we don't want to cause any other
               avoid string to appear by virtue of encoding, so we just totally
               encode.) *)
            val avoid = [implode [ce], cs]

            fun encoder (avoidme :: rest) s =
                let val sl = map (encoder rest) (StringUtil.sfields avoidme s)
                    val sep = String.concat(map (fn s => implode[ce] ^ s) (map (StringUtil.bytetohex o ord) (explode avoidme)))
                in StringUtil.delimit sep sl
                end
              | encoder nil s = s

            val encode = encoder avoid

            fun decode s =
                case String.fields (fn c => c = ce) s of
                    nil => raise Serialize "impossible fields"
                  | first :: hexleads =>
                        String.concat (first ::
                                       map (fn hx =>
                                            if size hx < 2
                                            then raise Serialize ("bad escaping (" ^ implode[ce] ^ hx ^ ")")
                                            else
                                                (* XXX check valid hex *)
                                                implode [chr (StringUtil.hexvalue (CharVector.sub(hx, 0)) * 16 +
                                                              StringUtil.hexvalue (CharVector.sub(hx, 1)))] ^
                                                String.substring(hx, 2, size hx - 2)) hexleads)

            fun ulist nil = cn
              | ulist l = StringUtil.delimit cs (map encode l)
            fun unlist s =
                if s = cn
                then nil
                else map decode (StringUtil.sfields cs s)
        in
            (ulist, unlist)
        end

    val (ulist, unlist) = list_serializer "?" #"%"

    fun expectopt err f s = 
        case f s of
            SOME r => r
          | NONE => raise Serialize ("error parsing: " ^ err)

end
