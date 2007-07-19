
structure Highlight =
struct

  exception Highlight of string

  fun highlight (m : string) (n : string) (c : string) =
    let
      (* don't match whole id, since it may have a suffix :1, etc. *)
      val target = " id=\"" ^ n (* " *)
      fun rfrom str start =
        case StringUtil.findat start target str of
          NONE => str
        | SOME x =>
             (* next char must be : or ", not simply a prefix (Arlington vs. Arlington Heights) *)
             let val next = String.sub (str, x + size target)
             in
               if next = #":" orelse next = #"\"" (* " *)
               then
                 (case StringUtil.findat x "fill=\"#" (* " *) str of
                    NONE => raise Highlight "expected to find fill..."
                  | SOME y =>
                      let
                        val off = y + size "fill=\"#" (* " *)
                          
                        (* make new string, replacing old fill with c *)
                        val str = CharVector.tabulate (size str,
                                                       fn i =>
                                                       if i >= off
                                                          andalso i < off + 6
                                                       then String.sub(c, i - off)
                                                       else String.sub(str, i))
                      in
                        rfrom str off
                      end)
               else rfrom str (x + size target)
             end
    in
      rfrom m 0
    end


end
