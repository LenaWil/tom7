(* Keep track of global records. The authoritative store is on the
   server. A synchronization process allows the client to send new
   high scores when updating. Local records are scored in the profile
   database; we send only the ones that beat the global record to
   the server during synchronization. *)
(* XXX Should generalize this to allow more than one high score per
   song. The only thing that's tricky is knowing when a client-side
   record is good enough to send to the server, and there only mildly.
   Just make the scores ref before be a list map. *)
structure Highscores :> HIGHSCORES =
struct

    exception Highscores of string
    val screen = Sprites.screen
    structure SM = Setlist.Map

    (* The high scores file format is a series of lines of the form:
       
       midi-sha1   #misses   unix-epoch-time   urlencoded-band-name
       
       *)
    val HIGHSCORES = "highscores.hero"

    fun highscores_url () = 
        "http://spacebar.org/stuff/fakehighscores"
        (* XXX *)
        (* "http://t7es.spacebar.org/f/a/t7eshero/highscores" *)

    fun addhighscores_url () =
        "http://spacebar.org/f/a/t7eshero/addhighscores"

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

    (* Is this performance worthy of prompting and uploading to the server? *)
    fun is_new_record (sid : Setlist.songid, (name : string, 
                                              { percent = _,
                                                misses : int,
                                                medals = _ } : Record.record,
                                              when : IntInf.int)) : bool =
        case SM.find(!scores, sid) of
            NONE => true (* no global record for this song *)
          (* Only way to beat it is to get fewer misses. *)
          | SOME (mm, tt, nn) => misses < mm

    fun send_scores parent { progress, message } =
        let
            (* All local records. *)
            val loc : (Setlist.songid * 
                       (string * Record.record * IntInf.int)) list =
                Profile.local_records ()
            val loc = List.filter is_new_record loc
        in
            if List.null loc
            then Prompt.info parent "High scores synchronized!"
            else
                (* HERE Send to server.. *)
                raise Highscores "unimplemented"
        end

    (* get and write a new high scores file. *)
    fun update_with parent { progress : string * int * int option -> unit,
                             message : string -> unit } =
        case HTTP.get_url (highscores_url ()) (fn (got, total) =>
                                               progress ("high scores", got, total)) of
            HTTP.Success scoredata =>
                let in
                    StringUtil.writefile HIGHSCORES scoredata;
                    loadscores ();
                    message ("Read " ^ Int.toString (SM.numItems (!scores)) ^ " high scores.");

                    (* When updating, also send our new scores *)
                    send_scores parent { progress = progress, message = message }
                end
          | HTTP.NetworkFailure s => message ("Network failure: " ^ s)
          | HTTP.Rejected s => message ("Couldn't update high scores: " ^ s)

    structure TS = TextScroll(Sprites.FontSmall)

    fun update () =
        let
            (* XXX common with Update. Lots of this is pointlessly complicated
               because it is for fetching multiple files, but there is just
               one file, which is the high score server. *)
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
            fun message s = (lf := ""; TS.write ts s)
            fun thenredraw f x = (f x; redraw ())
        in
            (* XXX should probably prompt with failures? *)
            update_with this { progress = thenredraw show_progress,
                               message = thenredraw message };
            Prompt.info this "exiting highscores.update"
        end

end
