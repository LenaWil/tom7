
structure Facebook :> ALGORITHM =
struct

    (* For facebook feeds, the description field contains the entire text
       of the post. There's a limit on the length of these, so it makes
       sense to just use the whole thing. *)
    fun algorithm { guid : string,
                    link : string option,
                    title : string,
                    description : string,
                    date : Date.date,
                    body : XML.tree list } : { url : string,
                                               title : string } option =
        let
            val author = 
                case RSS.getfirst "author" body of
                    NONE => "Facebook User"
                  | SOME a => a
            val link =
                case link of
                    NONE => "#"  (* should not happen *)
                  | SOME l => l
        in
            SOME { title =
                   "<a class=\"fbname\" href=\"" ^ link ^ "\">" ^ author ^ "</a> " ^
                   description,
                   url = link }
        end

end