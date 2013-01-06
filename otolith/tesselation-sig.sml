signature TESSELATION =
sig

  exception Tesselation of string

  (* Mutable, nonempty.

     Uses integer coordinates. *)
  type tesselation

  (* A vertex, usually in multiple triangles. *)
  type node

  (* Three vertices. Never degenerate. *)
  type triangle

  (* Creates a tesselation of the given rectangle, which looks like this

     .---.
     |\  |
     | \ |
     |__\|

     *)
  val tesselation : { x0 : int, y0 : int, x1 : int, y1 : int } -> tesselation

  (* Get the triangle this point is within *)
  val gettriangle : tesselation -> int * int -> triangle option

  (* Return the closest edge to the given point, and the point on that
     edge that's closest to the input point. Note that this may not be
     unique, so chooses arbitrarily in that case. This is always the same
     edge and point used by splitedge, when it can succeed. *)
  val closestedge : tesselation -> int * int -> node * node * int * int

  (* Split the edge closest to the given point, at its closest point.
     The edge will be on 1 or 2 triangles; each of those triangles is
     split by making a new edge from the created split point to the
     one node that is not on the edge.

     Only succeeds if this point is not one of the edge's vertices,
     and if no degenerate triangles will result. *)
  val splitedge : tesselation -> int * int -> node option

  val triangles : tesselation -> triangle list

  structure T :
  sig
    val nodes : triangle -> node * node * node
    (* Always three *)
    val nodelist : triangle -> node list
  end

  structure N :
  sig
    val coords : node -> int * int
    (* A node is usually part of multiple triangles. *)
    val triangles : node -> triangle list

    (* Try moving the node. This moves the node in each attached
       triangle. The point may not move to the desired spot, since
       the triangles are not allowed to be degenerate. *)
    val trymove : node -> int * int -> int * int

    val compare : node * node -> order
  end

end