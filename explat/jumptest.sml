
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

  val width = 320
  val height = 240

  val TILEW = 16
  val TILEH = 16
  val TILESW = width div 16
  val TILESH = height div 16

  val ROBOTH = 32
  val ROBOTW = 16

  val screen = makescreen (width, height)

  fun requireimage s =
    case Image.load s of
      NONE => (print ("couldn't open " ^ s ^ "\n");
               raise Nope)
    | SOME p => p

  val robotr = requireimage "testgraphics/robot.png"
  val robotl = requireimage "testgraphics/robotl.png" (* XXX should be able to flip graphics *)
  val solid = requireimage "testgraphics/solid.png"

  val redhi = requireimage "testgraphics/redhighlight.png"
  val greenhi = requireimage "testgraphics/greenhighlight.png"
  val robobox = requireimage "testgraphics/robobox.png"

  val ramp_lm = requireimage "testgraphics/rampup1.png"
  val ramp_mh = requireimage "testgraphics/rampup2.png"

  (* the mask tells us where things can walk *)
  datatype slope = LM | MH | HM | ML
  datatype mask = MEMPTY | MSOLID | MRAMP of slope (* | MCEIL of slope *)

  fun ttos MEMPTY = "empty"
    | ttos MSOLID = "solid"
    | ttos (MRAMP _) = "ramp?"

  val world = Array.array(TILESW * TILESH, MEMPTY)
  (* XXX do we really want to trap subscript? *)
  fun worldat (x, y) = Array.sub(world, y * TILESW + x) 
      handle Subscript => if y > 0 then MSOLID else MEMPTY

  fun setworld (x, y) m = Array.update(world, y * TILESW + x, m)
  val () = Util.for 0 (TILESW - 1) (fn x => setworld (x, TILESH - 1) MSOLID)
  val () = Util.for 4 (TILESW - 1) (fn x => setworld(x, TILESH - 1 - (x div 2)) (MRAMP (if x mod 2 = 0
                                                                                        then LM
                                                                                        else MH)))
  val () = Util.for 0 (Int.min (TILESW, TILESH) - 1) (fn x => 
                                                      if x mod 3 = 0 
                                                      then setworld (x, TILESH - 1 - x) MSOLID
                                                      else ())


  fun tilefor MSOLID = solid
    | tilefor (MRAMP LM) = ramp_lm
    | tilefor (MRAMP MH) = ramp_mh

  fun drawworld () =
    Util.for 0 (TILESW - 1)
    (fn x =>
     Util.for 0 (TILESH - 1)
     (fn y =>
      case worldat (x, y) of
        MEMPTY => ()
      | t => blitall (tilefor t, screen, x * TILEW, y * TILEH)))

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
  (* (* in sixteenths of a pixel per frame *) *)
  val botdx = ref 0
  val botdy = ref 0
  val botstate = BF.flags

  fun drawbot () =
      let val img = 
          (case !botface of
               FLEFT => robotl
             | FRIGHT => robotr)
      in
          blitall (img, screen, !botx, !boty)
      end

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
  val MAXWALK = 3
  val TERMINAL_VELOCITY = 3
  val JUMP_VELOCITY = 12

  fun movebot { nexttick, intention = i } =
      (* first, react to the player's intentions *)
      let
          val dx = !botdx
          val dy = !botdy
          val x = !botx
          val y = !boty
              
          (* val () = print (StringUtil.delimit ", " (map Int.toString [dx, dy, x, y])); *)
          val () = 
              case i of
                  nil => () 
                | _ => print (StringUtil.delimit " & " (map inttos i) ^ "\n")

          val dx =
              if intends i (I_GO LEFT)
                 andalso dx > ~ MAXWALK
              then dx - 1
              else dx
          val dx = 
              if intends i (I_GO RIGHT)
                 andalso dx < MAXWALK
              then dx + 1
              else dx

          (* and if we don't intend to move at all, slow us down *)
          val dx = 
              if not (intends i (I_GO RIGHT)) andalso
                 not (intends i (I_GO LEFT))
              then (if dx > 0 then dx - 1
                    else if dx < 0 then dx + 1 else 0)
              else dx
                  
          (* XXX jumping -- only when not in air already! *)

          val (dy, i) = if intends i (I_JUMP)
                        then (dy - JUMP_VELOCITY,
                              List.filter (fn I_JUMP => false | _ => true) i)
                        else (dy, i)

          (* falling *)
          val dy = if dy <= TERMINAL_VELOCITY 
                   then dy + 1
                   else dy

          (* XXX world effects... *)

          (* now try moving in that direction *)
          (* XXX this collision detection needs to be much more sophisticated, of course! *)
          val (dy, y) =
              (* 
                 simple: if the tile we're currently on, or the
                 tile below it, has any kind of clip, and we would
                 hit it this frame, then snap. Do this for both left
                 and right feet and take the min. *)
              if (dy > 0)
              then
                  let
                      (* look at its bottom *)
                      val y = y + ROBOTH

                      (* give the x coordinate to use... *)
                      fun vdrop x =
                          let
                              val xt = x div TILEW
                              val yt1 = y div TILEH
                              val yt2 = (y + dy) div TILEH
                                  
                              fun snap (yt, dist) =
                                  (case worldat (xt, yt) of
                                       MEMPTY => raise Test "can't snap to empty, duh"
                                     | MSOLID => (print ("snapped to yt=" ^ Int.toString yt ^ " (dist="
                                                         ^ Int.toString dist ^ ")\n");
                                                  (0, yt * TILEH - 1))
                                     | MRAMP sl => 
                                           let
                                               (* the distance from the bottom of the tile *)
                                               val yint =
                                                   (case sl of
                                                        (* XXX no constants like 8 *)
                                                        LM => (* ramps 0..8 *)     (x mod TILEW div 2)
                                                      | MH => (*       8..f *) 8 + (x mod TILEW div 2)
                                                      | _ => raise Test "ramps not supported"
                                                            )

                                               val mdist = TILEH - yint
                                               val dodist = Int.min(dist, mdist)
                                           in
                                               if (dist < mdist)
                                               then (* go all the way *)
                                                   (dy, yt * TILEH + dist)
                                               else (0, yt * TILEH + mdist)
                                           end
                                           )
                          in
                              (* drawpixel (screen, x - 1, y - 1, color (0wxFF, 0w0, 0w0, 0wxFF)); *)
                              blitall(greenhi, screen, xt * TILEW, yt1 * TILEH);
                              blitall(redhi,   screen, xt * TILEW, yt2 * TILEH);
                              print ("Vdrop: x: " ^ Int.toString x ^ " y: " ^ Int.toString y ^
                                     " dy: " ^ Int.toString dy ^ 
                                     " xt: " ^ Int.toString xt ^ 
                                     " yt1: " ^ Int.toString yt1 ^ "(" ^ ttos (worldat (xt, yt1)) ^ ")" ^
                                     " yt2: " ^ Int.toString yt2 ^ "(" ^ ttos (worldat (xt, yt2)) ^ ")" ^
                                     "\n");
                              (* if our current location stops us, then stop *)
                              (case worldat(xt, yt1) of
                                   MEMPTY =>
                                   (* are we going to enter the next spot? *)
                                       if yt1 <> yt2 
                                       then (case worldat(xt, yt2) of
                                                 MEMPTY => (* just drop, safely *)
                                                           (dy, y + dy)
                                               (* otherwise snap *)
                                               | _ => snap (yt2, (y + dy) mod TILEH))
                                       else (dy, y + dy)
                                     | _ => snap (yt1, dy))
                                   
                          end

                      val () = print "-- drop stop --\n"
                      val (dyl, yl) = vdrop (x + 0)
                      val (dyr, yr) = vdrop (x + (ROBOTW - 1))
                  in

                      if yl < yr
                      then (dyl, yl - ROBOTH)
                      else (dyr, yr - ROBOTH)
                  end
              else (dy, y)

                  (*
          val (dy, y) = if dy > 0 andalso 
                           y >= ((TILESH - 1) * TILEH) - ROBOTH
                        then (0, ((TILESH - 1) * TILEH) - ROBOTH)
                        else (dy, y + dy)
                        *)

          (* then do it: *)
          val (dy, y) = (dy, y + dy)
          val (dx, x) = (dx, x + dx)
      in
          (* print (" -> " ^ StringUtil.delimit ", " (map Int.toString [dx, dy, x, y]) ^ "\n"); *)
          botdx := dx;
          botdy := dy;
          botx := x;
          boty := y;
          i
      end 
                  
  fun loop { nexttick, intention } =
      if getticks () > nexttick
      then 
          let
              val () =               clearsurface (screen, color (0w0, 0w0, 0w0, 0w0))
              val () =               drawworld ()
              val intention = movebot { nexttick = nexttick, intention = intention }
          in

              drawbot ();
              flip screen;
              key { nexttick = getticks() + 0w20, intention = intention }
          end
      else
          let in
              SDL.delay 1;
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

    | SOME (E_KeyDown { sym = SDLK_LEFT }) =>
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

    | SOME (E_KeyDown { sym = SDLK_RIGHT }) =>
          (botface := FRIGHT;
           if intends i (I_GO RIGHT)
           then loop { nexttick = nexttick, intention = i }
           else loop { nexttick = nexttick, intention = I_GO RIGHT :: i })

    | SOME (E_KeyDown { sym }) =>
          let in
              print ("unknown key " ^ SDL.sdlktos sym ^ "\n");
              loop { nexttick = nexttick, intention = i }
          end

    | SOME (E_KeyUp { sym = SDLK_SPACE }) =>
          (* these 'impulse' events are not turned off by a key going up! 
             (actually, I guess jump should work like l/r in that if
             I hold the jump button I should go higher than if I tap it.)

             *)
    (* loop { nexttick = nexttick, intention = List.filter (fn I_JUMP => false | _ => true) i } *)
          loop cur

    | SOME (E_KeyUp { sym = SDLK_LEFT }) =>
            (loop { nexttick = nexttick, intention = List.filter (fn I_GO LEFT => false | _ => true) i })

    | SOME (E_KeyUp { sym = SDLK_RIGHT }) =>
              loop { nexttick = nexttick, intention = List.filter (fn I_GO RIGHT => false | _ => true) i }

    | SOME E_Quit => ()
    | _ => loop cur

  val () = loop { nexttick = 0w0, intention = nil }
    handle Test s => messagebox ("exn test: " ^ s)
        | SDL s => messagebox ("sdl error: " ^ s)
        | e => messagebox ("Uncaught exception: " ^ exnName e ^ " / " ^ exnMessage e)

end
