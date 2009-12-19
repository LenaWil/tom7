(* retract five yellow blocks (approximate; doesn't take player
   maneuvering into account) *)
functor Yellow5AllRetract(val filename : string) :> GAME =
struct

  open RetractParse

    val findshortest = false
    val reverse = true

    (* always distinct and sorted *)
    type state = { y1 : Word9.word,
                   y2 : Word9.word,
                   y3 : Word9.word,
                   y4 : Word9.word,
                   y5 : Word9.word }

    fun sort_state { y1, y2, y3, y4, y5 } =
        let val l = [y1, y2, y3, y4, y5]

            val l = ListUtil.sort Word9.compare l
        in
            case l of
                [y1, y2, y3, y4, y5] => {y1=y1, y2=y2, y3=y3, y4=y4, y5=y5}
              | _ => raise Match (* impossible *)
        end


    fun merge y1 {y2, y3, y4, y5} =
      (if y1 <= y2
       then let val m2_y1 = y1
            in let val m2_y2 = y2
      in let val m2_y3 = y3
      in let val m2_y4 = y4
      in let val m2_y5 = y5
      in {y1 = m2_y1, y2 = m2_y2, y3 = m2_y3, y4 = m2_y4, y5 = m2_y5}
      end
      end
      end
      end
            end
       else let val m2_y1 = y2
            in (if y1 <= y3
       then let val m2_y2 = y1
            in let val m2_y3 = y3
      in let val m2_y4 = y4
      in let val m2_y5 = y5
      in {y1 = m2_y1, y2 = m2_y2, y3 = m2_y3, y4 = m2_y4, y5 = m2_y5}
      end
      end
      end
            end
       else let val m2_y2 = y3
            in (if y1 <= y4
       then let val m2_y3 = y1
            in let val m2_y4 = y4
      in let val m2_y5 = y5
      in {y1 = m2_y1, y2 = m2_y2, y3 = m2_y3, y4 = m2_y4, y5 = m2_y5}
      end
      end
            end
       else let val m2_y3 = y4
            in (if y1 <= y5
       then let val m2_y4 = y1
            in let val m2_y5 = y5
      in {y1 = m2_y1, y2 = m2_y2, y3 = m2_y3, y4 = m2_y4, y5 = m2_y5}
      end
            end
       else let val m2_y4 = y5
            in let val m2_y5 = y1
      in {y1 = m2_y1, y2 = m2_y2, y3 = m2_y3, y4 = m2_y4, y5 = m2_y5}
      end
            end)
            end)
            end)
            end)

    val xorb = Word32.xorb
    infix xorb
    fun hash {y1, y2, y3, y4, y5} =
        (* PERF: note, toLarge is apparently slower in current mlton *)
        Word32.<< (Word32.fromInt (Word9.toInt y1), 0w0)  xorb
        Word32.<< (Word32.fromInt (Word9.toInt y2), 0w7)  xorb
        Word32.<< (Word32.fromInt (Word9.toInt y3), 0w14)  xorb
        Word32.<< (Word32.fromInt (Word9.toInt y4), 0w21)  xorb
        Word32.<< (Word32.fromInt (Word9.toInt y5), 0w28)

    val eq = op=

       
    val {board, initial, z} =
        (* parse f *)
        let
            val {board, ents} = parse_walls filename

            fun indexof c =
                case ListUtil.Alist.find op= ents c of
                    SOME i => Word9.fromInt i
                  | NONE => raise Parse ("didn't find ent " ^ implode [c])


            val blocks = sort_state {y1 = indexof #"1", 
                                     y2 = indexof #"2", 
                                     y3 = indexof #"3", 
                                     y4 = indexof #"4", 
                                     y5 = indexof #"5"}
        in
            { board = board, 
              initial = blocks,
              z = Option.map Word9.fromInt (ListUtil.Alist.find op= ents #"Z") }
        end handle Parse s =>
            let in
                print ("parse error: " ^ s ^ "\n");
                raise Parse s
            end

    val initials = [initial]

    fun app_successors (f, {y1, y2, y3, y4, y5} : state) =
        let

            val ti = Word9.toInt

            (* give it one of the five, and the rest *)
            fun try_one y (y1, y2, y3, y4) =
                let
                    (* val _ = print ("try " ^ Int.toString y ^ "\n") *)

                    (* dir is the direction the block was kicked,
                       so opp is the dir we are 'retracting in' *)
                    fun go dir opp =
                        let
                            
                            (* might be nice if we could use board for
                               this, but it's hard to maintain that it
                               is in the correct state *)

                            fun blockat dest =
                                dest = y1 orelse
                                dest = y2 orelse
                                dest = y3 orelse
                                dest = y4


                            (* in order to retract, must have something
                               blocking us in 'dir' to hit *)
                            fun blocked idx d opp =
                                let val dest = idx + dirchange d
                                    val w = Array.sub(board, dest)
                                    (*
                                    val _ = print ("  -- board[" ^ Int.toString dest ^ "]: " ^ 
                                                   Word32.toString w ^ "\n")
                                    *)
                                in
                                    Word32.andb(Array.sub(board, dest), opp) > 0w0
                                    orelse blockat dest
                                end

                            (* any free spot that this block could
                               have been pushed from (along the direction specified)
                               now counts as a valid predecessor *)

                            (*       + + + + +
                              opp <- |      i| -> dir
                                     + + + + + 

                              reasons to stop:
                                     + + + + +
                                     |  X i  |
                                     + + + + +
                                .. block before us.

                                     + + + + +
                                     |   |i  |
                                     + + + + +
                                        -> (blocked)
                                .. wall before us.

                              *)

                            and retracting idx dir opp =
                                (* retract at least once first, since when
                                   this is called, we have already visited
                                   that state *)
                                let
                                    val newi = idx + dirchange opp
                                    val newi2 = newi + dirchange opp
                                        
                                    (*
                                    val _ = print ("  (idx = " ^ Int.toString idx ^
                                                   " dir = " ^ Word32.toString dir ^ 
                                                   " newi = " ^ Int.toString newi ^ ")\n");
                                    *)
                                in
                                    (* PERF: this could be more efficient, since
                                       these tests overlap between iterations.
                                       make a loop invariant, establish it, and use it *)
                                    if blockat newi orelse blockat newi2 
                                       orelse blocked newi dir opp
                                       orelse blocked newi2 dir opp
                                    then () (* done -- can't push from here *)
                                    else let
                                             val fi = Word9.fromInt
                                             val news = merge (fi newi) { y2 = fi y1, 
                                                                          y3 = fi y2,
                                                                          y4 = fi y3, 
                                                                          y5 = fi y4}
                                         in
                                             f (news, 1);
                                             retracting newi dir opp
                                         end
                                end

                        in
                            if blocked y dir opp
                            then retracting y dir opp
                            else () (* print ("  .. not blocked " ^ Word32.toString dir ^ "\n") *)
                        end
                        
                in
                    go UP DOWN;
                    go DOWN UP;
                    go LEFT RIGHT;
                    go RIGHT LEFT
                end

            (* can also pull it out of the target, if desired *)
        (* XX no target *)
            fun try_one' y r = try_one y r

            val y1 = ti y1
            val y2 = ti y2
            val y3 = ti y3
            val y4 = ti y4
            val y5 = ti y5
        in
            try_one' y1 (y2, y3, y4, y5);
            try_one' y2 (y1, y3, y4, y5);
            try_one' y3 (y1, y2, y4, y5);
            try_one' y4 (y1, y2, y3, y5);
            try_one' y5 (y1, y2, y3, y4)
        end

    fun tostring {y1, y2, y3, y4, y5} =
        let
            val e = map Word9.toInt [y1, y2, y3, y4, y5]
            val ll =
                List.tabulate 
                (HEIGHTR,
                 (fn y =>
                  List.tabulate
                  (WIDTHR,
                   (fn x => (Array.sub (board, y * WIDTHR + x), y * WIDTHR + x)))))
        in
            StringUtil.delimit "\n"
            (map 
             (fn l => 
              String.concat 
              ((map (fn (w, _) => "+" ^ (if Word32.andb(w, UP) > 0w0 then "-" else " ") ^ "+") l) @
               "\n" ::
               (map (fn (w, i) => (if Word32.andb(w, LEFT) > 0w0
                              then "|" else " ") ^ 
                              (if List.exists (fn z => z = i) e
                               then "X"
                               else " ") ^
                             (if Word32.andb(w, RIGHT) > 0w0
                              then "|" else " ")) l) @ "\n" ::
               (map (fn (w, _) => "+" ^ (if Word32.andb(w, DOWN) > 0w0 then "-" else " ") ^ "+") l))) ll)
        end

    fun tocode {y1, y2, y3, y4, y5} =
        let
            val e = map Word9.toString [y1, y2, y3, y4, y5]
        in
            StringUtil.delimit "," e
        end

    (* if there is a "Z" entity, then, all yellows must be bigger than it *)
    fun accepting {y1, y2, y3, y4, y5} =
      (case z of
         NONE => true
       | SOME i => i < y1 andalso i < y2 andalso i < y3 andalso i < y4 andalso i < y5)

    val constant_distance = true
end
