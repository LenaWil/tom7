
structure KnightSweeper =
struct

  val board1 = Vector.fromList
    [
     1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 2, 0, 1, 0, 0,
     0, 1, 0, 2, 1, 0, 1, 1, 1, 1, 1, 2, 1, 2, 1,
     2, 0, 1, 2, 1, 2, 0, 4, 0, 1, 1, 2, 0, 0, 1,
     0, 0, 1, 2, 1, 0, 2, 1, 1, 1, 1, 1, 0, 1, 0,
     2, 0, 1, 1, 1, 0, 0, 2, 1, 0, 3, 2, 1, 0, 1,
     0, 1, 1, 2, 2, 0, 3, 0, 2, 0, 2, 1, 1, 1, 1,
     1, 0, 1, 1, 0, 2, 0, 2, 0, 1, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     1, 1, 1, 1, 0, 2, 1, 1, 2, 0, 1, 1, 1, 1, 1,
     0, 1, 3, 1, 2, 1, 2, 1, 2, 1, 1, 2, 1, 0, 2,
     0, 2, 1, 0, 0, 3, 0, 1, 1, 1, 1, 2, 1, 1, 1,
     0, 0, 3, 1, 2, 1, 1, 2, 2, 1, 2, 4, 0, 0, 2,
     1, 2, 2, 1, 0, 4, 1, 1, 2, 1, 1, 2, 1, 1, 1,
     0, 1, 2, 0, 2, 0, 1, 1, 2, 0, 1, 2, 1, 0, 2,
     0, 1, 0, 0, 0, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1
     ]

  val board2 = Vector.fromList
    [
     0, 2, 1, 1, 2, 0, 2, 0, 1, 0, 1, 0, 2, 0, 1,
     1, 2, 2, 3, 1, 4, 0, 2, 0, 3, 0, 1, 0, 1, 0,
     2, 2, 3, 2, 2, 1, 2, 1, 2, 1, 2, 0, 2, 1, 1,
     2, 1, 2, 2, 2, 2, 2, 2, 0, 3, 1, 3, 1, 2, 0,
     1, 3, 2, 3, 2, 2, 3, 1, 3, 1, 2, 1, 2, 0, 1,
     2, 0, 2, 2, 3, 1, 3, 2, 2, 2, 1, 3, 2, 1, 0,
     1, 1, 1, 2, 0, 1, 0, 1, 1, 1, 2, 0, 3, 2, 2,
     1, 0, 1, 1, 2, 1, 1, 1, 2, 1, 0, 2, 2, 1, 0,
     2, 3, 2, 3, 0, 2, 1, 1, 2, 1, 1, 1, 1, 1, 0,
     1, 2, 1, 2, 1, 0, 0, 0, 0, 1, 0, 2, 3, 1, 1,
     1, 2, 1, 2, 2, 2, 1, 2, 2, 2, 1, 2, 5, 1, 2,
     3, 2, 4, 4, 3, 2, 2, 4, 2, 2, 1, 3, 2, 1, 0,
     3, 4, 4, 4, 3, 2, 2, 2, 4, 2, 2, 2, 4, 1, 1,
     2, 2, 4, 2, 4, 0, 4, 3, 4, 1, 2, 5, 3, 1, 1,
     1, 2, 2, 3, 3, 2, 3, 2, 3, 2, 2, 1, 2, 0, 1
     ]

  fun knightat board (x, y) = 
    if x < 0 orelse y < 0 orelse x >= 15 orelse y >= 15
    then false
    else Vector.sub(board, y * 15 + x)


  fun countat board (x, y) = 
    Vector.sub(board, y * 15 + x)

  val X = true
  val O = false

  fun times_attacked knights (x, y) =
    let fun ka (x, y) = if knightat knights (x, y) then 1 else 0
    in
      ka (x + 2, y - 1) +
      ka (x + 2, y + 1) +
      ka (x - 2, y - 1) +
      ka (x - 2, y + 1) +
      ka (x - 1, y - 2) +
      ka (x - 1, y + 2) +
      ka (x + 1, y - 2) +
      ka (x + 1, y + 2)
    end

  val start = Vector.fromList
    [
     O, O, O, O, O, O, O, O, O, O, O, O, O, O, O,
     O, O, O, O, O, O, O, O, O, O, O, O, O, O, O,
     O, O, O, O, O, O, O, O, O, O, O, O, O, O, O,
     O, O, O, O, O, O, O, O, O, O, O, O, O, O, O,
     O, O, O, O, O, O, O, O, O, O, O, O, O, O, O,
     O, O, O, O, O, O, O, O, O, O, O, O, O, O, O,
     O, O, O, O, O, O, O, O, O, O, O, O, O, O, O,
     O, O, O, O, O, O, O, O, O, O, O, O, O, O, O,
     O, O, O, O, O, O, O, O, O, O, O, O, O, O, O,
     O, O, O, O, O, O, O, O, O, O, O, O, O, O, O,
     O, O, O, O, O, O, O, O, O, O, O, O, O, O, O,
     O, O, O, O, O, O, O, O, O, O, O, O, O, O, O,
     O, O, O, O, O, O, O, O, O, O, O, O, O, O, O,
     O, O, O, O, O, O, O, O, O, O, O, O, O, O, O,
     O, O, O, O, O, O, O, O, O, O, O, O, O, O, O
     ]

  fun vmapi f v =
    Vector.mapi (fn (i, v) =>
                 let 
                   val x = i mod 15
                   val y = i div 15
                 in
                   f ((x, y), v)
                 end) v

  fun make knights =
    vmapi (fn ((x, y), _) => times_attacked knights (x, y)) knights

  fun show k =
    Util.for 0 14
    (fn y =>
     (Util.for 0 14
      (fn x => 
       print (Int.toString (countat k (x, y)) ^ " "));
      print "\n"))

  fun showk k =
    Util.for 0 14
    (fn y =>
     (Util.for 0 14
      (fn x => 
       print ((if knightat k (x, y)
               then "#" else "-") ^ " "));
      print "\n"))

  exception Done

  fun neighbors (x, y) =
    let
      val poss =
        [(x + 2, y - 1),
         (x + 2, y + 1),
         (x - 2, y - 1),
         (x - 2, y + 1),
         (x - 1, y - 2),
         (x - 1, y + 2),
         (x + 1, y - 2),
         (x + 1, y + 2)]
    in
      (* must be on board ... *)
      List.filter (fn (x, y) =>
                   not (x < 0 orelse y < 0
                        orelse x >= 15 orelse y >= 15)) poss
    end

  fun solve cur target =
    (* invt: cur <= target (pointwise).
       (this is easy by starting with all Os)

       for any cell where cur < target (strictly),
       see how many attackers could be added to
       increase it. Then, try adding each of these
       attackers, but always in order from fewest
       possibilities to most. *)
    let
      fun possible_attackers (x, y) =
        if times_attacked cur (x, y) < countat target (x, y)
        then
          let
(*
            val () = print ("attacked: " ^ Int.toString x ^ "/" ^ Int.toString y ^ "\n")
*)

            (* possible offsets. *)
            val poss = neighbors (x, y)
(*
            val () = print ("  (nb) " ^ StringUtil.delimit ", "
                   (map (fn (x, y) => "(" ^ Int.toString x ^ ", " ^ Int.toString y ^ ")") poss) ^ "\n");
*)

            (* to add this knight, its attacked squares must all 
               be strictly than the target *)
            val poss = List.filter (fn (x, y) => 
                                    let 
                                      val attacked = neighbors (x, y)
                                        (*
                                      val () = print ("    (" ^ Int.toString x ^ "/" ^ Int.toString y ^ ") " ^ StringUtil.delimit ", "
                                                      (map (fn (x, y) => "(" ^ Int.toString x ^ ", " ^ Int.toString y ^ ")") attacked) );
                                      *)
                                      val okay_inc = List.all (fn (x', y') =>
                                                times_attacked cur (x', y') < countat target (x', y')) attacked
                                    in
                                      (* (if okay_inc
                                         then print "  ok\n"
                                         else print "\n"); *)
                                      okay_inc
                                    end) poss

              (*
            val () = print ("  (fi) " ^ StringUtil.delimit ", "
                   (map (fn (x, y) => "(" ^ Int.toString x ^ ", " ^ Int.toString y ^ ")") poss) ^ "\n");
            *)
          in
            SOME (length poss, poss)
          end
        else NONE

      val choices = ref nil
      val () =
        Util.for 0 14
        (fn y =>
         (Util.for 0 14
          (fn x =>
           case possible_attackers (x, y) of
             NONE => ()
           | SOME l => choices := l :: !choices)))

      val choices =
           ListUtil.sort (ListUtil.byfirst Int.compare) (!choices)
    in
      case choices of
        nil => 
          let in
            print "DONE:\n";
            showk cur;
            raise Done
          end
      (* don't ever backtrack when we are forced. *)
      | (1, [(x, y)]) :: _ => 
          let
            val cur = Vector.tabulate (Vector.length cur, 
                                       fn i => if i = x + y * 15 then true else Vector.sub(cur, i))
          in
            solve cur target
          end
      | (0, nil) :: _ => () (* dead end; backtrack *)
      | (n, l) :: _ => 
        (* try them all, recursively. *)
          app
          (fn (x, y) =>
           let
             val cur = Vector.tabulate (Vector.length cur, 
                                        fn i => if i = x + y * 15 then true else Vector.sub(cur, i))
           in
             solve cur target
           end) l

(*
          let in
            print "Loose... unimplemented\n";
            app (fn (i, l') =>
                 print (Int.toString i ^ " : " ^
                        StringUtil.delimit ", "
                        (map (fn (x, y) => "(" ^ Int.toString x ^ ", " ^ Int.toString y ^ ")") l') ^ "\n")) l;
            raise Done
          end
*)

    end
(* 
  val targ = Vector.fromList
    [
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 2, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
     ]
*)
end

structure K = KnightSweeper
