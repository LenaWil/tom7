(* Keep track of global records. The authoritative store is on the
   server. A synchronization process allows the client to send new
   high scores when updating.
   *)
structure Highscores (* XXX SIG *) =
struct

    exception Highscores of string
    val screen = Sprites.screen
    structure SM = Setlist.Map

    (* The high scores file format is a series of lines of the form:
       
       midi-sha1   #misses   unix-epoch-time   urlencoded-band-name
       
       *)
    val HIGHSCORES = "highscores.hero"

    fun highscores_url () = "http://t7es.spacebar.org/f/a/t7eshero/highscores"

    val scores = ref (SM.empty : (int * IntInf.int * string) SM.map)
    fun loadscores () =
        let
            val () = scores := SM.empty
            val s = Script.linesfromfile HIGHSCORES handle _ => nil
            val s = app
                (fn l =>
                 case String.tokens (StringUtil.ischar #" ") l of
                     [sha, misses, time, band] =>
                        (case (Setlist.fromstring sha,
                               Int.fromString misses,
                               IntInf.fromString time,
                               StringUtil.urldecode band) of
                             (SOME sha, SOME misses, 
                              SOME time, SOME band) => 
                             scores := SM.insert(!scores, sha, (misses, time, band))
                            | _ => print ("Bad high scores line: " ^ l ^ "\n"))
                   | _ => print ("Another bad high scores line: " ^ l ^ "\n")) s
        in
            ()
        end

    (* get_url url callback
       get the specified url from a remote host. Returned as a
       string. 
       callback is called periodically with the number of
       bytes received so far and the total size, if known.

       XXX needs a way to fail
       *)
    fun get_url (url : string) (callback : int * int option -> unit) : string =
        (case url of
             "http://t7eshero.spacebar.org/f/a/t7eshero/highscores" =>
                 "44A49EACEB959A2FDE97672520CBEA2B8AE7F3BA  6  1234567  my%20band\n"
           | url => 
             let in
                 callback (0, NONE);
                 print ("GET " ^ url ^ "\n");
                 callback (0, SOME 1000);
                 print ("XXX: Unimplemented: HTTP fetches!\n");
                 ("awesome   u    aaaaaaaaaaaaaaaa\n" ^
                  "garbage   u    *\n" ^
                  "cooool.txt  u  bbbbbbbbbbbbbbbb\n")
                 before
                 callback (1000, SOME 1000)
             end)

    (* get and write a new high scores file. *)
    fun update_with parent (callback : string * int * int option -> unit) =
        let
            val scoredata = get_url (highscores_url ()) (fn (a, b) =>
                                                         callback ("high scores", a, b))
            val () = StringUtil.writefile HIGHSCORES scoredata
            val () = loadscores ()

            (* All local records. *)
            val loc : (Setlist.songid * 
                       (string * Record.record * IntInf.int)) list =
                Profile.local_records ()
            (* Filter out ones that are beaten by the global high score table. *)
            fun isbest (sid, (name, {percent = _, misses, medals = _}, t)) =
                case SM.find(!scores, sid) of
                    NONE => true (* no global record for this song *)
                  (* Only way to beat it is to get fewer misses. *)
                  | SOME (mm, tt, nn) => misses < mm
            val loc = List.filter isbest loc
        in
            if List.null loc
            then Prompt.info parent "High scores synchronized!"
            else
                (* Send to server.. *)
                raise Highscores "unimplemented"
        end

    structure TS = TextScroll(Sprites.FontSmall)

    fun update () =
        let
            (* XXX common with Update *)
            (* Gotta turn off sound because we'll freeze otherwise during
               HTTP requests *)
            val () = Sound.all_off ()

            val lf = ref ""
            val ts = TS.make { x = 0, y = 0,
                               width = Sprites.gamewidth, 
                               height = Sprites.height,
                               bgcolor = SOME (SDL.color (0w0, 0w0, 0w0, 0w255)),
                               bordercolor = NONE }
                
            fun saysame file s = (if file = !lf
                                  then TS.rewrite
                                  else (lf := file; TS.write)) ts s
            fun draw () = 
                let in
                    SDL.fillrect (screen, 0, 0, Sprites.gamewidth, Sprites.height, 
                                  SDL.color (0w20, 0w30, 0w40, 0w255));
                    TS.draw screen ts
                end
            fun redraw () = (draw (); SDL.flip screen)
            val this = Drawable.drawable { draw = draw, 
                                           resize = Drawable.don't, 
                                           heartbeat = Drawable.don't }

            (* XXX display to SDL surface *)
            fun show_progress (file, i, NONE) = saysame file ("Get " ^ file ^ " @ " ^
                                                              Int.toString i ^ "\n")
              | show_progress (file, i, SOME t) = saysame file ("Get " ^ file ^ " @ " ^
                                                                Int.toString i ^ "/" ^
                                                                Int.toString t ^ "\n")
            fun show_draw x = (show_progress x; redraw ())
        in
            update_with this show_draw
        end

end
