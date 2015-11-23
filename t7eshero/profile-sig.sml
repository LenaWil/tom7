(* A player's profile stores personal records, finished songs,
   achievements, etc. *)
signature PROFILE =
sig

  (* an individual profile *)
  type profile

  (* for the whole database, serialize to and unserialize from disk. *)
  val save : unit -> unit
  val load : unit -> unit

  val all : unit -> profile list
  val profiles : profile list ref (* XXX *)

  datatype achievement =
      (* get perfect on a song *)
      PerfectMatch

  (* Get the best records from all local players. Includes the player's
     name, the record, and the last time that player played (which is an
     upper bound on the time the record was set). *)
  val local_records : unit -> (Setlist.songid *
                               (string * Record.record * IntInf.int)) list

  (* Create a profile with some random defaults *)
  val add_default : unit -> profile

  (* accessors *)
  val name : profile -> string
  val pic : profile -> string (* filename of image *)
  val records : profile -> (Setlist.songid * Record.record) list
  val achievements : profile ->
    (achievement * Setlist.songid option * IntInf.int) list
  val lastused : profile -> IntInf.int
  val surface : profile -> SDL.surface
  val closet : profile -> Items.item list
  val outfit : profile -> Items.worn

  (* posessions, fans, etc. *)

  (* mutators *)
  val setname : profile -> string -> unit
  (* also updates surface *)
  val setpic  : profile -> string -> unit
  val setrecords : profile -> (Setlist.songid * Record.record) list -> unit
  val setachievements : profile ->
    (achievement * Setlist.songid option * IntInf.int) list -> unit
  val setlastused : profile -> IntInf.int -> unit
  val setcloset : profile -> Items.item list -> unit
  val setoutfit : profile -> Items.worn -> unit

  (* Usually updating the last-used time with now, so for convenience: *)
  val setusednow : profile -> unit

end
