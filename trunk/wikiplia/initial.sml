
(* seed the database with the initial program *)

structure Initial =
struct

  (* the empty string key "" is the main program *)
  fun init () = ignore ( DB.insert "" (Parse.parse (StringUtil.readfile "initial.b")) )

end