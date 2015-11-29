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

  val DRAWTICKS = (* 128 *) 12

  exception EarlyExit

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
                  SOME (_, Input.ButtonDown b) => State.fingeron b
                | SOME (_, Input.ButtonUp b) => State.fingeroff b
                (* Always allow drums I guess? *)
                | SOME (_, Input.Drum d) =>
                    Sound.setfreq(Sound.DRUMCH d,
                                  Vector.sub(Samples.default_drumbank, d),
                                  (* player drums are always max velocity *)
                                  Sound.midivel 127,
                                  Sound.WAVE_SAMPLER Samples.sid)
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
    SDL.flip Sprites.screen

  fun loop cursor =
    let in
      doinput ();
      Song.update ();
      loopplay cursor;
      Womb.heartbeat ();
      dodraw ();

      if Song.done cursor
      then ()
      else loop cursor
    end handle EarlyExit => ()

  fun game song =
    let
      val tracks = Score.assemble song
      val () = Song.init ()
      val playcursor = Song.cursor 0 tracks
    in
      loop playcursor
    end handle EarlyExit => ()

end