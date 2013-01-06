(* Abstract letters (no drawing). *)
structure Letter =
struct

  open BDDMath
  open BDDOps
  infix 6 :+: :-: %-% %+% +++
  infix 7 *: *% +*: +*+ #*% @*:

  structure U = Util
  open SDL
  structure Util = U

  structure M = Maths
  structure GA = GrowArray

  structure CM = SplayMapFn(type ord_key = char
                            val compare = Char.compare)

  exception Letter of string

  (* A letter is a mutable array of polygons. *)
  type letter =
      (* Add graphics, ... *)
      { polys: Maths.poly GA.growarray }

  fun copyletter { polys } =
      { polys = GA.fromlist (map GA.copy (GA.tolist polys)) }
      (* handle Subscript => (eprint "copyletter"; raise Subscript) *)

  type alphabet = letter CM.map

  (* Only if they are structurally equal (order of polygons and
     vertices matters). Used to deduplicate undo state. *)
  local exception NotEqual
  in
      fun lettereq ({ polys = ps }, { polys = pps }) =
          let in
              if GA.length ps <> GA.length pps
              then raise NotEqual
              else ();
              Util.for 0 (GA.length ps - 1)
              (fn i =>
               let val p = GA.sub ps i
                   val pp = GA.sub pps i
               in
                   if GA.length p <> GA.length pp
                   then raise NotEqual
                   else ();
                   Util.for 0 (GA.length p - 1)
                   (fn j =>
                    if not (vec2eq (GA.sub p j, GA.sub pp j))
                    then raise NotEqual
                    else ())
               end);
              true
          end handle NotEqual => false
  end

  fun non_cr #"\r" = false
    | non_cr _ = true

  val rtos9 = Real.fmt (StringCvt.FIX (SOME 2))
  fun vtos9 v = rtos9 (vec2x v) ^ "," ^ rtos9 (vec2y v)
  fun stov s =
      case map Real.fromString (String.fields (StringUtil.ischar #",") s) of
          [SOME x, SOME y] => vec2 (x, y)
        | _ => raise Letter ("bad vector: " ^ s)

  val (letter_ulist, letter_unlist) =
      Serialize.list_serializerex non_cr "\n" #"$"

  val (poly_ulist, poly_unlist) = Serialize.list_serializer ";" #"!"
  (* Note: loses precision. *)
  fun polytostring poly =
    poly_ulist (map vtos9 (GA.tolist poly))

  fun polyfromstring (s : string) : Maths.poly =
    GA.fromlist (map stov (poly_unlist s))

  fun tostring ({ polys } : letter) : string =
    letter_ulist (map polytostring (GA.tolist polys))

  fun fromstring (s : string) : letter =
    let val ps = letter_unlist s
        val ps = map polyfromstring ps
    in
        { polys = GA.fromlist ps }
    end

  fun shapes (origin : vec2, { polys } : letter) : BDDShape.shape list =
    let
        val l = GA.tolist polys
        fun polytoshape p =
            let val p = GA.tolist p
            in BDDShape.Polygon (BDDPolygon.polygon
                                 (map (fn v => v :+: origin) p))
            end
    in
        map polytoshape l
    end

  val (alpha_ulist, alpha_unlist) =
      Serialize.list_serializerex non_cr "\n--------\n" #"#"

  fun alphabettostring (a : alphabet) : string =
    let
        val l = CM.listItemsi a
    in
        alpha_ulist (map (fn (c, letter) =>
                          implode [c, #":"] ^
                          tostring letter) l)
    end

  fun alphabetfromstring str : alphabet =
    let
        val ps = alpha_unlist str
        fun one s =
            if size s < 2 orelse String.sub(s, 1) <> #":"
            then raise Letter "illegal letter"
            else (String.sub (s, 0),
                  fromstring (String.substring (s, 2, size s - 2)))
        val ps = map one ps
    in
        foldl CM.insert' CM.empty ps
    end
end
