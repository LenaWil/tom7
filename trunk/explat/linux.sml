
structure Test =
struct

  type ptr = MLton.Pointer.t

  exception Nope

  val init = _import "ml_init" : unit -> int ;
  val mkscreen = _import "ml_makescreen" : int * int -> ptr ;
  val loadpng = _import "IMG_Load" : string -> ptr ;
  val loadpng = fn s => loadpng (s ^ "\000")
  val flip = _import "SDL_Flip" : ptr -> unit ;
  val blit = _import "ml_blitall" : ptr * ptr * int * int -> unit ;
  val surface_width = _import "ml_surfacewidth" : ptr -> int ;
  val surface_height = _import "ml_surfaceheight" : ptr -> int ;
  val clearsurface = _import "ml_clearsurface" : ptr * Word32.word -> unit ;
  val newevent = _import "ml_newevent" : unit -> ptr ;
  val free = _import "free" : ptr -> unit ;
  val eventtag = _import "ml_eventtag" : ptr -> int ;

  datatype event =
    E_Active
  | E_KeyDown
  | E_KeyUp
  | E_MouseMotion
  | E_MouseDown
  | E_MouseUp
  | E_JoyAxis
  | E_JoyDown
  | E_JoyUp
  | E_JoyHat
  | E_JoyBall
  | E_Resize
  | E_Expose
  | E_SysWM
  | E_User
  | E_Quit
  | E_Unknown

  fun convertevent e =
   (* XXX need to get props too... *)
    (case eventtag e of
       1 => E_Active
     | 2 => E_KeyDown
     | 3 => E_KeyUp
     | 4 => E_MouseMotion
     | 5 => E_MouseDown
     | 6 => E_MouseUp
     | 7 => E_JoyAxis
     | 8 => E_JoyBall
     | 9 => E_JoyHat
     | 10 => E_JoyDown
     | 11 => E_JoyUp
     | 12 => E_Quit
     | 13 => E_SysWM
(* reserved..
     | 14 => 
     | 15 =>
*)
     | 16 => E_Resize
     | 17 => E_Expose
     | _ => E_Unknown
       )

  fun pollevent () =
    let
      val p = _import "SDL_PollEvent" : ptr -> int ;
      val e = newevent ()
    in
      case p e of
        0 => 
          let in
          (* no event *)
            free e;
            NONE
          end
      | _ =>
          let 
            val ret = convertevent e
          in
            free e;
            SOME ret
          end
    end

  val () = print "Let's go!\n";
  val () = case init () of
             0 => 
               let in
                 print "SDL failed to initialize.\n";
                 raise Nope
               end
           | _ => ()

  val width = 640
  val height = 480

  val screen = mkscreen (width, height)

  val graphic = loadpng "icon.png"
  val w = surface_width graphic
  val h = surface_height graphic

  val gravity = 0.1

  fun damp d = d * 0.9

  fun goone (dx, dy, x, y) =
    let
      
      val x = x + dx
      val y = y + dy
      
      val dy = dy + gravity

    (* bounces *)
      val (x, dx) = if x < 0.0 then (0.1, damp (0.0 - dx))
                    else if (x + real w > real width)
                         then (real width - (real w + 0.1), damp (0.0 - dx))
                         else (x, dx)

      val (y, dy) = if y < 0.0 then (0.1, damp (0.0 - dy))
                    else if (y + real h > real height)
                         then (real height - (real h + 0.1), damp (0.0 - dy))
                         else (y, dy)

    in
      (dx, dy, x, y)
    end

  fun random () =
    real (Word.toInt (Word.andb (0wxFFFFFF, MLton.Random.rand ()))) / real 0xFFFFFF

  fun loop l =
    let
      val l = map goone l

    in
      clearsurface (screen, 0wx000000);
      app (fn (_, _, x, y) => blit (graphic, screen, trunc x, trunc y)) l;
      flip screen;
      key l
    end

  and key l =
    case pollevent () of
      SOME E_KeyDown => loop (map (fn (dx, dy, x, y) => (dx + (10.0 * random () - 5.0), dy + (10.0 * random () - 5.0), x, y)) l)
    | SOME E_Quit => ()
    | _ => loop l

  val () = loop 
    (List.tabulate(50,
                   fn x =>
                   (real x, real x, 50.0, 50.0)))

end
