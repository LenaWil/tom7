
signature ITEMS =
sig
    exception Items of string

    (* set of mutually-exclusive things *)
    type class

    (* an individual item *)
    type item

    (* A worn is a set of items that can be legitimately worn together
       (no more than one per class). They can be saved to disk, or enumerated
       in z-index order. *)
    type worn

    (* apply in z-index order, items behind or items in front of the robot *)
    val app_behind  : worn -> (item -> unit) -> unit
    val app_infront : worn -> (item -> unit) -> unit

    val add : worn -> item -> worn
    val remove : worn -> item -> worn
    val has : worn -> item -> bool

    val name : item -> string
    val frames : item -> (SDL.surface * int * int) Vector.vector
    val id : item -> string
    val zindex : item -> int

    val default_outfit : unit -> worn
    val default_closet : unit -> item list

    (* Give an arbitrary item back that isn't already in the list *)
    val award : item list -> item option

    (* loads the database of items. It is immutable. *)
    val load : unit -> unit

    val fromid : string -> item

    (* for serialization *)
    val wtostring : worn -> string
    val wfromstring : string -> worn

end