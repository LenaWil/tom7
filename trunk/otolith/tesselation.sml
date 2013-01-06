structure Tesselation :> TESSELATION =
struct

  exception Tesselation of string

  datatype node = N of { id : IntInf.int,
                         x : int, y : int,
                         triangles : (node * node) list } ref
  type triangle = node * node * node

  (* Enough? *)
  type tesselation = triangle list ref

  val ctr = ref (0 : IntInf.int)
  fun next () = (ctr := !ctr + 1; !ctr)

  fun tesselation { x0 : int, y0 : int, x1 : int, y1 : int } : tesselation =
      let
          fun settriangles (N (r as ref { id, x, y, ... }), t) =
              r := { id = id, x = x, y = y, triangles = t }

          (*    n1 --- n2
                |  \    |  t2
             t1 |    \  |
                n3 --- n4 *)
          val n1 = N (ref { id = next (), x = x0, y = y0, triangles = nil })
          val n2 = N (ref { id = next (), x = x1, y = y0, triangles = nil })
          val n3 = N (ref { id = next (), x = x0, y = y1, triangles = nil })
          val n4 = N (ref { id = next (), x = x1, y = y1, triangles = nil })
      in
          (* These are all clockwise. Should that be a representation invariant? *)
          settriangles (n1, [(n4, n3), (n2, n4)]);
          settriangles (n2, [(n4, n1)]);
          settriangles (n3, [(n1, n4)]);
          settriangles (n4, [(n3, n1), (n1, n2)]);
          ref [(n1, n4, n3), (n4, n1, n2)]
      end

  fun closestedge (s : tesselation) (x, y) : node * node * int * int =
      raise Tesselation "unimplemented"

  fun gettriangle (s : tesselation) (x, y) : triangle option =
      raise Tesselation "unimplemented"

  fun splitedge (s : tesselation) (x, y) : node option =
      raise Tesselation "unimplemented"

  fun triangles (s : tesselation) : triangle list = !s

  structure T =
  struct
    fun nodes x = x
    fun nodelist (a, b, c) = [a, b, c]
  end

  structure N =
  struct
    fun coords (N (ref {x, y, ...})) = (x, y)
    fun triangles (v as N (ref {triangles, ...})) =
        map (fn (a, b) => (v, a, b)) triangles
    fun compare (N (ref {id, ...}), N (ref {id = idd, ...})) =
        IntInf.compare (id, idd)

    fun trymove n (x, y) = raise Tesselation "unimplemented"
  end
end
