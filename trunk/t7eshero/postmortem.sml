
structure Postmortem =
struct

    open SDL
    structure FontSmall = Sprites.FontSmall
    structure Font = Sprites.Font
    structure FontMax = Sprites.FontMax
    structure FontHuge = Sprites.FontHuge
    structure SmallFont3x = Sprites.SmallFont3x
    structure SmallFont = Sprites.SmallFont

    val background = Sprites.requireimage "testgraphics/postmortem.png"    
    val screen = Sprites.screen

    val BGMIDI = "postmortem.mid"
    val PRECURSOR = 180
    val SLOWFACTOR = 5
    val MENUTICKS = 0w60
    val MINIMUM_TIME = 0w2000

    (* It's hard to calibrate the cutoffs for dancing awards. Here are
       some measurements with the 360 X-Plorer, configured correctly:

       0.056m/s was my normal standing posture for Goog. 
       0.1 when I was rocking out.
       0.016 when I was trying to stay as still as possible and still play.
       (But on other songs I can get 0.0...)
       I can get 0.0 if I just sit there and don't play anything. *)
        
    datatype medal = datatype Hero.medal

    fun medalg PerfectMatch = Sprites.matchmedal
      | medalg Snakes = Sprites.snakesmedal
      | medalg Stoic = Sprites.stoicmedal
      | medalg Plucky = Sprites.pluckymedal
      | medalg Pokey = Sprites.pokeymedal
      | medalg AuthenticStrummer = Sprites.press_ok (* XXX *)
      | medalg AuthenticHammer = Sprites.press_ok (* XXX *)
        
    fun medal1 PerfectMatch = "Perfect"
      | medal1 Snakes = "Snakes!"
      | medal1 Stoic = "Stoic."
      | medal1 Plucky = "Plucky!"
      | medal1 Pokey = "Pokey!"
      | medal1 AuthenticStrummer = "Authentic"
      | medal1 AuthenticHammer = "Authentic"

    fun medal2 PerfectMatch = "Match!"
      | medal2 Snakes = ""
      | medal2 Stoic = ""
      | medal2 Plucky = ""
      | medal2 Pokey = ""
      | medal2 AuthenticStrummer = "Strummer"
      | medal2 AuthenticHammer = "Hammer"

    exception Done
    fun loop (songid, profile, tracks) =
        let
            val () = Sound.all_off ()

            val { misses, percent = (hit, total), ... } = Match.stats tracks
            val () = print ("At end: " ^ Int.toString misses ^ " misses\n");

            val percent = (real hit * 100.0 / real total)
            val () = if total > 0
                     then print ("At end: " ^ Int.toString hit ^ "/" ^ Int.toString total ^
                                 " (" ^ Real.fmt (StringCvt.FIX (SOME 1)) percent ^ 
                                 "%) of notes hit\n")
                     else ()

            val { totaldist, totaltime, upstrums, downstrums } = State.stats ()

            val dancerate = totaldist / totaltime

            val () = print ("Danced: " ^ Real.fmt (StringCvt.FIX (SOME 2)) totaldist ^ "m (" ^
                            Real.fmt (StringCvt.FIX (SOME 3)) dancerate
                            ^ "m/s)\n")

            (* get old records for this song, if any. Then decide if we made new records. *)
            val { percent = oldpercent, misses = oldmisses, medals = oldmedals } =
                case List.find (fn (sid, _) => Setlist.eq(sid, songid)) (Profile.records profile) of
                    NONE => { percent = 0, misses = total + 1, medals = nil }
                  | SOME (_, r) => r

            (* Need 90% to qualify for medals. *)
            val medals = 
                if percent >= 90.0
                then
                    List.filter
                    (fn PerfectMatch => hit = total
                      | Snakes => dancerate >= 0.25
                      | Stoic => dancerate < 0.02
                      | Plucky => downstrums = 0
                      | Pokey => upstrums = 0
                      | AuthenticStrummer => false (* XXX *)
                      | AuthenticHammer => false)
                    [PerfectMatch, Snakes, Stoic, Plucky, Pokey,
                     AuthenticStrummer, AuthenticHammer]
                else nil

            (* old and new, avoiding duplicates *)
            val allmedals = List.filter (fn m' => not (List.exists (fn m => m = m') oldmedals)) medals @ oldmedals

            (* save profile right away *)
            (* XXX if there are NO notes in the song, this crashes. maybe that
               should be considered an illegal song, but we should not
               be so brutal. *)
            val () = Profile.setrecords profile ((songid, { percent = Int.max(oldpercent,
                                                                              (hit * 100) div total),
                                                            misses = Int.min(oldmisses, misses),
                                                            medals = allmedals }) ::
                                                 List.filter (fn (sid, _) => not (Setlist.eq(songid, sid)))
                                                 (Profile.records profile))
            val () = Profile.save()

            val (divi, thetracks) = Game.fromfile BGMIDI
            val tracks = Game.label PRECURSOR SLOWFACTOR thetracks
            fun slow l = map (fn (delta, e) => (delta * SLOWFACTOR, e)) l
            val () = Song.init ()
            val cursor = Song.cursor_loop (0 - PRECURSOR) (slow (MIDI.merge tracks))

            val nexta = ref 0w0
            val start = SDL.getticks()
            fun exit () = if SDL.getticks() - start > MINIMUM_TIME
                          then raise Done
                          else ()

            (* got a new medal? then get clothes. *)
            val award = if List.exists (fn m => not (List.exists (fn m' => m = m') oldmedals)) medals
                        then (case Items.award (Profile.closet profile) of
                                  NONE => NONE
                                | SOME i =>
                                      let in
                                          Profile.setcloset profile (i :: Profile.closet profile);
                                          Profile.save();
                                          SOME i
                                      end)
                        else NONE

            fun loopplay () =
                let
                    val nows = Song.nowevents cursor
                in
                    List.app 
                    (fn (label, evt) =>
                     (case label of
                          Match.Music (inst, _) =>
                     (case evt of
                          MIDI.NOTEON(ch, note, 0) => Sound.noteoff (ch, note)
                        | MIDI.NOTEON(ch, note, vel) => Sound.noteon (ch, note, 
                                                                      90 * vel, 
                                                                      inst) 
                        | MIDI.NOTEOFF(ch, note, _) => Sound.noteoff (ch, note)
                        | _ => print ("unknown music event: " ^ MIDI.etos evt ^ "\n"))
                        | _ => ()))
                    nows
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

                    val X_MEDALS = 15
                    val X_MEDALTEXT = 15 + 64 + 8
                    val Y_MEDALS = Y_STRUM + 40
                    val H_MEDALS = 68

                    val X_NEW = X_MEDALS + 64 - 22
                    val YOFF_NEW = 12

                    val my = ref Y_MEDALS
                in
                    blitall(background, screen, 0, 0);

                    FontHuge.draw(screen, X_PERCENT, Y_PERCENT,
                                  "^3" ^ 
                                  Real.fmt (StringCvt.FIX (SOME 1)) (real hit * 100.0 / real total) ^ "^0%");
                    FontSmall.draw(screen, X_COUNT, Y_COUNT,
                                   "^1(^5" ^ Int.toString hit ^ "^1/^5" ^ Int.toString total ^ "^1) notes");
                    (* XXX extraneous, max streak, average latency, etc. *)
                    FontSmall.draw(screen, X_DANCE, Y_DANCE,
                                   "Danced: ^5" ^ Real.fmt (StringCvt.FIX (SOME 2)) totaldist ^ "^0m (^5" ^
                                   Real.fmt (StringCvt.FIX (SOME 3)) (totaldist / totaltime)
                                   ^ "^0m/s)");
                    FontSmall.draw(screen, X_STRUM, Y_STRUM,
                                   "Strum: ^5" ^ Int.toString upstrums ^ "^0 up, ^5" ^
                                   Int.toString downstrums ^ "^0 down");

                    app
                    (fn m =>
                     let in
                         SDL.blitall(medalg m, screen, X_MEDALS, !my);
                         Font.draw(screen, X_MEDALTEXT, !my, Chars.fancy (medal1 m));
                         Font.draw(screen, X_MEDALTEXT, !my + Font.height + 2, Chars.fancy (medal2 m));
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
