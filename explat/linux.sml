
structure Test =
struct

  type ptr = MLton.Pointer.t

  exception Nope

  val init = _import "ml_test" : unit -> int ;
  val mkscreen = _import "ml_makescreen" : int * int -> ptr ;
  val loadpng = _import "IMG_Load" : string -> ptr ;
  val loadpng = fn s => loadpng (s ^ "\000")
  val flip = _import "SDL_Flip" : ptr -> unit ;
  val blit = _import "ml_blitall" : ptr * ptr * int * int -> unit ;
  val surface_width = _import "ml_surfacewidth" : ptr -> int ;
  val surface_height = _import "ml_surfaceheight" : ptr -> int ;
  val clearsurface = _import "ml_clearsurface" : ptr * Word32.word -> unit ;

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

  fun loop l =
    let
      val l = map goone l

    in
      clearsurface (screen, 0wx000000);
      app (fn (_, _, x, y) => blit (graphic, screen, trunc x, trunc y)) l;
      flip screen;
      loop l
    end

  val () = loop 
    (List.tabulate(50,
                   fn x =>
                   (real x, real x, 50.0, 50.0)))

end
