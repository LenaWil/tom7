
structure Screen (* XXX SIG *) =
struct

  exception Screen of string

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
  type areas = Areas.keyedtesselation

  structure ObjArg =
  struct
    type key = Areas.node
    val compare = Areas.N.compare
    (* Perhaps could allow debugging output of nodes? *)
    fun tostring n = "(NODE)"
  end

  structure Obj = KeyedTesselation(ObjArg)
  type obj = Obj.keyedtesselation

  type screen = { areas : areas,
                  objs : obj list }

  (* Most of the work is done by KeyedTesselation itself.
     But we need to set up a mapping between area nodes and
     stringified integers, since those are used as keys for
     coordinates in the objs. *)
  fun toworld { areas, objs } : WorldTF.screen =
    let
      val (areas, getid) = Areas.toworld (fn () => "") areas
      fun serializekey n = Int.toString (getid n)

      fun oneobj obj =
          let val (kt, _) = Obj.toworld serializekey obj
          in kt
          end
    in
      WorldTF.S { areas = areas,
                  objs = map oneobj objs }
    end

  fun fromworld (WorldTF.S { areas, objs }) : screen =
    let
      fun checkkey "" = SOME ()
        | checkkey _ = NONE
      val (areas, getnode) = Areas.fromworld checkkey areas

      fun deserializekey s =
          Option.map getnode (Int.fromString s)

      fun oneobj obj =
        let val (kt, _) = Obj.fromworld deserializekey obj
        in kt
        end
    in
      { areas = areas,
        objs = map oneobj objs }
    end

end
