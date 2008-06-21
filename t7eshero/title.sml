functor TitleFn(val screen : SDL.surface) :> TITLE =
struct

    open SDL
    structure FontSmall = Sprites.FontSmall
    structure Font = Sprites.Font
    structure FontMax = Sprites.FontMax
    structure FontHuge = Sprites.FontHuge
    structure SmallFont3x = Sprites.SmallFont3x
    structure SmallFont = Sprites.SmallFont

    (* XXX joymap is obsolete *)
    type config = { joymap : int -> int }
    val joymap : config -> int -> int = #joymap

    datatype selection = Play | SignIn | Configure

    exception Selected of { midi : string,
                            difficulty : Hero.difficulty,
                            slowfactor : int,
                            config : config }

    fun dummy_joymap 0 = 0
      | dummy_joymap 1 = 1
      | dummy_joymap 3 = 2
      | dummy_joymap 2 = 3
      | dummy_joymap 4 = 4
      | dummy_joymap _ = 999 (* XXX *)

    val dummy = { midi = "medleyscore.mid",
                  difficulty = Hero.Real,
                  slowfactor = 5,
                  config = { joymap = dummy_joymap } }

    val SONGS_FILE = "songs.hero"
    val TITLEMIDI = "title.mid"
    val PRECURSOR = 180
    val SLOWFACTOR = 5

    structure LM = ListMenuFn(val screen = screen)
        
    local val seed = ref (0wxDEADBEEF : Word32.word)
    in
        fun random () =
            let
                val () = seed := Word32.xorb(!seed, 0wxF13844F5)
                val () = seed := Word32.*(!seed, 0wx7773137)
                val () = seed := Word32.+(!seed, 0wx7654321)
            in
                seed := !seed + 0w1;
                !seed
            end
        fun random_int () =
            Word32.toInt (Word32.andb(random (), 0wx7FFFFFFF))
    end

    fun fancy s =
        String.concat (map (fn c =>
                            implode [#"^", chr (ord #"0" + (random_int() mod 6)), c])
                       (explode s))

    fun loop () =
        let
            val () = Profile.load ()

            (* from 0..(humplen-1) *)
            val humpframe = ref 0
            val humprev = ref false
            val selected = ref Play

            val (divi, thetracks) = Game.fromfile TITLEMIDI
            val tracks = Game.label PRECURSOR SLOWFACTOR thetracks
            fun slow l = map (fn (delta, e) => (delta * SLOWFACTOR, e)) l
            val () = Song.init ()
            val cursor = Song.cursor_loop (0 - PRECURSOR) (slow (MIDI.merge tracks))

            fun move_down () =
                selected :=
                (case !selected of
                     Play => SignIn
                   | SignIn => Configure
                   | Configure => Play)

            fun move_up () = (move_down(); move_down())

            val playstring = ref "^1Play"
            val signstring = ref "^1Sign in"
            val confstring = ref "^1Configure"

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

            fun advance () =
                let
                in
                    (* XXX should pause on first, last frames a bit *)
                    (if !humprev
                     then humpframe := !humpframe - 1
                     else humpframe := !humpframe + 1);
                    (if !humpframe < 0
                     then (humpframe := 0; humprev := false)
                     else ());
                    (if !humpframe >= (Vector.length Sprites.humps)
                     then (humpframe := (Vector.length Sprites.humps - 1); 
                           humprev := true)
                     else ());
                        
                    playstring := "^1Play";
                    confstring := "^1Configure";
                    signstring := "^1Sign in";

                    (case !selected of
                         Play => playstring := fancy "Play"
                       | SignIn => signstring := fancy "Sign in"
                       | Configure => confstring := fancy "Configure")
                end

            val Y_PLAY = 148 + (FontHuge.height + 12) * 0
            val Y_SIGN = 148 + (FontHuge.height + 12) * 1
            val Y_CONF = 148 + (FontHuge.height + 12) * 2
            val MENUTICKS = 0w60

            (* configure sub-menu *)
            val configorder = Vector.fromList [Input.C_Button 0,
                                               Input.C_Button 1,
                                               Input.C_Button 2,
                                               Input.C_Button 3,
                                               Input.C_Button 4,
                                               Input.C_StrumUp,
                                               Input.C_StrumDown]
            val NINPUTS = Vector.length configorder
            fun configure device =
                let
                    exception AbortConfigure and FinishConfigure
                    val done = ref 0

                    (* in case we cancel *)
                    val old = Input.getmap device
                    val () = Input.clearmap device

                    val Y_GUITAR = 300
                    val Y_PRESS = Y_GUITAR - (57 * 2)
                    val Y_OK = Y_GUITAR + (81 * 2)
                    val PRESS_OFFSET = 104
                    fun buttonpos x = 
                        (if x <= 4 
                         then x * 28
                         else if x = 5 orelse x = 6 then (180 * 2)
                              else raise Hero.Hero "??")

                    fun accept e =
                        let in
                            Input.setmap device e (Vector.sub(configorder, !done));
                            done := !done + 1;
                            if !done = NINPUTS
                            then raise FinishConfigure
                            else ()
                        end

                    fun input () =
                        case pollevent () of
                            SOME (E_KeyDown { sym = SDLK_ESCAPE }) => raise AbortConfigure
                          | SOME E_Quit => raise Hero.Exit
                          | SOME e =>
                                if Input.belongsto e device
                                then  
                                  (* we only support these events right now *)
                                  (case e of
                                       (* ignore up events; these are handled by input *)
                                       E_KeyDown { sym } => accept (Input.Key sym)
                                     | E_JoyDown { button, which = _ } => accept (Input.JButton button)
                                     | E_JoyHat { hat, state, which = _ } => accept (Input.JHat { hat = hat,
                                                                                                  state = state })
                                     | _ => print "Unsupported event during configure.\n")
                                else print "Foreign event during configure.\n"
                          | NONE => ()

                    (* nothin' doin' *)
                    fun advance () = ()
                    fun draw () =
                        let
                        in
                            blitall(Sprites.configure, screen, 0, 0);
                            (* blitall(Vector.sub(Sprites.humps, !humpframe), screen, 128, 333); *)
                            blitall(Sprites.guitar, screen, 0 - buttonpos (!done), Y_GUITAR);
                            blitall(case !done of
                                        5 => Sprites.strum_up
                                      | 6 => Sprites.strum_down
                                      | _ => Sprites.press, screen, PRESS_OFFSET, Y_PRESS);
                            Util.for 0 (!done - 1)
                            (fn x =>
                             blitall(Sprites.press_ok, screen, 
                                     (0 - buttonpos (!done))
                                     + PRESS_OFFSET
                                     + buttonpos x, Y_OK))
                        end

                    val nexta = ref (getticks ())
                    fun heartbeat () = 
                        let 
                            val () = Song.update ()
                            val () = loopplay ()
                            val now = getticks ()
                        in
                            if now > !nexta
                            then (advance();
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
                    go () handle AbortConfigure => Input.restoremap device old
                                 (* XXX should have some titlescreen message fade-out queue *)
                               | FinishConfigure => ()
                end

            val nexta = ref (getticks ())

            (* it depends which device we click with for configuring *)
            fun select device =
                case !selected of
                    Play => play ()
                  | SignIn => signin ()
                  | Configure => configure device

            and input () =
                case pollevent () of
                    SOME (E_KeyDown { sym = SDLK_ESCAPE }) => raise Hero.Exit
                  | SOME E_Quit => raise Hero.Exit
                  | SOME (E_KeyDown { sym = SDLK_UP }) => move_up ()
                  | SOME (E_KeyDown { sym = SDLK_DOWN }) => move_down ()
                  | SOME (E_KeyDown { sym = SDLK_ENTER }) => select Input.keyboard
                  (* XXXX should use input map, duh *)
                  | SOME (E_JoyDown { button, which, ... }) => select (Input.joy which)
                  | SOME (E_JoyHat { state, ... }) =>
                    if Joystick.hat_up state
                    then move_up ()
                    else if Joystick.hat_down state
                         then move_down()
                         else ()
                  | _ => ()

            (* Choose song *)
            and play () =
                let
                    val trim = StringUtil.losespecl StringUtil.whitespec o StringUtil.losespecr StringUtil.whitespec
                    val songs = StringUtil.readfile SONGS_FILE
                    val songs = String.tokens (fn #"\n" => true | _ => false) songs
                    val songs = List.mapPartial 
                        (fn s =>
                         case String.fields (fn #"|" => true | _ => false) s of
                             [file, slowfactor, title, artist, year] =>
                                 (case Int.fromString (trim slowfactor) of
                                      NONE => (print ("Bad slowfactor: " ^ slowfactor ^ "\n");
                                               NONE)
                                    | SOME slowfactor => SOME (trim file, slowfactor, trim title, trim artist,
                                                               trim year))
                           | _ => (print ("Bad line: " ^ s ^ "\n"); NONE)) songs

                    fun itemheight _ = FontSmall.height + SmallFont.height + 6
                    fun drawitem ((_, _, title, artist, year), x, y, sel) = 
                        let in
                            FontSmall.draw(screen, x, y, 
                                           if sel then "^3" ^ title
                                           else title);
                            SmallFont.draw(screen, x, y + FontSmall.height, "^1by ^0" ^ artist ^ 
                                           " ^4(" ^ year ^ ")")
                            (* XXX show records *)
                        end
                in
                    case LM.select { x = 8, y = 40,
                                     width = 256 - 16,
                                     height = 400,
                                     items = songs,
                                     drawitem = drawitem,
                                     itemheight = itemheight,
                                     parent_draw = draw,
                                     parent_heartbeat = heartbeat } of
                        NONE => ()
                      | SOME (file, factor, _, _, _) => 
                            (* XXX need to get real joymap from config. *)
                            raise Selected
                            { midi = file,
                              difficulty = Hero.Real,
                              slowfactor = factor,
                              config = { joymap = dummy_joymap } }
                end


            (* profile select sub-menu *)
            and signin () =
                let
                    fun createnew () =
                        let val p = Profile.add_default()
                        in
                            Profile.save();
                            (* XXX start editing *)
                            signin ()
                        end

                    datatype saction =
                        CreateNew
                      | SelectOld of Profile.profile

                    fun itemheight CreateNew = Font.height
                      | itemheight (SelectOld _) = 72
                    fun drawitem (CreateNew, x, y, sel) = Font.draw(screen, x, y, 
                                                                    if sel then "^3Create Profile"
                                                                    else "^2Create Profile")
                      | drawitem (SelectOld p, x, y, sel) = 
                        let in
                            (* XXX also, draw border for it *)
                            SDL.fillrect(screen, x + 2, y + 2, 66, 66, SDL.color (0wxFF, 0wxFF, 0wxFF, 0wxFF));
                            SDL.blitall(Profile.surface p, screen, x + 4, y + 4);
                            Font.draw(screen, x + 72, y + 4, 
                                      if sel then ("^3" ^ Profile.name p)
                                      else Profile.name p)
                        end
                in
                    case LM.select { x = 8, y = 40,
                                     width = 256 - 16,
                                     height = 400,
                                     items = CreateNew :: map SelectOld (Profile.all ()),
                                     drawitem = drawitem,
                                     itemheight = itemheight,
                                     parent_draw = draw,
                                     parent_heartbeat = heartbeat } of
                        NONE => ()
                      | SOME CreateNew => createnew()
                      | SOME (SelectOld profile) => Hero.messagebox (Profile.name profile)
                end

            and draw () =
                let
                in
                    blitall(Sprites.title, screen, 0, 0);
                    blitall(Vector.sub(Sprites.humps, !humpframe), screen, 128, 333);
                    FontHuge.draw(screen, 36, Y_PLAY, !playstring);
                    FontHuge.draw(screen, 36, Y_SIGN, !signstring);
                    FontHuge.draw(screen, 36, Y_CONF, !confstring);
                    (case !selected of
                         Play => FontHuge.draw(screen, 4, Y_PLAY, Chars.HEART)
                       | SignIn => FontHuge.draw(screen, 4, Y_SIGN, Chars.HEART)
                       | Configure => FontHuge.draw(screen, 4, Y_CONF, Chars.HEART))
                end

            and heartbeat () = 
                let 
                    val () = Song.update ()
                    val () = loopplay ()
                    val now = getticks ()
                in
                    if now > !nexta
                    then (advance();
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
            go () handle Selected what => 
                let in
                    Sound.all_off ();
                    what
                end
        end


end
