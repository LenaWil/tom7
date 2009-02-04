functor TitleFn(val screen : SDL.surface) :> TITLE =
struct

    structure FontSmall = Sprites.FontSmall
    structure Font = Sprites.Font
    structure FontMax = Sprites.FontMax
    structure FontHuge = Sprites.FontHuge
    structure SmallFont3x = Sprites.SmallFont3x
    structure SmallFont = Sprites.SmallFont
    structure S = SDL
    structure Joystick = S.Joystick
    datatype sdlk = datatype SDL.sdlk
    datatype event = datatype SDL.event

    datatype selection = Play | SignIn | Configure | Wardrobe | Update

    exception Selected of { song : Setlist.songinfo,
                            difficulty : Hero.difficulty,
                            profile : Profile.profile }

    val TITLEMIDI = "title.mid"
        
    val PRECURSOR = 180
    val SLOWFACTOR = 5

    structure LM = ListMenuFn(val screen = screen)
    structure Configure = ConfigureFn(val screen = screen)
        

    val profile = 
        let in
            Profile.load();
            (* ensure that we have at least a profile to use now. *)
            if length (Profile.all ()) = 0
            then let in 
                ignore (Profile.add_default());
                Profile.save()
                 end
            else ();
            ref (hd (Profile.all ()))
        end
        handle Items.Items s => (Hero.messagebox s; raise Hero.Hero "couldn't load profile")
             (* | Profile.Profile s => (Hero.messagebox s; raise Hero.Hero "couldn't load profile")*)

    fun loop () =
        let

            (* from 0..(humplen-1) *)
            val humpframe = ref 0
            val humprev = ref false
            val selected = ref 0

            val (divi, thetracks) = Game.fromfile TITLEMIDI
            val tracks = Game.label PRECURSOR SLOWFACTOR thetracks
            fun slow l = map (fn (delta, e) => (delta * SLOWFACTOR, e)) l
            val () = Song.init ()
            val cursor = Song.cursor_loop (0 - PRECURSOR) (slow (MIDI.merge tracks))

            val items = Vector.fromList [Play, SignIn, Wardrobe, Configure, Update]
            fun posof d =
                case Vector.findi (fn (_, x) => x = d) items of
                    NONE => raise Hero.Hero "menuitem not in vector"
                  | SOME (i, _) => i
            fun move_down () = selected := (!selected + 1) mod Vector.length items
            fun move_up () = selected := (!selected - 1) mod Vector.length items

            val playstring = ref "^1Play"
            val signstring = ref "^1Sign in"
            val confstring = ref "^1Configure"
            val wardstring = ref "^1Wardrobe"
            val updastring = ref "^1Update"

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
                                                                      Sound.midivel vel, 
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
                    wardstring := "^1Wardrobe";
                    updastring := "^1Update";

                    (case Vector.sub(items, !selected) of
                         Play => playstring := Chars.fancy "Play"
                       | SignIn => signstring := Chars.fancy "Sign in"
                       | Configure => confstring := Chars.fancy "Configure"
                       | Wardrobe => wardstring := Chars.fancy "Wardrobe"
                       | Update => updastring := Chars.fancy "Update" )
                end

            val Y_PLAY = 148 + (FontHuge.height) * posof Play
            val Y_SIGN = 148 + (FontHuge.height) * posof SignIn
            val Y_CONF = 148 + (FontHuge.height) * posof Configure
            val Y_WARD = 148 + (FontHuge.height) * posof Wardrobe
            val Y_UPDA = 148 + (FontHuge.height) * posof Update
            val X_ROBOT = 128
            val Y_ROBOT = 333

            val nexta = ref (S.getticks ())

            (* it depends which device we click with for configuring *)
            fun select device =
                case Vector.sub(items, !selected) of
                    Play => play ()
                  | SignIn => signin ()
                  | Configure => Configure.configure loopplay device
                  | Update => Update.update () (* XXX *)
                  | Wardrobe => 
                        let in
                            Wardrobe.loop (!profile);
                            Song.init ();
                            Song.rewind cursor
                            (* and draw? *)
                        end

            and input () =
                case S.pollevent () of
                    (* XXX Escape and cancel button should show a quit prompt *)
                    SOME (E_KeyDown { sym = SDLK_ESCAPE }) => raise Hero.Exit
                  | SOME E_Quit => raise Hero.Exit
                  | SOME e =>
                      (case Input.map e of
                           SOME (d, Input.ButtonDown 0) => select d
                         | SOME (_, Input.ButtonDown 1) => raise Hero.Exit
                         | SOME (_, Input.StrumUp) => move_up ()
                         | SOME (_, Input.StrumDown) => move_down ()
                         | SOME _ => () (* XXX other buttons should do something funny? *)
                         | NONE => 
                               (case e of
                                    E_KeyDown { sym = SDLK_UP } => move_up ()
                                  | E_KeyDown { sym = SDLK_DOWN } => move_down ()
                                  | E_KeyDown { sym = SDLK_ENTER } => select Input.keyboard
                                  (* Might be able to reach configure menu with unconfigured joystick.. *)
                                  | E_JoyDown { button, which, ... } => select (Input.joy which)
                                  | E_JoyHat { state, ... } =>
                                        if Joystick.hat_up state
                                        then move_up ()
                                        else if Joystick.hat_down state
                                             then move_down()
                                             else ()
                                  | _ => ()))
                  | NONE => ()

            (* Choose song *)
            and play () =
                let
                    (* XXX draw mini icons! *)
                    fun mtostring Hero.PerfectMatch = Chars.MATCH
                      | mtostring Hero.Snakes = Chars.SNAKES
                      | mtostring Hero.Stoic = Chars.STOIC
                      | mtostring Hero.Plucky = Chars.PLUCKY
                      | mtostring Hero.Pokey = Chars.POKEY
                      | mtostring Hero.AuthenticStrummer = "A"
                      | mtostring Hero.AuthenticHammer = "a"

                    fun mstostring Hero.PerfectMatch = Chars.MATCH
                      | mstostring Hero.Snakes = Chars.SNAKES
                      | mstostring Hero.Stoic = Chars.STOIC
                      | mstostring Hero.Plucky = Chars.PLUCKY
                      | mstostring Hero.Pokey = Chars.POKEY
                      | mstostring Hero.AuthenticStrummer = "A"
                      | mstostring Hero.AuthenticHammer = "a"

                    val WIDTH = 256 - 16
                    val HEIGHT = 444


                    fun getrecords (songinfo as { id, ... }) =
                        case List.find (fn (sid, _) => Setlist.eq(sid, id)) 
                            (Profile.records (!profile)) of
                            NONE => ("", fn () => "") (* no record. *)
                          | SOME (_, { percent, misses, medals }) =>
                            let 
                                fun colorp p s =
                                    if p = 100 
                                    then Chars.fancy s ^ "^0"
                                    else if p >= 90
                                         then "^5" ^ s ^ "^<"
                                         else if p >= 80
                                              then "^1" ^ s ^ "^<"
                                              else if p >= 50
                                                   then "^3" ^ s ^ "^<"
                                                   else "^2" ^ s ^ "^<"
                            in
                                print ("GOT RECORD for " ^ #file songinfo ^ "\n");
                                ("^4" ^
                                 (if percent = 99 orelse misses > 0 andalso misses <= 3
                                  then "-" ^ Int.toString misses
                                  else Int.toString percent ^ "%") ^ " " ^
                                     String.concat (map mtostring medals),
                                     fn () => 
                                     colorp percent
                                     (if percent = 99 orelse misses > 0 andalso misses <= 3
                                      then  ("-" ^ Int.toString misses)
                                      else Int.toString percent ^ "%") ^ " " ^
                                         String.concat (map mstostring medals))
                            end

                    val songs = ListUtil.mapto getrecords (Setlist.allsongs())

                    fun itemheight _ = FontSmall.height + SmallFont.height + FontSmall.height + 8
                    fun drawitem (i as ({title, artist, year, ...} : Setlist.songinfo, 
                                        (r, rs)), x, y, sel) = 
                        let in
                            FontSmall.draw(screen, x + 2, y, 
                                           if sel then "^3" ^ title
                                           else title);

                            SmallFont.draw(screen, x + 2, y + 2 + FontSmall.height, 
                                           "^4by ^0" ^ artist ^ 
                                           " ^1(" ^ year ^ ")");
                            
                            FontSmall.draw(screen, x + 42, y + 4 + FontSmall.height + SmallFont.height,
                                           if sel then rs() else r)
                        end
                in
                    case LM.select { x = 8, y = 40,
                                     width = WIDTH,
                                     height = HEIGHT,
                                     items = songs,
                                     drawitem = drawitem,
                                     itemheight = itemheight,
                                     bgcolor = SOME LM.DEFAULT_BGCOLOR,
                                     selcolor = SOME (S.color (0wx44, 0wx44, 0wx77, 0wxFF)),
                                     bordercolor = SOME LM.DEFAULT_BORDERCOLOR,
                                     parent = Drawable.drawable { draw = draw, heartbeat = heartbeat,
                                                                  resize = Drawable.don't } } of
                        NONE => ()
                      | SOME (song, _) => 
                            raise Selected
                            { song = song,
                              difficulty = Hero.Real,
                              profile = !profile }
                end

            (* FIXME XXX this doesn't do anything useful right now.
               Should let you change the player's name and icon,
               see and clear statistics, etc. *)
            and editprofile profile =
                let

                    datatype item =
                        PlayerName
                      | PlayerIcon
                      | PlayerStats

                    fun itemheight PlayerName = FontSmall.height * 2
                      | itemheight PlayerIcon = 72
                      | itemheight PlayerStats = FontSmall.height

                    val profile_name = "Profile name:"

                    fun drawitem (PlayerName, x, y, sel) = 
                        let in
                            FontSmall.draw(screen, x, y, 
                                           (if sel then "^3" else "^2") ^
                                               profile_name);
                            if sel
                            then SmallFont.draw(screen, x + FontSmall.sizex_plain profile_name,
                                                (* share baseline *)
                                                y + (FontSmall.height - SmallFont.height - 3),
                                                " (^5edit^0)")
                            else ();
                            FontSmall.draw(screen, x, y + FontSmall.height,
                                           Profile.name profile)
                        end
                      | drawitem _ = ()
                in
                    case LM.select { x = 8, y = 40,
                                     width = 256 - 16,
                                     height = 400,
                                     items = [PlayerName, PlayerIcon, PlayerStats],
                                     drawitem = drawitem,
                                     itemheight = itemheight,
                                     bgcolor = SOME LM.DEFAULT_BGCOLOR,
                                     selcolor = SOME LM.DEFAULT_SELCOLOR,
                                     bordercolor = SOME LM.DEFAULT_BORDERCOLOR,
                                     parent = Drawable.drawable { draw = draw,
                                                                  heartbeat = heartbeat,
                                                                  resize = Drawable.don't } } of
                        NONE => ()
(*
                      | SOME CreateNew => createnew()
                      | SOME (SelectOld pf) => profile := pf
*)
                end

            (* profile select sub-menu *)
            and signin () =
                let
                    fun createnew () =
                        let val p = Profile.add_default()
                        in
                            Profile.save();
                            (* start editing immediately *)
                            editprofile p
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
                            S.fillrect(screen, x + 2, y + 2, 66, 66, S.color (0wxFF, 0wxFF, 0wxFF, 0wxFF));
                            S.blitall(Profile.surface p, screen, x + 4, y + 4);
                            FontSmall.draw(screen, x + 72, y + 4, 
                                           if sel then ("^3" ^ Profile.name p)
                                           else Profile.name p)
                        end
                    val this = Drawable.drawable { draw = draw,
                                                   heartbeat = heartbeat,
                                                   resize = Drawable.don't }
                in
                    case LM.select { x = 8, y = 40,
                                     width = 256 - 16,
                                     height = 400,
                                     items = CreateNew :: map SelectOld (Profile.all ()),
                                     drawitem = drawitem,
                                     itemheight = itemheight,
                                     bgcolor = SOME LM.DEFAULT_BGCOLOR,
                                     selcolor = SOME (S.color (0wx55, 0wx22, 0wx00, 0wxFF)),
                                     bordercolor = SOME LM.DEFAULT_BORDERCOLOR,
                                     parent = this } of
                        NONE => ()
                      | SOME CreateNew => createnew()
                      | SOME (SelectOld pf) => (profile := pf;
                                                Profile.setusednow pf;
                                                Profile.save())

                end

            and draw () =
                let
                    fun drawitem item =
                        let val (f, x, y) = Vector.sub(Items.frames item, !humpframe)
                        in S.blitall(f, screen, X_ROBOT + x, Y_ROBOT + y)
                        end
                in
                    S.blitall(Sprites.title, screen, 0, 0);

                    Items.app_behind (Profile.outfit (!profile)) drawitem;
                    S.blitall(Vector.sub(Sprites.humps, !humpframe), screen, X_ROBOT, Y_ROBOT);
                    Items.app_infront (Profile.outfit (!profile)) (fn i => if Items.zindex i < 50
                                                                           then drawitem i
                                                                           else ());

                    FontHuge.draw(screen, 36, Y_PLAY, !playstring);
                    FontHuge.draw(screen, 36, Y_SIGN, !signstring);
                    FontHuge.draw(screen, 36, Y_CONF, !confstring);
                    FontHuge.draw(screen, 36, Y_WARD, !wardstring);
                    FontHuge.draw(screen, 36, Y_UPDA, !updastring);
                    (case Vector.sub(items, !selected) of
                         Play => FontHuge.draw(screen, 4, Y_PLAY, Chars.HEART)
                       | SignIn => FontHuge.draw(screen, 4, Y_SIGN, Chars.HEART)
                       | Configure => FontHuge.draw(screen, 4, Y_CONF, Chars.HEART)
                       | Wardrobe => FontHuge.draw(screen, 4, Y_WARD, Chars.HEART)
                       | Update => FontHuge.draw(screen, 4, Y_UPDA, Chars.HEART));

                    (* XXX hack attack.. *)
                    Items.app_infront (Profile.outfit (!profile)) (fn i => if Items.zindex i >= 50
                                                                           then drawitem i
                                                                           else ())

                end

            and heartbeat () = 
                let 
                    val () = Song.update ()
                    val () = loopplay ()
                    val now = S.getticks ()
                in
                    if now > !nexta
                    then (advance();
                          nexta := now + Hero.MENUTICKS)
                    else ()
                end

            val nextd = ref 0w0
            fun go () =
                let 
                    val () = heartbeat ()
                    val () = input ()
                    val now = S.getticks ()
                in
                    (if now > !nextd
                     then (draw (); 
                           nextd := now + Hero.MENUTICKS;
                           S.flip screen)
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
