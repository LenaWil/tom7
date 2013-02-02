
structure World (* XXX :> WORLD *) =
struct

  exception World of string

  structure IIM = SplayMapFn(type ord_key = int * int
                             fun compare ((x, y), (xx, yy)) =
                               case Int.compare (y, yy) of
                                 EQUAL => Int.compare (x, xx)
                               | ord => ord)

  type world = Screen.screen IIM.map
  (* val screens : Screen.screen ref IIM.map ref = ref IIM.empty *)


  fun fromtf (WorldTF.W { screens }) : world =
    let
      val w = ref IIM.empty

      fun addscreen (x, y, s) =
        case IIM.find (!w, (x, y)) of
          NONE => w := IIM.insert (!w, (x, y), Screen.fromtf s)
        | SOME _ => raise World ("Already have screen for " ^
                                 Int.toString x ^ ", " ^ Int.toString y)
    in
      app addscreen screens;
      !w
    end

  fun totf (w : Screen.screen IIM.map) : WorldTF.world =
    WorldTF.W { screens =
                map (fn ((x, y), s) =>
                     (x, y, Screen.totf s)) (IIM.listItemsi w) }


  val WORLDFILE = "world.tf"
  val WORLD_WIDTH = Constants.WORLD_WIDTH
  val WORLD_HEIGHT = Constants.WORLD_HEIGHT

  val world : world ref = ref IIM.empty

  fun eprint s = TextIO.output(TextIO.stdErr, s ^ "\n")
  fun load () =
    world := fromtf (WorldTF.W.fromfile WORLDFILE)
    handle Screen.Screen s =>
             eprint ("Error loading " ^ WORLDFILE ^ ": " ^ s ^ "\n")
           | World s =>
             eprint ("Error loading " ^ WORLDFILE ^ ": " ^ s ^ "\n")
           | WorldTF.Parse s =>
             eprint ("Error parsing " ^ WORLDFILE ^ ": " ^ s ^ "\n")
           | IO.Io _ => ()

  fun save () =
    WorldTF.W.tofile WORLDFILE (totf (!world))

  fun getorcreate (x, y) =
    case IIM.find (!world, (x, y)) of
      NONE => (world := IIM.insert (!world, (x, y), Screen.starter ());
               getorcreate (x, y))
    | SOME s => s

  fun getmaybe (x, y) =
    IIM.find (!world, (x, y))

  (* Sets the screen at x,y to the argument. Returns the screen
     since otolith keeps a copy too. *)
  fun setscreen (x, y, s) =
    let in
      world := IIM.insert (!world, (x, y), s);
      s
    end

end
