
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

  val width = 640
  val height = 480

  val screen = makescreen (width, height)

  val graphic = 
      case Image.load "icon.png" of
          NONE => (messagebox "couldn't open graphic";
                   raise Nope)
        | SOME p => p
          
  val () = messagebox "ok?"

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
      (* messagebox ("clearsurface..."); *)
      clearsurface (screen, color (0w0, 0w0, 0w0, 0w0));
      (* messagebox ("blit..."); *)
      app (fn (_, _, x, y) => blitall (graphic, screen, trunc x, trunc y)) l;
      (* messagebox ("right before flip..."); *)
      flip screen;
      key l
    end

  and key l =
    case pollevent () of
      SOME (E_KeyDown { sym = SDLK_SPACE }) => 
        loop (map (fn (dx, dy, x, y) => (0.0, dy + (10.0 * random () - 5.0), x, y)) l)
    | SOME (E_KeyDown { sym = SDLK_ESCAPE }) => () (* quit *)
        
    | SOME (E_KeyDown _) =>
        loop (map (fn (dx, dy, x, y) => (dx + (10.0 * random () - 5.0), dy + (10.0 * random () - 5.0), x, y)) l)
    | SOME E_Quit => ()
    | _ => loop l

  val () = loop 
    (List.tabulate(50,
                   fn x =>
                   (real x, real x, 50.0, 50.0)))
    handle e => messagebox ("Uncaught exception: " ^ exnName e ^ " / " ^ exnMessage e)

end
