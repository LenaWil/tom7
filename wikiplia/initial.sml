
(* seed the database with the initial program *)

structure Initial =
struct

  fun init () = ignore ( DB.insert "main" (Parse.parse (StringUtil.readfile "main.b")) )

end