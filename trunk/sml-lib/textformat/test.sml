
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
      val () = print ("n1s: (" ^ n1s ^ ")\n")
      val n1n = N.fromstring n1s

      val () = case n1n of
          N { id = 5, x = 10, y = 20, name = NONE,
              parent = NONE,
              triangles = [(1, 2), (3, 4)] } => ()
            | _ => raise Failure "didn't get back the same thing"

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
