(* Small minigame. *)
structure Minigame :> MINIGAME =
struct

  (* XXX clean up some of these copies that we don't need. *)
  datatype label = datatype Match.label
  exception Abort (* abort gameplay, return to menu *)
  exception Minigame of string

  structure MT = MersenneTwister

  structure MScene =
  struct
    fun clear () = ()
    fun settimesig (n, d) = ()
  end

  (* In the minigame we need to keep track of the ids of
     note events so that we can allocate them to balls. *)
  structure ID :
  sig
    eqtype id
    val compare : id * id -> order
    val zero : id
    val next : id -> id
  end =
  struct
    type id = int
    val compare = Int.compare
    val zero = 0
    fun next i = i + 1
  end

  structure IS = SplaySetFn(type ord_key = ID.id
                            val compare = ID.compare)

  val itos = Int.toString
  val rtos = Real.fmt (StringCvt.FIX (SOME 2))

  val DRAWTICKS = (* 128 *) 12
  val DISINTEGRATION_MS = 1000

  (* In MIDI ticks *)
  val EMIT_AHEAD = 256

  exception EarlyExit

  val screen = Sprites.screen

  val BLACK = SDL.color (0w0, 0w0, 0w0, 0wxFF)
  val WHITE = SDL.color (0wxFF, 0wxFF, 0wxFF, 0wxFF)

  val BALLCOLORS =
    Vector.fromList
    [SDL.color (0wxFF, 0wx00, 0wx00, 0wxFF),
     SDL.color (0wx00, 0wxFF, 0wx00, 0wxFF),
     SDL.color (0wx00, 0wx00, 0wxFF, 0wxFF),
     SDL.color (0wxFF, 0wxFF, 0wx00, 0wxFF),
     SDL.color (0wxFF, 0wx00, 0wxFF, 0wxFF),
     SDL.color (0wx00, 0wxFF, 0wxFF, 0wxFF)]

  val GAMEWIDTH = 512 (* Sprites.gamewidth *)
  val GAMEHEIGHT = Sprites.height
  val paddlewidth = ref 64
  val paddlex = ref 0.0
  val paddle_dx = ref 0.0
  val PADDLEY = GAMEHEIGHT - 32
  val PADDLEHEIGHT = 18
  (* Of the paddle, in pixels per tick *)
  val MAXSPEED = 1.5
  (* Pixels per tick per tick *)
  val GRAVITY = 0.0001

  val GAMEX = 0
  val GAMEY = 0

  datatype ballstate =
    Normal
  | Disintegrating of int
  type ball = { x : real, y : real,
                dx : real, dy : real,
                halfwidth : int,
                c : SDL.color,
                state : ballstate }

  val balls = ref (nil : ball list)

  val allocated = ref IS.empty

  fun clear () =
    let in
      balls := nil;
      paddlex := 0.0;
      paddle_dx := 0.0;

      (* XXX *)
      balls := [{ x = 10.0, y = 0.0, halfwidth = 10,
                  dx = 0.01, dy = 0.0,
                  c = WHITE, state = Normal },
                { x = 40.0, y = 0.0, halfwidth = 16,
                  dx = 0.02, dy = 0.0,
                  c = WHITE, state = Normal },
                { x = 11.0, y = 0.0, halfwidth = 8,
                  dx = ~0.02, dy = ~0.01,
                  c = WHITE, state = Normal }];

      ()
    end

  (* Like Play, we have some mutually recursive functions. *)

  (* This one is just responsible for making the music happen. *)
  fun doplay cursor =
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
        (fn (id, label, evt) =>
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

  (* Given a ball moving in this direction that we can reclaim,
     see if we can use it to allocate a note from the emit cursor. *)
  fun reallocate cursor (x, y, dx, dy, halfwidth) = NONE

  val mt = MT.init32 0wxF00D

  (* Given a delta time (number of midi ticks), spawn a random
     ball such that it reaches the paddle in time with the music. *)
  fun allocate (dt, id, ch, note, vel, inst) =
    let
      val halfwidth = 2 + vel div 10
      val dropheight = real (PADDLEY - halfwidth)

      val color = Vector.sub (BALLCOLORS, ch mod Vector.length BALLCOLORS)

    in
      allocated := IS.add (!allocated, id);
      (* XXX predict! *)
      { x = real (MT.random_nat mt GAMEWIDTH),
        y = 0.0, halfwidth = halfwidth,
        dx = real (MT.random_nat mt 100) / 1000.0,
        dy = 0.0,
        c = color, state = Normal }
    end

  (* This one emits balls so that they reach the paddle at the
     right moment. The emission cursor is ahead of the play cursor
     and will always drop balls as it crosses events that have not
     yet been allocated, guaranteeing that all notes become balls.

     Separately, we may allocate some balls out of order, or
     reallocate a ball that has bounced. *)
  fun doemit cursor =
    let
      (* XXX also use some future events... *)
      val (nows, future) = Song.now_and_look cursor

      fun noteon (id, ch, note, vel, inst) =
        if IS.member (!allocated, id)
        then ()
        else balls := allocate (EMIT_AHEAD, id, ch, note, vel, inst) :: !balls

    in
      (* XXX use score? *)
      List.app
      (fn (id, label, evt) =>
       case label of
         Music (inst, track) =>
           (case evt of
              MIDI.NOTEON(ch, note, vel) =>
                if vel > 0
                then noteon (id, ch, note, vel, inst)
                else ()
            | _ => ())
       | _ => ()) nows
    end

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
    let
      fun drawball ({ x, y, c, halfwidth, state, ... } : ball) =
        let
          val x = GAMEX + Real.round x
          val y = GAMEY + Real.round y


          val c = case state of
            Disintegrating n =>
              SDL.Util.darken_color (c,
                                     0.8 * real n /
                                     real DISINTEGRATION_MS)
            | _ => c
        in
          (* Note, this doesn't clip on the right edge, and wouldn't
             on other sides if they weren't the same as the screen. *)
          SDL.fillrect (screen, x - halfwidth, y - halfwidth,
                        halfwidth * 2, halfwidth * 2,
                        c)
        end
    in
      (* Fill whole screen black.
         PERF: Don't need to fill parts that aren't being used...
         *)
      SDL.fillrect (screen, 0, 0, Sprites.width, Sprites.height, BLACK);

      SDL.fillrect (screen, GAMEX + Real.trunc (!paddlex), GAMEY + PADDLEY,
                    !paddlewidth, PADDLEHEIGHT,
                    WHITE);

      app drawball (!balls);

      SDL.flip screen
    end

  (* Run once per tick. emit_cursor is used to allocate bounced balls
     to future notes. *)
  fun dophysics emit_cursor =
    let
      fun runballs nil = nil
        | runballs ({ state = Disintegrating 0, ... } :: rest) = rest
        | runballs ({ x : real, y : real,
                      dx : real, dy : real,
                      halfwidth : int,
                      c : SDL.color,
                      state : ballstate } :: rest) =
        let
          val x = x + dx
          val y = y + dy
          val dy = dy + GRAVITY

          val hw = real halfwidth

          (* clip x left *)
          val (x, dx) =
            if x - hw < 0.0
            then (hw, Real.abs dx)
            else (x, dx)

          val (x, dx) =
            if x + hw > real GAMEWIDTH
            then (real GAMEWIDTH - hw, ~ (Real.abs dx))
            else (x, dx)

          (* Already handled case of a disintegrating ball
             that timed out above. *)
          val state = case state of
            Disintegrating n => Disintegrating (n - 1)
          | other => other

          fun bounce (y, dy) =
            (* First, if it's already disintegrating, let it bounce
               but don't resurrect. *)
            case state of
              Disintegrating n =>
                { x = x, y = y, dx = dx, dy = dy, halfwidth = halfwidth,
                  c = c, state = state } :: runballs rest
            | Normal =>
                case reallocate emit_cursor (x, y, dx, dy, halfwidth) of
                  SOME (x, y, dx, dy, halfwidth) =>
                    { x = x, y = y, dx = dx, dy = dy, halfwidth = halfwidth,
                      c = c, state = Normal } :: runballs rest
                | NONE =>
                    (* If we can't reallocate it, then it disintegrates. *)
                    { x = x, y = y, dx = dx, dy = dy, halfwidth = halfwidth,
                      c = c, state = Disintegrating DISINTEGRATION_MS } ::
                    runballs rest
        in
          (* If it's gone off the bottom of the screen, it's
             never coming back. *)
          if y + hw > real GAMEHEIGHT
          then runballs rest
          (* Otherwise, try bouncing off paddle. *)
          else if dy > 0.0 andalso
                  (* XXX quantum tunneling is possible here *)
                  y + hw >= real PADDLEY andalso
                  y - hw <= real (PADDLEY + PADDLEHEIGHT) andalso
                  x + hw >= !paddlex andalso
                  x - hw <= !paddlex + real (!paddlewidth)
               then
                 let
                   val y = real (PADDLEY - halfwidth)
                   val dy = ~ (Real.abs dy)
                 in
                   bounce (y, dy)
                 end
               else
                 (* Just keep it. *)
                 { x = x, y = y, dx = dx, dy = dy, halfwidth = halfwidth,
                   c = c, state = state } :: runballs rest
        end

    in
      paddlex := !paddlex + !paddle_dx;
      (if !paddlex < 0.0 then paddlex := 0.0
       else if !paddlex + real (!paddlewidth) > real GAMEWIDTH
            then paddlex := real (GAMEWIDTH - !paddlewidth)
            else ());
      balls := runballs (!balls);
      ()
    end

  (* 60 fps *)
  val TICKS_PER_FRAME = 0w16
  fun loop (prev, prevframe, play_cursor, emit_cursor) =
    let
      val now = SDL.getticks()
      val ticks = Word32.toIntX (now - prev)
    in
      doinput ();
      Song.update ();
      doplay play_cursor;
      doemit emit_cursor;
      Womb.heartbeat ();

      Util.for 0 (ticks - 1)
      (fn _ => dophysics emit_cursor);

      let val prevframe =
        (if now - prevframe >= TICKS_PER_FRAME
         then (dodraw (); now)
         else prevframe);
      in
        (* Note: There may still be disintegrating balls *)
        if Song.done play_cursor
        then ()
        else loop (now, prevframe, play_cursor, emit_cursor)
      end
    end handle EarlyExit => ()

  fun add_ids cur ((dt, (label, evt)) :: rest) = (dt, (cur, label, evt)) ::
    add_ids (ID.next cur) rest
    | add_ids _ nil = nil

  fun game song =
    let
      val () = clear ()

      val tracks : (int * (Match.label * MIDI.event)) list = Score.assemble song
      val tracks : (int * (ID.id * Match.label * MIDI.event)) list =
        add_ids ID.zero tracks
      val () = Song.init ()
      val play_cursor = Song.cursor 0 tracks
      val emit_cursor = Song.cursor EMIT_AHEAD tracks
      val start = SDL.getticks()
    in
      dodraw ();
      loop (start, 0w0, play_cursor, emit_cursor)
    end handle EarlyExit => ()

end