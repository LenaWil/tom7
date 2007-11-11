
structure D =
struct

  val cube_top =
    Vector.fromList (map Vector.fromList
    [[#"O", #"R", #"O", #"E", #"P",
      #"T", #"E", #"P", #"Y", #"U",
      #"T", #"A", #"A", #"I", #"S",
      #"O", #"D", #"N", #"N", #"H",
      #"M", #"B", #"D", #"T", #"K"],
     [#"D", #"O", #"A", #"M", #"B",
      #"R", #"R", #"E", #"C", #"E",
      #"U", #"T", #"S", #"N", #"I",
      #"T", #"E", #"O", #"L", #"F",
      #"V", #"C", #"P", #"C", #"T"],
     [#"R", #"F", #"R", #"X", #"A",
      #"I", #"I", #"H", #"U", #"C",
      #"I", #"J", #"E", #"D", #"E",
      #"U", #"N", #"E", #"A", #"E",
      #"A", #"W", #"T", #"P", #"F"],
     [#"V", #"E", #"R", #"H", #"I",
      #"X", #"E", #"S", #"B", #"L",
      #"P", #"N", #"O", #"B", #"L",
      #"V", #"S", #"N", #"T", #"I",
      #"C", #"E", #"P", #"S", #"L"],
     [#"B", #"S", #"L", #"L", #"K",
      #"Y", #"Y", #"V", #"E", #"I",
      #"L", #"N", #"I", #"N", #"O",
      #"N", #"K", #"R", #"P", #"A",
      #"E", #"E", #"F", #"P", #"I"]]
                     )

  val cube_test =
    Vector.fromList (map Vector.fromList
    [[#"1", #"A", #"A", #"A", #"2",
      #"A", #"A", #"A", #"A", #"A",
      #"A", #"A", #"A", #"A", #"A",
      #"A", #"A", #"A", #"A", #"A",
      #"3", #"A", #"A", #"A", #"4"],
     [#"B", #"B", #"B", #"B", #"B",
      #"B", #"B", #"B", #"B", #"B",
      #"B", #"B", #"B", #"B", #"B",
      #"B", #"B", #"B", #"B", #"B",
      #"B", #"B", #"B", #"B", #"B"],
     [#"C", #"C", #"C", #"C", #"C",
      #"C", #"C", #"C", #"C", #"C",
      #"C", #"C", #"C", #"C", #"C",
      #"C", #"C", #"C", #"C", #"C",
      #"C", #"C", #"C", #"C", #"C"],
     [#"D", #"D", #"D", #"D", #"D",
      #"D", #"D", #"D", #"D", #"D",
      #"D", #"D", #"D", #"D", #"D",
      #"D", #"D", #"D", #"D", #"D",
      #"D", #"D", #"D", #"D", #"D"],
     [#"E", #"E", #"E", #"E", #"E",
      #"E", #"E", #"E", #"E", #"E",
      #"E", #"E", #"E", #"E", #"E",
      #"E", #"E", #"E", #"E", #"E",
      #"E", #"E", #"E", #"E", #"E"]]
                     )

  val test_key =
    Vector.fromList
    [4, 0, 0, 0, 4,
     0, 0, 0, 0, 0,
     0, 0, 1, 1, 0,
     0, 0, 0, 0, 0,
     4, 0, 0, 0, 4]

(*
  val cube_backleft =
    Vector.fromList (map Vector.fromList
    [[#"O", #"D", #"R", #"V", #"B",
      #"R", #"O", #"F", #"E", #"S",
      #"O", #"A", #"R", #"R", #"L",
      #"E", #"M", #"X", #"H", #"L",
      #"P", #"B", #"A", #"I", #"K"],
     [#"T", #"R", #"I", #"X", #"Y",
      #"E", #"R", #"I", #"E", #"Y",
      #"P", #"E", #"H", #"S", #"V",
      #"Y", #"C", #"U", #"B", #"E",
      #"U", #"E", #"C", #"L", #"I"],
     [#"T", #"U", #"I", #"P", #"L",
      #"A", #"T", #"J", #"N", #"N",
      #"A", #"S", #"E", #"O", #"I",
      #"I", #"N", #"D", #"B", #"N",
      #"S", #"I", #"E", #"L", #"O"],
     [#"O", #"T", #"U", #"V", #"N",
      #"D", #"E", #"N", #"S", #"K",
      #"N", #"O", #"E", #"N", #"R",
      #"N", #"L", #"A", #"T", #"P",
      #"H", #"F", #"E", #"I", #"A"],
     [#"M", #"V", #"A", #"C", #"E",
      #"B", #"C", #"W", #"E", #"E",
      #"D", #"P", #"T", #"P", #"F",
      #"T", #"C", #"P", #"S", #"P",
      #"K", #"T", #"F", #"L", #"I"]]
                     )
*)
  val key =
    Vector.fromList
    [3, 3, 2, 1, 0,
     3, 2, 1, 0, 1,
     2, 1, 0, 1, 2,
     1, 0, 1, 2, 3,
     0, 1, 2, 3, 3]
(*
  val swine = (* normal *)
    Vector.fromList
    [4, 0, 0, 1, 3,
     2, 1, 2, 1, 0,
     0, 2, 1, 2, 0,
     0, 1, 2, 1, 2,
     4, 3, 2, 3, 2]
*)

  (* tom thinks it has to be this *)
  (* Adam has convinced himself *)

  val swine =
    Vector.fromList
    [4, 2, 0, 0, 4,
     0, 1, 2, 1, 3,
     0, 2, 1, 2, 2,
     1, 1, 2, 1, 3,
     3, 0, 0, 2, 2]

(* one more crazy transposition... *)
(*
  val swine =
    Vector.fromList
    [2, 2, 0, 0, 3,
     3, 1, 2, 1, 1,
     2, 2, 1, 2, 0,
     3, 1, 2, 1, 0,
     4, 0, 0, 2, 4]

  val swine =
    Vector.fromList
    [2, 3, 2, 3, 4,
     2, 1, 2, 1, 0,
     0, 2, 1, 2, 0,
     0, 1, 2, 1, 2,
     3, 1, 0, 0, 4]
*)
  fun chunk s =
    String.substring(s, 0, 5) ^ "\n"  ^
    String.substring(s, 5, 5) ^ "\n"  ^
    String.substring(s, 10, 5) ^ "\n" ^
    String.substring(s, 15, 5) ^ "\n" ^
    String.substring(s, 20, 5) ^ "\n"

  fun apply_key k cube =
    let
      val s =
        CharVector.tabulate (Vector.length k,
                             (fn i =>
                              let val offset = (0 + (0 - Vector.sub(k, i))) mod 5
                              in
                                Vector.sub(Vector.sub (cube, offset), i)
                              end))
    in
      chunk s
    end

  (* assumes k is applied to the top.
     returns a new cube in the same orientation *)
  fun make_cube k cube =
    let
    in
      Vector.tabulate
      (5,
       fn layer =>
       Vector.tabulate (Vector.length k,
                        (fn i =>
                         let val offset = (layer + (0 - Vector.sub(k, i))) mod 5
                         in
                           Vector.sub(Vector.sub (cube, offset), i)
                         end)))
    end

  fun show_cube c =
    Util.for 0 4
    (fn layer =>
     let in
       Util.for 0 4
       (fn y =>
        (Util.for 0 4
         (fn x =>
          print (implode [Vector.sub(Vector.sub(c, layer), y * 5 + x)])
          );
         print "\n"));
       print "\n"
     end)
    
  fun vector_cw v =
    Vector.tabulate (25,
                     fn i =>
                     let 
                       val x = i mod 5
                       val y = i div 5
                     in
                       Vector.sub(v, (4 - x) * 5 + y)
                     end)


  fun rot_cw cube = Vector.map vector_cw cube

  fun turn_left cube =
    Vector.tabulate (5,
                     fn layer =>
                     Vector.tabulate (25,
                                      fn i =>
                                      let
                                        val x = i mod 5
                                        val y = i div 5
                                      in
                                        (* x becomes layer,
                                           y is still y,
                                           layer becomes 4-x *)
                                        Vector.sub(Vector.sub(cube, x),
                                                   y * 5 + (4 - layer))
                                      end))

  fun turn_right cube = turn_left (turn_left (turn_left cube))
  fun rot_ccw cube = rot_cw (rot_cw (rot_cw cube))

  val cube_step1 = make_cube key cube_top
  val cube_backleft = turn_left (rot_cw cube_step1) (* orig good *)
  (* val cube_frontleft = rot_ccw (turn_right cube_step1) *)
  val cube_step2 = make_cube swine cube_backleft
(*
  val cube_step3 = make_cube swine cube_step2
  val cube_step4 = make_cube swine cube_step3
  val cube_step5 = make_cube swine cube_step4
  val cube_step6 = make_cube swine cube_step5
*)
  val cube_unrotated = rot_ccw (turn_right cube_step2)
(*  val cube_keyagain = make_cube key cube_unrotated *)
  val cube_frontleft = rot_ccw (turn_right cube_unrotated)
  val cube_final = make_cube swine cube_frontleft

  fun show_face c =
     let in
       Util.for 0 4
       (fn y =>
        (Util.for 0 4
         (fn x =>
          print (implode [Vector.sub(Vector.sub(c, 0), y * 5 + x)])
          );
         print "\n"));
       print "\n"
     end

  fun show_faces c =
    let in
      show_face c; (* A *)
      show_face (turn_right (rot_cw c)); (* B *)
      show_face (turn_left (turn_left c)); (* C *)
      show_face (turn_left (rot_cw c)); (* D *)
      show_face (turn_right c); (* E *)
      show_face (turn_left c); (* F *)
      ()
    end

end

