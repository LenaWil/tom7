(* Keep track of global records. The authoritative store is on the
   server. A synchronization process allows the client to send new
   high scores when updating.
   *)
structure Highscores =
struct
    
    (* The high scores file format is a series of lines of the form:
       
       midi-sha1   #misses   unix-epoch-time   urlencoded-band-name
       
       *)
    val HIGHSCORES = "highscores.hero"

    val scores = ref nil
    fun loadscores () =
        let
            val s = Script.linesfromfile HIGHSCORES handle _ => nil
         in
            
        end

end
