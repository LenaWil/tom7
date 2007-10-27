
structure Passwd : PASSWD =
struct

   type entry = {login : string,
                 uid : int,
                 gid : int,
                 name : string,
                 home : string,
                 shell : string}

   exception Passwd of string

   (* XXX how about a fast dict here?
      some apps require a fast lookup by uid as well. *)

   (* XXX in the meantime, move-to-front is a good scheme *)
   type ('a, 'b) dict = ('a * 'b) list
   val empty = nil
   val insert = op ::

   val db = (ref nil) : (string, entry) dict ref

   fun parseline l =
        case String.fields (fn c => c = #":") l of
             [login, _, uid, gid, name, home, shell] =>
                ({login=login, uid=Option.valOf (Int.fromString uid), 
                  gid=Option.valOf (Int.fromString gid),
                  name=name, home=home, shell=shell} 
                    handle _ => raise Passwd "bad line in passwd file")
           | _ => raise Passwd "bad line in passwd file"

   fun readdb s =
        let
             val f = TextIO.openIn s

             fun go d =
               (* XXX didn't test; does inputLine now strip newlines? *)
                case TextIO.inputLine f of
                    NONE => d (* EOF *)
                  | SOME l => let val p = parseline l
                         in go (insert ((#login p, p),d))
                         end
             val dict = go empty
        in
             TextIO.closeIn f;
             db := dict
        end

    fun lookup s =
      let
        fun f ((login, entry)::t) = if s = login then SOME entry
                                    else f t
          | f nil = NONE
      in
        f (!db)
      end

    fun lookupuid u =
      let
        fun f ((_, entry : entry as {uid,...})::t) = 
              if u = uid then SOME entry
              else f t
          | f nil = NONE
      in
        f (!db)
      end

end
