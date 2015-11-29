(* Small minigame. *)
structure Minigame :> MINIGAME =
struct

  (* XXX clean up some of these copies that we don't need. *)
  datatype label = datatype Match.label
  exception Abort (* abort gameplay, return to menu *)
  exception Minigame of string

  structure MScene =
  struct
    fun clear () = ()
    fun settimesig (n, d) = ()
  end

  val itos = Int.toString
  val rtos = Real.fmt (StringCvt.FIX (SOME 2))

  val DRAWTICKS = (* 128 *) 12

  exception EarlyExit

  val screen = Sprites.screen

  val GAMEWIDTH = Sprites.gamewidth
  val paddlewidth = ref 64
  val paddlex = ref 0.0
  val paddle_dx = ref 0.0
  val PADDLEY = Sprites.height - 32
  val PADDLEHEIGHT = 18
  (* In pixels per frame *)
  val MAXSPEED = 1.5

  datatype ballstate =
    Normal
  | Disintegrating of int
  type ball = { x : real, y: real,
                dx : real, dy: real,
                c : SDL.color,
                state : ballstate }

  val balls = ref (nil : ball list)

  val BLACK = SDL.color (0w0, 0w0, 0w0, 0wxFF)
  val WHITE = SDL.color (0wxFF, 0wxFF, 0wxFF, 0wxFF)


  (* Like Play, we have some mutually recursive functions. *)

  (* This one is just responsible for making the music happen. *)
  fun loopplay cursor =
    let
      val nows = Song.nowevents cursor

      fun noteon (ch, note, vel, inst) =
        let in
          Womb.liteson[Vector.sub(Womb.leds,
                                  note mod Vector.length Womb.leds),
                       Vector.sub(Womb.lasers,
                                  note mod Vector.length Womb.lasers)];
          Sound.noteon (ch, note, Sound.midivel vel, inst)
        end
      fun noteoff (ch, note) =
        let in
          Womb.litesoff [Vector.sub(Womb.leds,
                                    note mod Vector.length Womb.leds),
                         Vector.sub(Womb.lasers,
                                    note mod Vector.length Womb.lasers)];
          Sound.noteoff (ch, note)
        end
      in
        List.app
        (fn (label, evt) =>
         case label of
           Music (inst, track) =>
             (case evt of
                MIDI.NOTEON(ch, note, 0) => noteoff (ch, note)
              | MIDI.NOTEON(ch, note, vel) => noteon (ch, note, vel, inst)
              | MIDI.NOTEOFF(ch, note, _) => noteoff (ch, note)
              | _ => print ("unknown music event: " ^ MIDI.etos evt ^ "\n"))
         (* otherwise no sound..? *)
         | Control =>
             (case evt of
                (* http://jedi.ks.uiuc.edu/~johns/links/music/midifile.html *)
                MIDI.META (MIDI.TEMPO n) => print ("TEMPO " ^ itos n ^ "\n")
              | MIDI.META (MIDI.TIME (n, d, cpc, bb)) =>
                  let in
                    MScene.settimesig (n, Util.pow 2 d)
                  end
              | _ => print ("unknown ctrl event: " ^ MIDI.etos evt ^ "\n"))
         | Bar _ => () (* could play metronome click? *)
         | Score _ => ())
          nows
      end

  (* This one emits balls so that they reach the paddle at the
     right moment. *)
  fun loopemit cursor =
    ()

  fun doinput () =
    case SDL.pollevent () of
      SOME e =>
        let in
          (case e of
             SDL.E_KeyDown { sym = SDL.SDLK_ESCAPE } => raise Abort
           (* Skip to end of song, for show emergencies. *)
           | SDL.E_KeyDown { sym = SDL.SDLK_n } => raise EarlyExit
           | SDL.E_Quit => raise Hero.Exit
           | e =>
               (* Currently, allow events from any device to be for
                  Player 1, since there is only one player. *)
               (case Input.map e of
                  SOME (_, Input.Axis (Input.AxisLR, r)) =>
                    let
                      (* in [-1, 1] *)
                      (* XXX dead zone near 0.5? *)
                      val dx = (r - 0.5) * 2.0
                    in
                      paddle_dx := dx * MAXSPEED
                    end

                (* Always allow drums I guess? *)
                | SOME (_, Input.Drum d) =>
                    Sound.setfreq(Sound.DRUMCH d,
                                  Vector.sub(Samples.default_drumbank, d),
                                  (* player drums are always max velocity *)
                                  Sound.midivel 127,
                                  Sound.WAVE_SAMPLER Samples.sid)
                (* Ignore other events *)
                | SOME _ => ()
                | NONE =>
                    (* only if not mapped *)
                    (case e of
                       (SDL.E_KeyDown { sym = SDL.SDLK_o }) =>
                         Sound.transpose := !Sound.transpose - 1
                     | (SDL.E_KeyDown { sym = SDL.SDLK_p }) =>
                         Sound.transpose := !Sound.transpose + 1
                     | _ => ())));
          doinput ()
        end
    | NONE => ()

  fun dodraw () =
    let in
      SDL.fillrect (screen, 0, 0, Sprites.width, Sprites.height, BLACK);

      SDL.fillrect (screen, Real.trunc (!paddlex), PADDLEY,
                    !paddlewidth, PADDLEHEIGHT,
                    WHITE);

      SDL.flip screen
    end

  (* Run once per tick. *)
  fun dophysics () =
    let in
      paddlex := !paddlex + !paddle_dx;
      (if !paddlex < 0.0 then paddlex := 0.0
       else if !paddlex + real (!paddlewidth) > real GAMEWIDTH
            then paddlex := real (GAMEWIDTH - !paddlewidth)
            else ());
      (* print ("paddlex: " ^ rtos (!paddlex) ^ "\n") *)
      ()
    end

  (* 60 fps *)
  val TICKS_PER_FRAME = 0w16
  fun loop (prev, prevframe, cursor) =
    let
      val now = SDL.getticks()
      val ticks = Word32.toIntX (now - prev)
    in
      (* print ("Ticks: " ^ itos ticks ^ "\n"); *)
      doinput ();
      Song.update ();
      loopplay cursor;
      Womb.heartbeat ();

      Util.for 0 (ticks - 1)
      (fn _ => dophysics ());

      let val prevframe =
        (if now - prevframe >= TICKS_PER_FRAME
         then (dodraw (); now)
         else prevframe);
      in
        if Song.done cursor
        then ()
        else loop (now, prevframe, cursor)
      end
    end handle EarlyExit => ()

  fun game song =
    let
      val tracks = Score.assemble song
      val () = Song.init ()
      val playcursor = Song.cursor 0 tracks
      val start = SDL.getticks()
    in
      dodraw ();
      loop (start, 0w0, playcursor)
    end handle EarlyExit => ()

end