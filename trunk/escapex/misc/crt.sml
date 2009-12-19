

(* for "Chinese Remainder Theorem"
   this brute-forces the solution; although the
   Extended Euclidian algorithm is pretty easy,
   it's even easier to just try all reasonably small
   numbers and check if they work. *)

structure CRT =
struct
  (* series of equations of the form
     n = a1 mod b1
     n = a2 mod b2 ... *)
  val brian =
      (* initial bot offset, modulus *)
      [(1, 2),
       (2, 3),
       (3, 5),
       (3, 7),
       (8, 11),
       (7, 13),
       (1, 17),
       (4, 19)]

  fun normalize (a, b) = 
      if a < 0 then normalize (a + b, b)
      else (a mod b, b)

  fun satisfies n nil = true
    | satisfies n ((a, b) :: rest) =
      n mod b = a andalso satisfies (n + 1) rest

  fun solve l =
      let 
          val nl = map normalize l
          val _ = print (StringUtil.delimit "  "
                         (map (fn (a, b) => ("(" ^
                                             Int.toString a ^ ", " ^
                                             Int.toString b ^
                                             ")")) nl))
          val _ = print "\n"
          fun s x = 
              if satisfies x nl
              then x
              else s (x + 1)
      in
          s 0
      end
end