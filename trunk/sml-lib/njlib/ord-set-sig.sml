(* ord-set-sig.sml
 *
 * COPYRIGHT (c) 1993 by AT&T Bell Laboratories.
 * See COPYRIGHT file for details.
 *
 * Signature for a set of values with an order relation.
 *)

signature ORD_SET =
sig

  structure Key : ORD_KEY

  type item = Key.ord_key
  type set

  (* The empty set *)
  val empty : set

  (* Create a singleton set *)
  val singleton : item -> set

  (* Insert an item. *)
  val add  : set * item -> set
  val add' : item * set -> set

  (* Insert items from list. *)
  val addList : set * item list -> set

  (* Remove an item. Raise NotFound if not found. *)
  val delete : set * item -> set

  (* Return true if and only if item is an element in the set *)
  val member : set * item -> bool

  (* Return true if and only if the set is empty *)
  val isEmpty : set -> bool

  (* Return true if and only if the two sets are equal *)
  val equal : (set * set) -> bool

  (* does a lexical comparison of two sets *)
  val compare : (set * set) -> order

  (* Return true if and only if the first set is a subset of the second *)
  val isSubset : (set * set) -> bool

  (* Return the number of items in the table *)
  val numItems : set ->  int

  (* Return an ordered list of the items in the set *)
  val listItems : set -> item list

  (* Union *)
  val union : set * set -> set

  (* Intersection *)
  val intersection : set * set -> set

  (* Difference *)
  val difference : set * set -> set

  (* Create a new set by applying a map function to the elements
     of the set. *)
  val map : (item -> item) -> set -> set

  (* Apply a function to the entries of the set
     in decreasing order. *)
  val app : (item -> unit) -> set -> unit

  (* Apply a folding function to the entries of the set
     in increasing order. *)
  val foldl : (item * 'b -> 'b) -> 'b -> set -> 'b

  (* Apply a folding function to the entries of the set
     in decreasing order. *)
  val foldr : (item * 'b -> 'b) -> 'b -> set -> 'b

  val filter : (item -> bool) -> set -> set

  val exists : (item -> bool) -> set -> bool

  val find : (item -> bool) -> set -> item option

end
