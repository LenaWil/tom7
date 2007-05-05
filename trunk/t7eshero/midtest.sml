
(* FIXME Check that SDL_AUDIODRIVER is dsound otherwise this
   is unusable because of latency *)

structure Test =
struct

  type ptr = MLton.Pointer.t

  exception Nope

  exception Test of string

  open SDL

  fun messagebox s = 
      let
        (* val mb = _import "MessageBoxA" stdcall : int * string * string * int -> unit ; *)
      in
        (* mb (0, s ^ "\000", "message", 0) *)
        print (s ^ "\n")
      end

  val width = 640
  val height = 480

  val TILESW = width div 16
  val TILESH = height div 16

  val ROBOTH = 32
  val ROBOTW = 16

  open Tile
  open World

  val screen = makescreen (width, height)

(*
  val _ = Util.for 0 (Joystick.number () - 1)
      (fn x => print ("JOY " ^ Int.toString x ^ ": " ^ Joystick.name x ^ "\n"))

  (* XXX requires joystick! *)
  val joy = Joystick.openjoy 0 
  val () = Joystick.setstate Joystick.ENABLE
*)

  val initaudio_ = _import "ml_initsound" : unit -> unit ;
  val () = initaudio_ ()

  val freq = ref 256
  val setfreq_ = _import "ml_setfreq" : int -> unit ;

  fun requireimage s =
    case Image.load s of
      NONE => (print ("couldn't open " ^ s ^ "\n");
               raise Nope)
    | SOME p => p

  val robotr = requireimage "testgraphics/robot.png"
  val robotl = requireimage "testgraphics/robotl.png" (* XXX should be able to flip graphics *)
  val robotr_fade = alphadim robotr
  val robotl_fade = alphadim robotl
  val solid = requireimage "testgraphics/solid.png"

  val redhi = requireimage "testgraphics/redhighlight.png"
  val greenhi = requireimage "testgraphics/greenhighlight.png"
  val robobox = requireimage "testgraphics/robobox.png"

  val ramp_lm = requireimage "testgraphics/rampup1.png"
  val ramp_mh = requireimage "testgraphics/rampup2.png"

  datatype dir = UP | DOWN | LEFT | RIGHT
  datatype facing = FLEFT | FRIGHT

  (* bot flags *)
  structure BF :>
  sig
      include FLAG
      val ONGROUND : flag
  end =
  struct
      open Flag
      val ONGROUND = 0
      val NFLAGS = 1
      val flags = nflags NFLAGS
  end

  val botx = ref 50
  val boty = ref 50
  val botface = ref FRIGHT
  (* position of top-left of scroll window *)
  val scrollx = ref 0
  val scrolly = ref 0
  (* (* in sixteenths of a pixel per frame *) *)
  val botdx = ref 0
  val botdy = ref 0
  val botstate = BF.flags

  val paused = ref false
  val advance = ref false

  datatype intention =
      I_GO of dir
    | I_JUMP

  fun dtos LEFT = "left"
    | dtos RIGHT = "right"
    | dtos UP = "up"
    | dtos DOWN = "down"

  fun inttos (I_GO d) = "go " ^ dtos d
    | inttos I_JUMP = "jump"

  fun intends il i = List.exists (fn x => x = i) il

  (* number of pixels per frame that we can walk at maximum *)
  val MAXWALK = 4
  val TERMINAL_VELOCITY = 5
  val JUMP_VELOCITY = 12

  (* make sure bot's in the scroll window! *)
  fun setscroll () =
    let
    in
      (* stay in the center third of the screen. *)
      if !botx - !scrollx < (width div 3)
      then (print "left edge\n";
            scrollx := !botx - (width div 3))
      else if (!scrollx + width) - !botx < (width div 3)
           then (print "right edge\n";
                 scrollx := !botx - 2 * (width div 3))
           else ();

      if !boty - !scrolly < (height div 3)
      then (print "top edge\n";
            scrolly := !boty - (height div 3))
      else if (!scrolly + height) - !boty < (height div 3)
           then (print "bottom edge\n";
                 scrolly := !boty - 2 * (height div 3))
           else ()

    end

  fun setfreq n =
      let in
          freq := n;
          setfreq_ n;
          (* PERF *)
          clearsurface (screen, color (0w0, 0w0, 0w0, 0w0));
          blitall (robotl, screen, n, 32);
          flip screen
      end


  fun loop { nexttick, intention } =
      if getticks () > nexttick
         andalso (not (!paused) orelse !advance)
      then 
          let
(*
              val () =               clearsurface (screen, color (0w0, 0w0, 0w0, 0w0))
              val () =               setscroll ()
              val () =               drawworld ()
              val () =               drawbot true
              val intention = movebot { nexttick = nexttick, intention = intention }
*)
          in
(*
              drawbot false;
              flip screen;
              advance := false;
*)
              key { nexttick = getticks() + 0w20, intention = intention }
          end
      else
          let in
              SDL.delay 0;
              key { nexttick = nexttick, intention = intention }
          end
              
              
  and key ( cur as { nexttick, intention = i } ) = 
    case pollevent () of
      SOME (E_KeyDown { sym = SDLK_ESCAPE }) => () (* quit *)

    | SOME (E_MouseMotion { xrel, yrel, ...}) =>
        let in 
          botdx := !botdx + xrel; botdy := !botdy + yrel;
          botdx := (if !botdx > 4 then 4
                   else (if !botdx < ~4 then ~4
                         else !botdx));
          botdy := (if !botdy > 4 then 4
                    else (if !botdy < ~4 then ~4
                          else !botdy));
          loop cur
        end

    | SOME (E_KeyDown { sym = SDLK_RETURN }) =>
        let in
          paused := not (!paused);
          loop cur
        end

    | SOME (E_KeyDown { sym = SDLK_PERIOD }) => 
        let in
          advance := true;
          loop cur
        end

    | SOME (E_KeyDown { sym = SDLK_q }) =>
        (setfreq 256;
         loop cur)

    | SOME (E_KeyDown { sym = SDLK_w }) =>
        (setfreq 400;
         loop cur)

    | SOME (E_KeyDown { sym = SDLK_e }) =>
        (setfreq 512;
         loop cur)


    | SOME (E_KeyDown { sym = SDLK_i }) =>
        (scrolly := !scrolly - 3;
         loop cur)
    | SOME (E_KeyDown { sym = SDLK_j }) =>
        (scrollx := !scrollx - 3;
         loop cur)
    | SOME (E_KeyDown { sym = SDLK_k }) =>
        (scrolly := !scrolly + 3;
         loop cur)
    | SOME (E_KeyDown { sym = SDLK_l }) =>
        (scrollx := !scrollx + 3;
         loop cur)

(*
    | SOME (E_KeyDown { sym = SDLK_b }) => 
        loop { nexttick = nexttick, intention = I_BOOST :: i }
*)

    | SOME (E_KeyDown { sym = SDLK_LEFT }) =>
        (setfreq (!freq - 50);
         loop cur)

    | SOME (E_JoyDown { button = 0, ... }) =>
        (* XXX for these there should also be an impulse event,
           so that when I tap the left key ever so quickly, I at least
           start moving left for one frame. *)
          (botface := FLEFT;
           if intends i (I_GO LEFT)
           then loop { nexttick = nexttick, intention = i }
           else loop { nexttick = nexttick, intention = (I_GO LEFT :: i) })


    | SOME (E_KeyDown { sym = SDLK_SPACE }) =>
          if intends i (I_JUMP)
          then loop { nexttick = nexttick, intention = i }
          else loop { nexttick = nexttick, intention = (I_JUMP :: i) }

    | SOME (E_JoyDown { button = 3, ... }) =>
          if intends i (I_JUMP)
          then loop { nexttick = nexttick, intention = i }
          else loop { nexttick = nexttick, intention = (I_JUMP :: i) }

    | SOME (E_KeyDown { sym = SDLK_RIGHT }) =>
        (setfreq (!freq + 30);
         loop cur)

    | SOME (E_JoyDown { button = 1, ... }) =>
          (botface := FRIGHT;
           if intends i (I_GO RIGHT)
           then loop { nexttick = nexttick, intention = i }
           else loop { nexttick = nexttick, intention = I_GO RIGHT :: i })

(*
    | SOME (E_KeyDown { sym = SDLK_c }) => 
          (showclip := not (!showclip);
           loop cur)
*)

    | SOME (E_KeyUp { sym = SDLK_SPACE }) =>
          (* these 'impulse' events are not turned off by a key going up! 
             (actually, I guess jump should work like l/r in that if
             I hold the jump button I should go higher than if I tap it.)

             *)
    (* loop { nexttick = nexttick, intention = List.filter (fn I_JUMP => false | _ => true) i } *)
          loop cur

    | SOME (E_KeyUp { sym = SDLK_LEFT }) =>
            (loop { nexttick = nexttick, intention = List.filter (fn I_GO LEFT => false | _ => true) i })

    | SOME (E_JoyUp { button = 0, ... }) =>
            (loop { nexttick = nexttick, intention = List.filter (fn I_GO LEFT => false | _ => true) i })

    | SOME (E_KeyUp { sym = SDLK_RIGHT }) =>
              loop { nexttick = nexttick, intention = List.filter (fn I_GO RIGHT => false | _ => true) i }

    | SOME (E_JoyUp { button = 1, ... }) =>
            (loop { nexttick = nexttick, intention = List.filter (fn I_GO RIGHT => false | _ => true) i })

    | SOME (E_JoyDown { which, button }) =>  
            let in
                print ("unknown joydown " ^ Int.toString which ^ ":" ^
                       Int.toString button ^ "\n");
                loop cur
            end
    | SOME (E_JoyUp { which, button }) =>  
            let in
                print ("unknown joyup " ^ Int.toString which ^ ":" ^
                       Int.toString button ^ "\n");
                loop cur
            end

    | SOME (E_KeyDown { sym }) =>
          let in
              print ("unknown key " ^ SDL.sdlktos sym ^ "\n");
              loop { nexttick = nexttick, intention = i }
          end

    | SOME E_Quit => ()
    | _ => loop cur

  val () = loop { nexttick = 0w0, intention = nil }
    handle Test s => messagebox ("exn test: " ^ s)
        | SDL s => messagebox ("sdl error: " ^ s)
        | e => messagebox ("Uncaught exception: " ^ exnName e ^ " / " ^ exnMessage e)

end
