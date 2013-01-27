
structure World (* XXX :> WORLD *) =
struct

  exception World of string

  structure IIM = SplayMapFn(type ord_key = int * int
                             fun compare ((x, y), (xx, yy)) =
                               case Int.compare (y, yy) of
                                 EQUAL => Int.compare (x, xx)
                               | ord => ord)

  type world = Screen.screen IIM.map ref
  (* val screens : Screen.screen ref IIM.map ref = ref IIM.empty *)


  fun fromtf (WorldTF.W { screens }) =
    let
      val w = ref IIM.empty

      fun addscreen (x, y, s) =
        case IIM.find (!w, (x, y)) of
          NONE => w := IIM.insert (!w, (x, y), Screen.fromtf s)
        | SOME _ => raise World ("Already have screen for " ^
                                 Int.toString x ^ ", " ^ Int.toString y)
    in
      app addscreen screens;
      w
    end

  fun totf (ref (w : Screen.screen IIM.map)) : WorldTF.world =
    WorldTF.W { screens =
                map (fn ((x, y), s) =>
                     (x, y, Screen.totf s)) (IIM.listItemsi w) }


  val WORLD_WIDTH = Constants.WORLD_WIDTH
  val WORLD_HEIGHT = Constants.WORLD_HEIGHT


  (* val world = *)

end
