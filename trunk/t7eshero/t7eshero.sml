
(* Tom 7 Entertainment System Hero! *)

(* FIXME On Windows, Check that SDL_AUDIODRIVER is dsound otherwise
   this is unusable because of latency *)

structure T7ESHero =
struct

  val Hero = Hero.Hero
  val Exit = Hero.Exit

  val messagebox = Hero.messagebox

  (* just enable all joysticks. If there are no joysticks, then you cannot play. *)
  val () = Input.register_all ()
  val () = Input.load () handle Input.Input s => messagebox ("input file error: " ^ s)
  val () = Items.load ()

  structure Title = TitleFn(val screen = Sprites.screen)

  (* The game loop shows the title, plays the selected show,
     then returns back to the title. *)
  fun gameloop () =
  let
      (* Clear stats whenever we return to the title. Stats
         only span a series of songs in a show. *)
    val () = Stats.clear ()
    val () = State.reset ()

    val { show : Setlist.showinfo, 
          profile : Profile.profile } = Title.loop ()


    fun doshow nil = ()
      | doshow ((Setlist.Song { song = songid, misses, drumbank, background }) :: rest) =
       (let
            (* Need to have a song in effect. *)
            val () = Stats.push songid

            (* XXX should pull these out of the song as needed, I think? *)
            val song = Setlist.getsong songid
            (* val songid = #id song *)
            val SLOWFACTOR = #slowfactor song

            val (divi, thetracks) = Game.fromfile (#file song)
            val divi = divi * SLOWFACTOR
            val PREDELAY = 2 * divi (* ?? *)

            val (tracks : (int * (Match.label * MIDI.event)) list list) = 
                Game.label PREDELAY SLOWFACTOR thetracks
            val tracks = Game.slow SLOWFACTOR (MIDI.merge tracks)
            val tracks = Game.add_measures divi tracks
            val tracks = Game.endify tracks
            val (tracks : (int * (Match.label * MIDI.event)) list) = 
                Game.delay PREDELAY tracks
            val () = Song.init ()
            val playcursor = Song.cursor 0 tracks
            val drawcursor = Song.cursor (0 - Play.Scene.DRAWLAG) tracks
            val failcursor = Song.cursor (0 - Match.EPSILON) tracks

                (* XXX *)
            val t = print ("This will take " ^ 
                           Real.fmt (StringCvt.FIX (SOME 1)) 
                           (real (MIDI.total_ticks tracks) / 1000.0) ^
                           " sec\n")

            val () = Play.loop (playcursor, drawcursor, failcursor)

        in
            doshow rest
        end )
      (* | doshow (Setlist.Postmortem :: rest) = *)
            (* Get postmortem statistics *)
            (* val () = Postmortem.loop (songid, profile, tracks) *)

    val () = doshow (#parts show)
                handle Play.Abort =>
                    let in
                        (* should go FAILURE!!!! *)
                        ()
                    end
  in
      Womb.signal nil;
      Sound.all_off ();
      Sound.seteffect 0.0;
      print "GAME END.\n";
      (* XXX highscores... *)
      gameloop () 
  end 

  (* and, begin. *)
  val () = gameloop ()
      handle Hero.Hero s => messagebox ("hero error: " ^ s)
           | SDL.SDL s => messagebox ("sdl error: " ^ s)
           | Game.Game s => messagebox ("sdl error: " ^ s)
           | Items.Items s => messagebox ("items database error: " ^ s)
           | Input.Input s => messagebox ("input subsystem error: " ^ s)
           | Hero.Exit => ()
           | e => messagebox ("Uncaught exception: " ^ exnName e ^ " / " ^ exnMessage e)
end
