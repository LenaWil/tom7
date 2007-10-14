
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

  val showclip = ref false

  val width = 640
  val height = 480

  val TILESW = width div Tile.TILEW
  val TILESH = height div Tile.TILEH

  val ROBOTH = 32
  val ROBOTW = 16

  open Tile
  open World

  val screen = makescreen (width, height)

  fun requireimage s =
      let val s = "testgraphics/" ^ s
      in
          case Image.load s of
              NONE => (print ("couldn't open " ^ s ^ "\n");
                       raise Nope)
            | SOME p => p
      end

  structure Font = FontFn (val surf = requireimage "font.png"
                           val charmap =
                           " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" ^
                           "`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?" (* \" *)
                           (* CHECKMARK ESC HEART LCMARK1 LCMARK2 BAR_0 BAR_1 BAR_2 BAR_3 
                              BAR_4 BAR_5 BAR_6 BAR_7 BAR_8 BAR_9 BAR_10 BARSTART LRARROW LLARROW *)
                           val width = 9
                           val height = 16
                           val styles = 6
                           val overlap = 1
                           val dims = 3)

  val robotr = requireimage "robot.png"
  val robotl = requireimage "robotl.png" (* XXX should be able to flip graphics *)
  val robotr_fade = alphadim robotr
  val robotl_fade = alphadim robotl
  val error = requireimage "error_frame.png"

  val redhi = requireimage "redhighlight.png"
  val greenhi = requireimage "greenhighlight.png"
  val robobox = requireimage "robobox.png"

  val star = requireimage "redstar.png"
  val spider_up = requireimage "spider_up.png"
  val spider_down = requireimage "spider_down.png"

  val fireballr = requireimage "fireball.png"
  val fireballl = requireimage "fireball_left.png"

  fun ttos MEMPTY = "empty"
    | ttos MSOLID = "solid"
    | ttos (MRAMP _) = "ramp?"

  datatype dir = UP | DOWN | LEFT | RIGHT
  datatype facing = FLEFT | FRIGHT
  datatype intention =
      I_GO of dir
    | I_JUMP
    | I_BOOST

  fun dir_reverse UP = DOWN
    | dir_reverse DOWN = UP
    | dir_reverse LEFT = RIGHT
    | dir_reverse RIGHT = LEFT

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
  val boty = ref 150
  val botface = ref FRIGHT
  (* position of top-left of scroll window, in pixels *)
  val scrollx = ref 0
  val scrolly = ref 0
  (* (* in sixteenths of a pixel per frame *) *)
  val botdx = ref 0
  val botdy = ref 0
  val botstate = BF.flags

  datatype monster = STAR | SPIDER

  datatype object =
      Bullet   of { dx : int, dy : int, x : int, y : int }
    | Monster  of { which : monster, dir : dir, dx : int, dy : int, x : int, y : int }

  val objects = ref (nil : object list)
      
  val paused = ref false
  val advance = ref false

  fun onscreen (x, y) =
      SOME ((x + !scrollx) div TILEW,
            (y + !scrolly) div TILEH)

  datatype zone = ZBG | ZFG | ZMASK

  val editzone = ref ZBG
  val editx = ref 100
  val edity = ref 100
  val editbgtile = ref (Tile.fromword 0w1)
  val editfgtile = ref (Tile.fromword 0w0)
  val editmask = ref Tile.MSOLID
  val editmenucolor = SDL.color (0wx44, 0wx14, 0wx14, 0wxFF)
  val editzonecolor = SDL.color (0wxFF, 0wx14, 0wx14, 0wxFF)
  val showedit = ref false
  local
      (* in tiles *)
      val EDITW = 16
      val EDITH = 7
      val MARGIN = 4
      val MARGIN_TOP = 18
          
      val MASKS = 
          Vector.fromList 
          [ MEMPTY, MSOLID,
            MRAMP LM, MRAMP MH, MRAMP HM, MRAMP ML,
            MDIAG NW, MDIAG NE, MDIAG SW, MDIAG SE,
            MCEIL LM, MCEIL MH, MCEIL HM, MCEIL ML,
            MLEFT LM, MLEFT MH, MLEFT HM, MLEFT ML,
            MRIGHT LM, MRIGHT MH, MRIGHT HM, MRIGHT ML

            (* XXX more *)
            ]

  in
      fun drawedit now =
          if !showedit
          then
             let
             in
                 (* menu border *)
                 SDL.fillrect (screen, !editx, !edity,
                               EDITW * TILEW + (MARGIN * 2),
                               EDITH * TILEH + (MARGIN * 2 + MARGIN_TOP),
                               editmenucolor);

                 (* indicate the zone *)
                 SDL.fillrect (screen, 
                               !editx + (MARGIN - 2) +
                               ((TILEW + 2) *
                                (case !editzone of
                                     ZBG => 0
                                   | ZFG => 1
                                   | ZMASK => 2)), 
                               !edity + (MARGIN - 2),
                               TILEW + 4,
                               TILEH + 4,
                               editzonecolor);

                 Font.draw_plain(screen, 
                                 !editx + TILEW * 6,
                                 !edity + 1,
                                 (case !editzone of
                                      ZBG => "background"
                                    | ZFG => "foreground"
                                    | ZMASK => "mask"));

                 (* the background, foreground, mask *)
                 Tile.draw (now,
                            !editbgtile, screen,
                            !editx + MARGIN,
                            !edity + MARGIN);
                 Tile.draw (now,
                            !editfgtile, screen,
                            !editx + MARGIN + TILEW + 2,
                            !edity + MARGIN);

                 case !editzone of
                     ZMASK =>
                        (Util.for 0 (EDITH - 1)
                         (fn y =>
                          Util.for 0 (EDITW - 1)
                          (fn x =>
                           (* might subscript *)
                           let val m = Vector.sub (MASKS, EDITW * y + x)
                           in
                               Tile.drawmask (m, screen,
                                              !editx + MARGIN + (TILEW * x),
                                              !edity + MARGIN + MARGIN_TOP + (TILEH * y))
                           end)) handle Subscript => ())
                   | _ =>
                         Util.for 0 (EDITH - 1)
                         (fn y =>
                          Util.for 0 (EDITW - 1)
                          (fn x =>
                           let val t = Tile.fromword (Word32.fromInt (EDITW * y + x))
                           in
                               Tile.draw (now,
                                          t, screen, 
                                          !editx + MARGIN + (TILEW * x),
                                          !edity + MARGIN + MARGIN_TOP + (TILEH * y))
                           end))
             end
          else ()

      fun edit_hit (x, y) =
          if !showedit 
             andalso x >= !editx 
             andalso y >= !edity
             andalso x < !editx + (MARGIN * 2) + (TILEW * EDITW)
             andalso y < !edity + (MARGIN * 2 + MARGIN_TOP) + (TILEH * EDITH)
          then
              let 
                  (* XXX Should also allow window dragging (but do that
                     in a general way) *)
                  (* XXX Should allow to click fg/bg/mask to switch to
                     editing that zone *)
                  (* in tiles *)
                  val x = x - (!editx + MARGIN)
                  val y = y - (!edity + MARGIN_TOP + MARGIN)

                  val idx = ((y div TILEH) * EDITW + (x div TILEW))
              in
                  if idx >= 0
                  then
                      let in
                          print ("tile/mask " ^ Int.toString idx ^ "\n");
                          (case !editzone of
                               ZMASK =>
                                   if idx >= 0 andalso idx < Vector.length MASKS
                                   then editmask := Vector.sub(MASKS, idx)
                                   else ()
                             | ZBG => editbgtile := Tile.fromword (Word32.fromInt idx)
                             | ZFG => editfgtile := Tile.fromword (Word32.fromInt idx))
                      end
                  else ();
                  true
              end
          else false
  end

  (* draw a view of the world where the top left of
     the screen is at scrollx/scrolly *)
  fun drawworld (now, layer) =
    let
      (* tlx/tly is the (screen coordinate pixel) point 
         at which we draw the top-left tile. it is nonpositive *)
      val tlx = 0 - (!scrollx mod TILEW)
      val tly = 0 - (!scrolly mod TILEH)
        
      (* this is the tile number (world absolute) that we start
         by drawing *)
      val xstart = !scrollx div TILEW
      val ystart = !scrolly div TILEH
    in
      case layer of
        (* not really a layer, but useful when editing / debugging *)
        (* XXX I guess a different datatype, option is weird *)
        NONE =>
        (* nb, always doing one extra tile, because we might
           display only partial tiles if not aligned to scroll
           view *)
          Util.for 0 TILESW
          (fn x =>
           Util.for 0 TILESH
           (fn y =>
            case maskat (xstart + x, ystart + y) of
                MEMPTY => ()
              | m => Tile.drawmask(m, screen, 
                                   tlx + (x * TILEW), tly + (y * TILEH))
                    ))
      | SOME layer => 
          Util.for 0 TILESW
          (fn x =>
           Util.for 0 TILESH
           (fn y =>
            Tile.draw (now,
                       World.tileat(layer, xstart + x, ystart + y), screen, 
                       tlx + (x * TILEW),
                       tly + (y * TILEH))
            ))
    end

  fun drawobjects () =
      let
          fun doobj (Bullet { x, y, dx, dy }) =
              blitall (if dx > 0 then fireballr
                       else fireballl, screen,
                       x - !scrollx, y - !scrolly)
            | doobj (Monster { which, dx, dy, x, y, dir }) =
              blitall ((case (dir, which, dy) of 
                            (_, STAR, _) => star
                          | (_, SPIDER, 0) => spider_down
                          | (_, SPIDER, _) => spider_up
                          | _ => error),
                       screen,
                       x - !scrollx, y - !scrolly)
      in
          app doobj (!objects)
      end

  fun drawbot fade =
      let val img = 
          (case (!botface, fade) of
               (FLEFT, false) => robotl
             | (FLEFT, true) => robotl_fade
             | (FRIGHT, false) => robotr
             | (FRIGHT, true) => robotr_fade)
      in
          blitall (img, screen, !botx - !scrollx, !boty - !scrolly)
      end

  fun dtos LEFT = "left"
    | dtos RIGHT = "right"
    | dtos UP = "up"
    | dtos DOWN = "down"

  fun inttos (I_GO d) = "go " ^ dtos d
    | inttos I_JUMP = "jump"
    | inttos I_BOOST = "boost"

  fun intends il i = List.exists (fn x => x = i) il

  (* number of pixels per frame that we can walk at maximum *)
  val MAXWALK = 4
  val TERMINAL_VELOCITY = 8
  val JUMP_VELOCITY = 16

  (* make sure bot's in the scroll window! *)
  fun setscroll () =
    let
    in
      (* stay in the center third of the screen. *)
      if !botx - !scrollx < (width div 3)
      then ((* print "left edge\n"; *)
            scrollx := !botx - (width div 3))
      else if (!scrollx + width) - !botx < (width div 3)
           then ((* print "right edge\n"; *)
                 scrollx := !botx - 2 * (width div 3))
           else ();

      if !boty - !scrolly < (height div 3)
      then ((* print "top edge\n"; *)
            scrolly := !boty - (height div 3))
      else if (!scrolly + height) - !boty < (height div 3)
           then ((* print "bottom edge\n"; *)
                 scrolly := !boty - 2 * (height div 3))
           else ()

    end

  (* Move an entity, which is a solid object that has intentions *)
  fun moveent clip (i, x, y, dx, dy) =
      let
          (* val () = print (StringUtil.delimit ", " (map Int.toString [dx, dy, x, y]) ^ "\n") *)
              (*
          val () = 
              case i of
                  nil => () 
                | _ => print (StringUtil.delimit " & " (map inttos i) ^ "\n")
                  *)

          (* XXX these maximums should also be parameters *)
          (* first, react to the entity's intentions: *)
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

          val (dx, i) = if intends i I_BOOST
                        then (dx * 2, List.filter (fn I_BOOST => false | _ => true) i)
                        else (dx, i)

          (* and if we don't intend to move at all, slow us down *)
          val dx = 
              if not (intends i (I_GO RIGHT)) andalso
                 not (intends i (I_GO LEFT))
              then (if dx > 0 then dx - 1
                    else if dx < 0 then dx + 1 else 0)
              else dx
                  
          (* jumping -- only when not in air already!
             (either way the intention goes away) *)
          val (dy, i) = 
            if intends i (I_JUMP)
               (* something to push off of.. *)
               andalso Clip.clipped clip (x, y + 1)
            then (dy - JUMP_VELOCITY,
                  List.filter (fn I_JUMP => false | _ => true) i)
            else (dy, List.filter (fn I_JUMP => false | _ => true) i)

          (* gravity *)
          val dy = dy + 1 

          (* air resistance *)
          val dx = if dx > TERMINAL_VELOCITY
                   then dx - 1
                   else if dx < ~ TERMINAL_VELOCITY
                        then dx + 1 
                        else dx

          val dy = if dy > TERMINAL_VELOCITY
                   then dy - 1
                   else if dy < ~ TERMINAL_VELOCITY
                        then dy + 1
                        else dy

          (* XXX world effects... *)

                       
          val (x, y, dx, dy) =
              let
                  val xi = if dx < 0 then ~1 else 1
                  val yi = if dy < 0 then ~1 else 1
                  val xr = ref x
                  val yr = ref y
                  val stopx = ref false
                  val stopy = ref false

                  (* Allow vertical movement if walking up a gradient *)
                  fun climb () =
                    (yr := !yr - 1;
                     true)

                  fun nudgex _ = 
                      let val next = !xr + xi
                      in
                          if !stopx 
                          then ()
                          else if Clip.clipped clip (next, !yr)
                               then 
                                   (* can move up a little if
                                      we are on a ramp:

                                      . .
                                      x #

                                      *)
                                   if not (Clip.clipped clip (!xr, !yr - 1)
                                           orelse
                                           Clip.clipped clip (next, !yr - 1))
                                      andalso climb()
                                   then xr := next
                                   else stopx := true
                               else xr := next
                      end

                  fun nudgey _ = 
                      let val next = !yr + yi
                      in
                          if !stopy orelse Clip.clipped clip (!xr, next)
                          then stopy := true
                          else yr := next
                      end

                  fun abs z = if z < 0 then ~ z else z

              in
                  (* try moving one pixel at a time
                     in the desired direction, until
                     it is not possible to move any 
                     more. *)
                  
                  (* XXX this calculation should probably
                     be symmetric. Here we do all of our
                     X movement before considering the Y
                     direction... *)

                  Util.for 0 (abs dx - 1) nudgex;
                  Util.for 0 (abs dy - 1) nudgey;

                  (!xr, !yr, 
                   if !stopx then 0 else dx, 
                   if !stopy then 0 else dy)
              end
      in
          (i, x, y, dx, dy)
      end 

  fun movebot { nexttick, intention } =
      let
          val (i, x, y, dx, dy) = moveent Clip.std (intention, !botx, !boty, !botdx, !botdy)
      in
          botx := x;
          boty := y;
          botdx := dx;
          botdy := dy;
          i
      end

  (* draws the actual clip mask calculated pixel-by-pixel *)
  fun drawdebug () =
    if !showclip
    then 
      let in
        (* print "DEBUG..\n"; *)
        Util.for 0 (width - 1)
        (fn x => 
         let in
           Util.for 0 (height - 1)
           (fn y =>
            let
              val xx = !scrollx + x
              val yy = !scrolly + y
              val tx = xx div TILEW
              val ty = yy div TILEH
            in
              (* tile mask, absolute *)
              case maskat (tx, ty) of
                MEMPTY => ()
              | m => 
                  if Tile.clipmask m (xx mod TILEW, yy mod TILEH)
                  then SDL.drawpixel (screen, x, y, color (0w255, 0w0, 0w0, 0w255))
                  else SDL.drawpixel (screen, x, y, color (0w0, 0w255, 0w0, 0w255))

              (* (* clip mask in config space *)
              if Clip.clipped Clip.std (!scrollx + x, !scrolly + y)
              then SDL.drawpixel (screen, x, y, color (0w255, 0w0, 0w0, 0w255))
              else SDL.drawpixel (screen, x, y, color (0w0, 0w255, 0w0, 0w255))
              *)
            end)
(*          ; if x mod 16 = 0 then flip screen else () *)
         end)
        (* print "DONE.\n" *)
      end
    else ()

  fun moveobjects () =
      let
          fun doobj (Bullet { x, y, dx, dy }) =
              let 
                  (* XX only dx supported now *)
                  val xi = if dx < 0 then ~1 else 1
                  val xr = ref x
                  val stopx = ref false
                  fun nudgex _ = 
                      let val next = !xr + xi
                      in
                          if !stopx orelse Clip.clipped Clip.bullet (next, y)
                          then stopx := true
                          else xr := next
                      end
              in
                  Util.for 0 (abs dx - 1) nudgex;
                  if !stopx then NONE
                  else SOME (Bullet { x = !xr, y = y, dx = dx, dy = dy })
              end
            | doobj (Monster { which, dir, x, y, dx, dy }) =
              let
                val clip = 
                    case which of
                        STAR => Clip.star
                      | SPIDER => Clip.spider
                val (_, x, y, dx, dy) = moveent clip ([I_GO dir, I_JUMP], x, y, dx, dy)
                val dir = if dx = 0
                          then dir_reverse dir
                          else dir

              in
                (* never goes away *)
                SOME (Monster { which = which, dir = dir, x = x, y = y, dx = dx, dy = dy })
              end
      in
          objects := List.mapPartial doobj (!objects)
      end

  fun drawmask iter =
      case (!showedit, !editzone) of
          (true, ZMASK) => drawworld (iter, NONE)
        | _ => ()

  fun loop { nexttick, intention, iter } =
      if getticks () > nexttick
         andalso (not (!paused) orelse !advance)
      then 
          let
              val () =               clearsurface (screen, color (0w0, 0w0, 0w0, 0w0))
              val () =               setscroll ()
              val () =               drawworld (iter, SOME BACKGROUND)
              val () =               drawdebug ()
              val () =               drawobjects ()
              val () =               drawbot true (* XXX shadow *)
              val intention = movebot { nexttick = nexttick, intention = intention }
              val () =               moveobjects ()
              val () =               drawbot false
              val () =               drawworld (iter, SOME FOREGROUND)
              val () =               drawmask iter
              val () =               drawedit iter
          in
              flip screen;
              advance := false;
              key { nexttick = getticks() + 0w20, intention = intention, iter = iter + 1 }
          end
      else
          let in
              SDL.delay 1;
              key { nexttick = nexttick, intention = intention, iter = iter }
          end
              
              

  and key ( cur as { nexttick, intention = i, iter } ) = 
    case pollevent () of
      SOME (E_KeyDown { sym = SDLK_ESCAPE }) => () (* quit *)

(*
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
*)

    | SOME (E_MouseDown { x, y, ... }) =>
          if edit_hit (x, y)
          then loop cur
          else
           let in
               (* XXX depend on the layer we're currently editing *)
               (case onscreen (x, y) of
                    NONE => print "offscreen click\n"
                  | SOME (tx, ty) => 
                        let in
                            print ("MB: " ^ Int.toString tx ^ " / " ^ 
                                   Int.toString ty ^ "\n");
                            case !editzone of
                                ZMASK => World.setmask (tx, ty) (!editmask)
                              | ZBG => World.settile (BACKGROUND, tx, ty) (!editbgtile)
                              | ZFG => World.settile (FOREGROUND, tx, ty) (!editfgtile)
                        end);
               loop cur
           end

    | SOME (E_KeyDown { sym = SDLK_LSHIFT }) => 
        let in
            (* fire bullet *)
            objects := Bullet { x = (case !botface of
                                         FLEFT => !botx - (surface_width fireballl)
                                       | FRIGHT => !botx + surface_width robotr),
                                y = !boty + 8,
                                dy = 0,
                                dx = (case !botface of
                                          FLEFT => ~8
                                        | FRIGHT => 8) } :: !objects;
            loop cur
        end

    | SOME (E_KeyDown { sym = SDLK_m }) => 
        let in
          objects := Monster { which = STAR,
                               x = (case !botface of
                                      FLEFT => !botx - (surface_width star)
                                    | FRIGHT => !botx + surface_width robotr),
                               dir = (case !botface of
                                      FLEFT => LEFT
                                    | FRIGHT => RIGHT),
                               y = !boty - 4,
                               dy = ~4,
                               dx = (case !botface of
                                       FLEFT => ~8
                                     | FRIGHT => 8) } :: !objects;
          loop cur
        end
    | SOME (E_KeyDown { sym = SDLK_n }) => 
        let in
          objects := Monster { which = SPIDER,
                               x = (case !botface of
                                      FLEFT => !botx - (surface_width star)
                                    | FRIGHT => !botx + surface_width robotr),
                               dir = (case !botface of
                                      FLEFT => LEFT
                                    | FRIGHT => RIGHT),
                               y = !boty - 4,
                               dy = ~4,
                               dx = (case !botface of
                                       FLEFT => ~8
                                     | FRIGHT => 8) } :: !objects;
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

    | SOME (E_KeyDown { sym = SDLK_s }) =>
        let in
          World.save ();
          print "SAVED.\n";
          loop cur
        end

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

    | SOME (E_KeyDown { sym = SDLK_b }) => 
        loop { nexttick = nexttick, intention = I_BOOST :: i, iter = iter }

    | SOME (E_KeyDown { sym = SDLK_LEFT }) =>
        (* XXX for these there should also be an impulse event,
           so that when I tap the left key ever so quickly, I at least
           start moving left for one frame. *)
          (botface := FLEFT;
           if intends i (I_GO LEFT)
           then loop { nexttick = nexttick, intention = i, iter = iter }
           else loop { nexttick = nexttick, intention = (I_GO LEFT :: i), iter = iter })

    | SOME (E_KeyDown { sym = SDLK_SPACE }) =>
          if intends i (I_JUMP)
          then loop { nexttick = nexttick, intention = i, iter = iter }
          else loop { nexttick = nexttick, intention = (I_JUMP :: i), iter = iter }

    | SOME (E_KeyDown { sym = SDLK_RIGHT }) =>
          (botface := FRIGHT;
           if intends i (I_GO RIGHT)
           then loop { nexttick = nexttick, intention = i, iter = iter }
           else loop { nexttick = nexttick, intention = I_GO RIGHT :: i, iter = iter })

    | SOME (E_KeyDown { sym = SDLK_e }) => 
          (showedit := not (!showedit);
           loop cur)

    | SOME (E_KeyDown { sym = SDLK_z }) => 
          (editzone :=
           (case !editzone of
                ZMASK => ZBG
              | ZBG => ZFG
              | ZFG => ZMASK);
           loop cur)

    | SOME (E_KeyDown { sym = SDLK_c }) => 
          (showclip := not (!showclip);
           loop cur)

    | SOME (E_KeyUp { sym = SDLK_SPACE }) =>
          (* these 'impulse' events are not turned off by a key going up! 
             (actually, I guess jump should work like l/r in that if
             I hold the jump button I should go higher than if I tap it.)

             *)
    (* loop { nexttick = nexttick, intention = List.filter (fn I_JUMP => false | _ => true) i } *)
          loop cur

    | SOME (E_KeyUp { sym = SDLK_LEFT }) =>
            (loop { nexttick = nexttick, intention = List.filter (fn I_GO LEFT => false | _ => true) i,
                    iter = iter })

    | SOME (E_KeyUp { sym = SDLK_RIGHT }) =>
              loop { nexttick = nexttick, intention = List.filter (fn I_GO RIGHT => false | _ => true) i,
                     iter = iter }

    | SOME (E_KeyDown { sym }) =>
          let in
              print ("unknown key " ^ SDL.sdlktos sym ^ "\n");
              loop { nexttick = nexttick, intention = i, iter = iter }
          end



    | SOME (E_JoyDown { button = 3, ... }) =>
          if intends i (I_JUMP)
          then loop { nexttick = nexttick, intention = i, iter = iter }
          else loop { nexttick = nexttick, intention = (I_JUMP :: i), iter = iter }

    | SOME (E_JoyDown { button = 1, ... }) =>
          (botface := FRIGHT;
           if intends i (I_GO RIGHT)
           then loop { nexttick = nexttick, intention = i, iter = iter }
           else loop { nexttick = nexttick, intention = I_GO RIGHT :: i, iter = iter })

    | SOME (E_JoyUp { button = 1, ... }) =>
            (loop { nexttick = nexttick, intention = List.filter (fn I_GO RIGHT => false | _ => true) i,
                    iter = iter })

    | SOME (E_JoyUp { button = 0, ... }) =>
            (loop { nexttick = nexttick, intention = List.filter (fn I_GO LEFT => false | _ => true) i,
                    iter = iter })

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


    | SOME E_Quit => ()
    | _ => loop cur

  (* XXX iter overflow possibility *)
  val () = loop { nexttick = 0w0, intention = nil, iter = 0 }
    handle Test s => messagebox ("exn test: " ^ s)
        | SDL s => messagebox ("sdl error: " ^ s)
        | e => messagebox ("Uncaught exception: " ^ exnName e ^ " / " ^ exnMessage e)

end
