
structure Screen (* XXX SIG *) =
struct

  (* State of a single screen in the game.
     Not worrying about how screens are connected together
     for this experiment.

     We have a single tesselation which should cover the whole screen
     area. Call this the "areas". Then we have a list of objects,
     themselves tesselations, that are keyed by the nodes in the
     areas.

     *)

  structure AreaArg =
  struct
    type key = unit
    fun compare _ = EQUAL
    fun tostring () = ""
  end

  structure Areas = KeyedTesselation(AreaArg)

  structure ObjArg =
  struct
    type key = Areas.node
    val compare = Areas.N.compare
    fun tostring n = IntInf.toString (Areas.N.id n)
  end

  structure Obj = KeyedTesselation(ObjArg)

end