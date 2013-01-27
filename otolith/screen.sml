
structure Screen (* XXX SIG *) =
struct

  open Constants

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
    fun exn s = Screen ("areas: " ^ s)
  end

  structure Areas = KeyedTesselation(AreaArg)
  type areas = Areas.keyedtesselation

  structure ObjArg =
  struct
    type key = Areas.node
    val compare = Areas.N.compare
    (* Perhaps could allow debugging output of nodes? *)
    fun tostring n = "(NODE)"
    fun exn s = Screen ("obj: " ^ s)
  end

  structure Obj = KeyedTesselation(ObjArg)
  type obj = Obj.keyedtesselation

  type screen = { areas : areas,
                  objs : obj list }

  fun areas ({ areas, objs } : screen) = areas
  fun objs ({ areas, objs } : screen) = objs

  fun starter () : screen = { areas =
                              Areas.rectangle ()
                                { x0 = 0, y0 = 0,
                                  x1 = WIDTH - 1, y1 = HEIGHT - 1 },
                              objs = nil }

  (* Find all the objects that this point is within.
     Gives a key for each that causes the point to be inside it. *)
  fun objectswithin (objs : obj list) (x, y) =
    List.mapPartial
    (fn obj =>
     case Obj.gettriangle obj (x, y) of
       NONE => NONE
     | SOME (k, _) => SOME (obj, k))
    objs

  (* Return the closest node (and object) within the given distance from
     (x, y), using the configuration key. In the case of ties, the first
     object in the list is returned; the order among nodes that are the
     same distance is arbitrary, however. *)
  fun objectclosestnodewithin (objs : obj list) (key : Obj.key) (x, y) dist =
    let
      val closest = ref NONE
      fun closer d =
        case !closest of
          NONE => true
        | SOME (dd, _, _) => d < dd

      fun oneobject obj =
        if Obj.iskey obj key
        then
          case Obj.getnodewithin obj key (x, y) dist of
            NONE => ()
          | SOME n =>
              let
                val (xx, yy) = Obj.N.coords n key
                val d = IntMaths.distance_squared ((x, y), (xx, yy))
              in
                if closer d
                then closest := SOME (d, obj, n)
                else ()
              end
        else ()
    in
      app oneobject objs;
      Option.map (fn (_, b, c) => (b, c)) (!closest)
    end

  fun closestobjectedge (objs : obj list) key (x, y) =
    let
      (* I need to do this kind of thing a lot -- can probably be a
         nice little utility *)
      val closest = ref NONE
      fun closer d =
        case !closest of
          NONE => true
        | SOME (dd, _, _, _, _, _) => d < dd

      fun oneobject obj =
        if Obj.iskey obj key
        then
          let
            val (n1, n2, xx, yy) = Obj.closestedge obj key (x, y)
            val dsq = IntMaths.distance_squared ((x, y), (xx, yy))
          in
            if closer dsq
            then closest := SOME (dsq, obj, n1, n2, xx, yy)
            else ()
          end
        else ()
    in
      app oneobject objs;
      Option.map (fn (_, obj, n1, n2, xx, yy) => (obj, n1, n2, xx, yy)) (!closest)
    end

  (* XXX it is weird that this has to return a new screen...
     maybe screen should just be mutable at toplevel? *)
  fun addrectangle { areas, objs } node (x0, y0, x1, y1) : screen =
    let
      val obj = Obj.rectangle node { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
    in
      (* Attach to other nodes? *)
      { areas = areas, objs = obj :: objs }
    end

  (* Most of the work is done by KeyedTesselation itself.
     But we need to set up a mapping between area nodes and
     stringified integers, since those are used as keys for
     coordinates in the objs. *)
  fun totf { areas, objs } : WorldTF.screen =
    let
      val (areas, getid) = Areas.totf (fn () => "") areas
      fun serializekey n = Int.toString (getid n)

      fun oneobj obj =
          let val (kt, _) = Obj.totf serializekey obj
          in kt
          end
    in
      WorldTF.S { areas = areas,
                  objs = map oneobj objs }
    end

  fun fromtf (WorldTF.S { areas, objs }) : screen =
    let
      fun checkkey "" = SOME ()
        | checkkey _ = NONE
      val (areas, getnode) = Areas.fromtf checkkey areas

      fun deserializekey s =
          Option.map getnode (Int.fromString s)

      fun oneobj obj =
        let val (kt, _) = Obj.fromtf deserializekey obj
        in kt
        end
    in
      { areas = areas,
        objs = map oneobj objs }
    end

end
