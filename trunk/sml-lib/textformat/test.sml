
structure Test =
struct

  exception Failure of string

  open TestTF

  fun thetest () =
    let

(*
  val node = N {
  datatype node = N of {
    id : int,
    x : int,
    y : int,
    name : (int * int) option,
    triangles : (int * int) list
  }

  and tesselation = S of {
    nodes : (node) list
  }
*)

      val n1 = N { id = 5, x = 10, y = 20, name = NONE,
                   parent = NONE,
                   triangles = [(1, 2), (3, 4)] }

      val n1s = N.tostring n1
      val () = print ("n1s: '" ^ n1s ^ "'\n")
      val n1n = N.fromstring n1s

      val () = case n1n of
          N { id = 5, x = 10, y = 20, name = NONE,
              parent = NONE,
              triangles = [(1, 2), (3, 4)] } => ()
            | _ => raise Failure "didn't get back the same thing"

      val n2 = N { id = 6, x = 2, y = ~123, name = SOME (0, 0),
                   parent = NONE,
                   triangles = [(9, 90)] }

      val s1 = S { nodes = [n1, n2] }
      val s1s = S.tostring s1
      val () = print ("s1s: '" ^ s1s ^ "'\n")
      val s1n = S.fromstring s1s

      val () = case s1n of
          S { nodes = [n1', n2'] } => if n1 = n1' andalso n2 = n2'
                                      then ()
                                      else raise Failure "nodes not same"
        | _ => raise Failure "outer not same"

      val _ = S.fromstring ""
      val _ = N.fromstring ""
    in
      ()
    end handle e =>
        let in
            (case e of
                 Parse s => print ("FAIL: " ^ s ^ "\n")
               | _ => print ("???\n"));
            raise e
        end

  val () = thetest ()
  val () = print "OK.\n"
end
