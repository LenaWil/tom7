structure Postmortem :> POSTMORTEM =
struct

  open SDL
  structure FontSmall = Sprites.FontSmall
  structure Font = Sprites.Font
  structure FontMax = Sprites.FontMax
  structure FontHuge = Sprites.FontHuge
  structure SmallFont3x = Sprites.SmallFont3x
  structure SmallFont = Sprites.SmallFont

  exception Postmortem of string
  val background = Sprites.requireimage "postmortem.png"
  val screen = Sprites.screen

  val BGMIDI = "postmortem.mid"
  val PRECURSOR = 180
  val SLOWFACTOR = 5
  val MENUTICKS = 0w60
  val MINIMUM_TIME = 0w2000

  local open Womb
  in
    val womb_pattern =
      Womb.pattern 0w50
        [[A,D,G,F, J],
         [C,B,E,H, L],
         [A,D,G,F, M],
         [C,B,E,H, K]]
  end

  (* It's hard to calibrate the cutoffs for dancing awards. Here are
     some measurements with the 360 X-Plorer, configured correctly:

     0.056m/s was my normal standing posture for Goog.
     0.1 when I was rocking out.
     0.016 when I was trying to stay as still as possible and still play.
     (But on other songs I can get 0.0...)
     I can get 0.0 if I just sit there and don't play anything. *)

  datatype medal = datatype Hero.medal

  exception Done
  fun loop () =
    let
      val () = Sound.all_off ()
      val () = Sound.seteffect 0.0

      val (divi, thetracks) = Score.fromfile BGMIDI
      val tracks = Score.label PRECURSOR SLOWFACTOR thetracks
      fun slow l = map (fn (delta, e) => (delta * SLOWFACTOR, e)) l
      val () = Song.init ()
      val cursor = Song.cursor_loop (0 - PRECURSOR) (slow (MIDI.merge tracks))

      val nexta = ref 0w0
      val start_postmortem = SDL.getticks()
      fun exit () = if SDL.getticks() - start_postmortem > MINIMUM_TIME
                    then raise Done
                    else ()

      (* XXX support multi-song postmortem! *)
      val { allmedals, oldmedals, medals,
            percent, hit, total, danced, dancerate,
            upstrums, downstrums, totalseconds, award } =
        case !(#final (Stats.head ())) of
          NONE => raise Postmortem "no stats!?"
        | SOME f => f

      fun loopplay () =
        let
          val nows = Song.nowevents cursor
        in
          if List.exists (fn (Match.Music _, MIDI.NOTEON(ch, note, v)) =>
                          v > 0 | _ => false) nows
          then Womb.next womb_pattern
          else ();

          List.app
          (fn (label, evt) =>
           (case label of
              Match.Music (inst, _) =>
                (case evt of
                   MIDI.NOTEON(ch, note, 0) =>
                     Sound.noteoff (ch, note)
                 | MIDI.NOTEON(ch, note, vel) =>
                     Sound.noteon (ch, note, Sound.midivel vel, inst)
                 | MIDI.NOTEOFF(ch, note, _) => Sound.noteoff (ch, note)
                 | _ => print ("unknown music event: " ^
                               MIDI.etos evt ^ "\n"))
            | _ => ())) nows
        end

      and input () =
        case pollevent () of
          SOME (E_KeyDown { sym = SDLK_ESCAPE }) => raise Done
        | SOME E_Quit => raise Hero.Exit
        | SOME (E_KeyDown { sym = SDLK_ENTER }) => exit()
        | SOME e =>
            (case Input.map e of
               SOME (_, Input.ButtonDown b) => exit()
             | SOME (_, Input.ButtonUp b) => ()
             | SOME (_, Input.StrumUp) => ()
             | SOME (_, Input.StrumDown) => ()
             | _ => ())
        | NONE => ()

      and draw () =
        let
          val X_PERCENT = 50
          val Y_PERCENT = 100
          val X_COUNT = 50
          val Y_COUNT = Y_PERCENT + FontHuge.height + 3
          val X_DANCE = 50
          val Y_DANCE = Y_COUNT + FontSmall.height + 3
          val X_STRUM = 50
          val Y_STRUM = Y_DANCE + FontSmall.height + 3

          val X_TIME = 50
          val Y_TIME = Y_STRUM + FontSmall.height + 3

          val X_MEDALS = 15
          val X_MEDALTEXT = 15 + 64 + 8
          val Y_MEDALS = Y_TIME + 40
          val H_MEDALS = 68

          val X_NEW = X_MEDALS + 64 - 22
          val YOFF_NEW = 12

          val my = ref Y_MEDALS
        in
          blitall(background, screen, 0, 0);

          FontHuge.draw(screen, X_PERCENT, Y_PERCENT,
                        "^3" ^
                        Real.fmt (StringCvt.FIX (SOME 1)) percent ^ "^0%");
          FontSmall.draw(screen, X_COUNT, Y_COUNT,
                         "^1(^5" ^ Int.toString hit ^ "^1/^5" ^
                         Int.toString total ^ "^1) notes");

          (* XXX extraneous, max streak, average latency, etc. *)
          FontSmall.draw(screen, X_DANCE, Y_DANCE,
                         "Danced: ^5" ^
                         Real.fmt (StringCvt.FIX (SOME 2)) danced ^ "^0m (^5" ^
                         Real.fmt (StringCvt.FIX (SOME 3)) danced
                         ^ "^0m/s)");

          FontSmall.draw(screen, X_STRUM, Y_STRUM,
                         "Strum: ^5" ^ Int.toString upstrums ^ "^0 up, ^5" ^
                         Int.toString downstrums ^ "^0 down");

          FontSmall.draw(screen, X_TIME, Y_TIME,
                         "Time: ^5" ^ Real.fmt (StringCvt.FIX (SOME 1))
                         totalseconds ^ "^0s");

          app
          (fn m =>
           let in
             SDL.blitall(Sprites.medalg m, screen, X_MEDALS, !my);
             Font.draw(screen, X_MEDALTEXT, !my,
                       Chars.fancy (Sprites.medal1 m));
             Font.draw(screen, X_MEDALTEXT, !my + Font.height + 2,
                       Chars.fancy (Sprites.medal2 m));
             (if not (List.exists (fn m' => m = m') oldmedals)
              then SDL.blitall(Sprites.new, screen, X_NEW, !my - YOFF_NEW)
              else ());
             my := !my + H_MEDALS
           end) medals;

          (case award of
             SOME i =>
               FontSmall.draw(screen, X_MEDALS, !my + 8,
                              "^6IJ^5 You got a ^3" ^ Items.name i ^ "^5!")
           | NONE => ());

          ()
        end

      and heartbeat () =
        let
          val () = Song.update ()
          val () = loopplay ()
          val now = getticks ()
        in
          if now > !nexta
          then ((* advance(); *)
                nexta := now + MENUTICKS)
          else ()
        end

      val nextd = ref 0w0
      fun go () =
        let
          val () = heartbeat ()
          val () = input ()
          val now = getticks ()
        in
          (if now > !nextd
           then (draw ();
                 nextd := now + MENUTICKS;
                 flip screen)
           else ());
          go ()
        end
    in
      go () handle Done => Sound.all_off ()
    end

end
