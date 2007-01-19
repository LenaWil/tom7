
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

  val screen = makescreen (width, height)

  fun requireimage s =
    case Image.load s of
      NONE => (print ("couldn't open " ^ s ^ "\n");
               raise Nope)
    | SOME p => p

  val robot = requireimage "testgraphics/robot.png"
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

  fun loop l =
    let
    in
      clearsurface (screen, color (0w0, 0w0, 0w0, 0w0));
      drawworld ();
      flip screen;
      key l
    end

  and key l =
    case pollevent () of
      SOME (E_KeyDown { sym = SDLK_ESCAPE }) => () (* quit *)
    | SOME E_Quit => ()
    | _ => loop l

  val () = loop ()
    handle e => messagebox ("Uncaught exception: " ^ exnName e ^ " / " ^ exnMessage e)

end
