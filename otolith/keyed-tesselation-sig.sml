
(* An object is a tesselation where each vertex has multiple
   coordinates, keyed by some functor argument. This allows the
   object's shape/location to be parameterized.

   The code is basically a copy of Tesselation with the idea
   that once it's working, it can also be used to implement
   tesselation where the coordinate key is unit.
*)
signature KEYARG =
sig
  type key
  val compare : key * key -> order
  (* For serialization. *)
  val tostring : key -> string
  val fromstring : string -> key option
end

(* functor KeyedTesselation(KEYARG) :> *)
signature KEYEDTESSELATION =
sig

  (* From argument *)
  type key

  exception KeyedTesselation of string

  (* Mutable, nonempty.

     Uses integer coordinates. *)
  type keyedtesselation

  (* A vertex, usually in multiple triangles. *)
  type node

  (* Three nodes. Never degenerate. *)
  type triangle

  (* Creates a object of the given rectangle, which looks like this:

     .---.
     |\  |
     | \ |
     |__\|

     It starts with just a single position, for the key argument. *)
  val rectangle : key -> { x0 : int, y0 : int, x1 : int, y1 : int } -> keyedtesselation

  (* Get the triangle this point is within *)
  val gettriangle : keyedtesselation -> int * int -> triangle option

  (* When using the given key, return the closest edge to the given
     point, and the point on that edge that's closest to the input
     point. Note that this may not be unique, so chooses arbitrarily
     in that case. This is always the same edge and point used by
     splitedge, when it can succeed. *)
  val closestedge : keyedtesselation -> key -> int * int ->
                    node * node * int * int

  (* Split the edge closest to the given point (when using the given
     key), at its closest point. The edge will be on 1 or 2 triangles;
     each of those triangles is split by making a new edge from the
     created split point to the one node that is not on the edge.

     Only succeeds if this point is not one of the edge's vertices,
     and if no degenerate triangles will result. Additionally, the
     same split must work (and produce no degenerate triangles) in all
     configurations for the keyedtesselation. Your best bet is to do
     all the splitting for the tesselation with a single configuration
     before creating others. *)
  val splitedge : keyedtesselation -> key -> int * int -> node option

  val triangles : keyedtesselation -> triangle list
  val nodes : keyedtesselation -> node list

  (* getnodewithin s key (x, y) radius
     Get the closest node when the tesselation is configured to this key,
     as long as it is within the radius. *)
  val getnodewithin : keyedtesselation -> key -> int * int -> int ->
                      node option

  val toworld : keyedtesselation -> WorldTF.keyedtesselation
  val fromworld : WorldTF.keyedtesselation -> keyedtesselation

  (* Checks the structure of the keyedtesselation. This should never be
     necessary, but is useful if you suspect a bug. *)
 (*   val check : keyedtesselation -> unit *)

  structure T :
  sig
    val nodes : triangle -> node * node * node
    (* Always three *)
    val nodelist : triangle -> node list
  end

  structure N :
  sig
    (* Raises KeyedTesselation if the key is not present *)
    val coords : node -> key -> int * int
    val coordsmaybe : node -> key -> (int * int) option

    (* A node is usually part of multiple triangles. *)
    val triangles : node -> triangle list

    (* Get the unique ID of the node. *)
    val id : node -> IntInf.int

    (* Try moving the node in the configuration given by the key.
       This moves the node in each attached triangle. The point may
       not move to the desired spot, since the triangles are not
       allowed to be degenerate. *)
    val trymove : node -> key -> int * int -> int * int

    val compare : node * node -> order
  end

end