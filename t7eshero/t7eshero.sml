
(* Tom 7 Entertainment System Hero! *)

(* XXX On Windows, Check that SDL_AUDIODRIVER is dsound otherwise
   this is unusable because of latency *)

structure T7ESHero =
struct

  val Hero = Hero.Hero
  val Exit = Hero.Exit

  val messagebox = Hero.messagebox

  (* Just enable all joysticks. If there are no joysticks, then you
     cannot play. *)
  val () = Input.register_all ()
  (* This restores configuration of joysticks that are plugged in. *)
  val () = Input.load ()
    handle Input.Input s => messagebox ("input file error: " ^ s)
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

    val level = ref 0
    val total_levels =
      foldr (fn (Setlist.Song _, n) => n + 1 | (_, n) => n) 0 (#parts show)

    fun doshow nil = ()
      | doshow ((Setlist.Song { song = songid, misses,
                                drumbank, background }) :: rest) =
       (let
          val () = level := !level + 1
          (* should be done by conscientious predecessor *)
          val () = Sound.all_off ()
          (* Need to have a song in effect. *)
          val () = Stats.push songid
          val song = Setlist.getsong songid

          (* XXX can move a bunch of this into Play itself. *)
          val () = Play.Scene.background := background
          val () = Play.Scene.initfromsong (song, !level, total_levels)

          val tracks = Score.assemble song

          val () = Song.init ()
          val playcursor = Song.cursor 0 tracks
          val drawcursor = Song.cursor (0 - Play.Scene.DRAWLAG) tracks
          val failcursor = Song.cursor (0 - Match.EPSILON) tracks

          (* XXX *)
          val t = print ("This will take " ^
                         Real.fmt (StringCvt.FIX (SOME 1))
                         (real (MIDI.total_ticks tracks) / 1000.0) ^
                         " sec\n")

          val () = Play.setmiss misses
          val () = Play.loop (playcursor, drawcursor, failcursor)

          val () = Stats.finish tracks profile

          val () = Sound.all_off ()
          val () = Sound.seteffect 0.0
        in
          doshow rest
        end)
      | doshow (Setlist.Postmortem :: rest) =
          if Stats.has ()
          then
            let in
              (* Get postmortem statistics *)
              Postmortem.loop ();
              Stats.clear ();
              doshow rest
            end
          else doshow rest
      | doshow (Setlist.Wardrobe :: rest) =
          let in
            Wardrobe.loop profile;
            Sound.all_off();
            doshow rest
          end
      | doshow (Setlist.Interlude (m1, m2) :: rest) =
          let in
            Interlude.loop profile (m1, m2);
            Sound.all_off();
            doshow rest
          end
      | doshow (Setlist.Command Setlist.WombOn :: rest) =
          let in
            Womb.enable();
            doshow rest
          end
      | doshow (Setlist.Command Setlist.WombOff :: rest) =
          let in
            Womb.signal_raw 0w0;
            Womb.disable();
            doshow rest
          end
      | doshow (Setlist.Minigame { song = songid, misses,
                                   drumbank, background } :: rest) =
          let in
            (* XXX unimplemented *)
            ();
            doshow rest
          end

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
         | Score.Score s => messagebox ("score error: " ^ s)
         | Items.Items s => messagebox ("items database error: " ^ s)
         | Input.Input s => messagebox ("input subsystem error: " ^ s)
         | Postmortem.Postmortem s => messagebox ("postmortem problem: " ^ s)
         | Hero.Exit => ()
         | e => messagebox ("Uncaught exception: " ^
                            exnName e ^ " / " ^ exnMessage e)
end
