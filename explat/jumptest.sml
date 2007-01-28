
structure Test =
struct

  type ptr = MLton.Pointer.t

  exception Nope

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

  (* the mask tells us where things can walk *)
  datatype slope = LM | MH | HM | ML
  datatype mask = MEMPTY | MSOLID | MRAMP of slope (* | MCEIL of slope *)

  val world = Array.array(TILESW * TILESH, MEMPTY)
  fun worldat (x, y) = Array.sub(world, y * TILESW + x)
  fun setworld (x, y) m = Array.update(world, y * TILESW + x, m)
  val () = Util.for 0 (TILESW - 1) (fn x => setworld (x, TILESH - 1) MSOLID)

  fun tilefor MSOLID = solid
    | tilefor _ = raise Nope

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
  val MAXWALK = 2
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
          val (dy, y) = if dy > 0 andalso 
                           y >= ((TILESH - 1) * TILEH) - ROBOTH
                        then (0, ((TILESH - 1) * TILEH) - ROBOTH)
                        else (dy, y + dy)

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
              val intention = movebot { nexttick = nexttick, intention = intention }
          in
              clearsurface (screen, color (0w0, 0w0, 0w0, 0w0));
              drawworld ();
              drawbot ();
              flip screen;
              key { nexttick = getticks() + 0w5, intention = intention }
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

    | SOME (E_KeyDown { sym = SDLK_k }) =>
          (botface := FLEFT;
           if intends i (I_GO LEFT)
           then loop { nexttick = nexttick, intention = i }
           else loop { nexttick = nexttick, intention = (I_GO LEFT :: i) })

    | SOME (E_KeyDown { sym = SDLK_SPACE }) =>
          if intends i (I_JUMP)
          then loop { nexttick = nexttick, intention = i }
          else loop { nexttick = nexttick, intention = (I_JUMP :: i) }

    | SOME (E_KeyDown { sym = SDLK_l }) =>
          (botface := FRIGHT;
           if intends i (I_GO RIGHT)
           then loop { nexttick = nexttick, intention = i }
           else loop { nexttick = nexttick, intention = I_GO RIGHT :: i })

    | SOME (E_KeyUp { sym = SDLK_SPACE }) =>
              loop { nexttick = nexttick, intention = List.filter (fn I_JUMP => false | _ => true) i }

    | SOME (E_KeyUp { sym = SDLK_k }) =>
            (print "LEFT_UP\n";
             loop { nexttick = nexttick, intention = List.filter (fn I_GO LEFT => false | _ => true) i })

    | SOME (E_KeyUp { sym = SDLK_l }) =>
              loop { nexttick = nexttick, intention = List.filter (fn I_GO RIGHT => false | _ => true) i }

    | SOME E_Quit => ()
    | _ => loop { nexttick = nexttick, intention = i }

  val () = loop { nexttick = 0w0, intention = nil }
    handle e => messagebox ("Uncaught exception: " ^ exnName e ^ " / " ^ exnMessage e)

end
