(* Common datatype and constant definitions for T7eshero. *)
structure Hero =
struct

  exception Hero of string
  exception Exit

  datatype bar =
      Measure
    | Beat
    | Timesig of int * int

  datatype state =
      Future
    | Missed
    | Hit of int ref (* animation frame *)

  (* ... ? *)
  datatype input =
      FingerDown of int
    | FingerUp of int
    | Commit of int list

  (* To earn a medal, you have to get at least 90% on the song. *)
  datatype medal =
      (* Got 100% *)
      PerfectMatch
    (* Averaged at least 0.25 m/s dancing *)
    | Snakes
    (* Less than 0.02 m/s (?) average dancing *)
    | Stoic
    (* Only strummed upward. *)
    | Plucky
    (* Only strummed downward. *)
    | Pokey
    (* never hammered a note (hard to measure?) *)
    | AuthenticStrummer
    (* never strummed a hammer note *)
    | AuthenticHammer

  fun medal_cmp (PerfectMatch, PerfectMatch) = EQUAL
    | medal_cmp (PerfectMatch, _) = GREATER
    | medal_cmp (_, PerfectMatch) = LESS
    | medal_cmp (Snakes, Snakes) = EQUAL
    | medal_cmp (Snakes, _) = GREATER
    | medal_cmp (_, Snakes) = LESS
    | medal_cmp (Stoic, Stoic) = EQUAL
    | medal_cmp (Stoic, _) = GREATER
    | medal_cmp (_, Stoic) = LESS
    | medal_cmp (Plucky, Plucky) = EQUAL
    | medal_cmp (Plucky, _) = GREATER
    | medal_cmp (_, Plucky) = LESS
    | medal_cmp (Pokey, Pokey) = EQUAL
    | medal_cmp (Pokey, _) = GREATER
    | medal_cmp (_, Pokey) = LESS
    | medal_cmp (AuthenticStrummer, AuthenticStrummer) = EQUAL
    | medal_cmp (AuthenticStrummer, _) = GREATER
    | medal_cmp (_, AuthenticStrummer) = LESS
    | medal_cmp (AuthenticHammer, AuthenticHammer) = EQUAL
(*    | medal_cmp (AuthenticHammer, _) = GREATER
    | medal_cmp (_, AuthenticHammer) = LESS *)

  val FINGERS = 5

  val MENUTICKS = 0w60

  fun messagebox s =
      let val f = TextIO.openAppend("/tmp/t7es.txt")
      in
          TextIO.output(f, s ^"\n");
          TextIO.closeOut(f)
      end

  fun messagebox s = print (s ^ "\n")

  fun fail s = (messagebox s; raise Hero s)

end

val () = print "Hero initialized.\n"
