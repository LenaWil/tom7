
structure Highlight =
struct

  exception Highlight of string

  fun highlight (m : string) (n : string) (c : string) =
    let
      val target = "<polyline id=\"" ^ n (* " *)
      fun rfrom str start =
        case StringUtil.findat start target str of
          NONE => str
        | SOME x =>
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
    in
      rfrom m 0
    end


end
