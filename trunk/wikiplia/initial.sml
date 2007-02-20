
(* seed the database with the initial program *)

structure Initial =
struct

  fun init () = 
    let 
      (* This "ties the knot", since we know that b:compile.b is just the parser. *)
      val compile_b = StringUtil.readfile "b_compile.b"
      val compile = Eval.eval nil (Parse.parse compile_b)
      val main_b = StringUtil.readfile "main.b"
      val main = Parse.parse main_b
    in
      ignore ( DB.insert "b:compile.b" (Bytes.String compile_b) );
      ignore ( DB.insert "b:compile" compile );

      ignore ( DB.insert "main.b" (Bytes.String main_b) );
      ignore ( DB.insert "main" main )
    end

end
