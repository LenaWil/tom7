(* Tests that the ASTFn works correctly. *)

structure ASTConformance =
struct

  exception Conformance of string

  structure Arg =
  struct
    val ctr = ref 0
    type var = string
    val var_eq = op= : string * string -> bool
    val var_cmp = String.compare
    fun var_vary s = 
      let in
        ctr := !ctr + 1;
        s ^ "_" ^ Int.toString (!ctr)
      end

    fun var_tostring s = s

    val Exn = Conformance

    type leaf = string
    val leaf_cmp = String.compare
  end

  structure A = ASTFn(Arg)
  open A
  infixr / \ // \\


  fun real_count x a =
    case look a of
      V y => if x = y then 1 else 0
    | l / r => real_count x l + real_count x r
    | _ \ r => real_count x r
    | S l => foldr op+ 0 (map (real_count x) l)
    | B (_, r) => real_count x r
    | $ _ => 0

  fun correct_count l t =
    if List.all (fn x => real_count x t = count t x) l
    then ()
    else raise Conformance "counts not correct"

  fun self_equal t = 
    if ast_cmp (t, t) = EQUAL
    then ()
    else raise Conformance "not equal to self"

  val () =
    let
      
      val vars = ["w", "x", "y", "z"]
      val terms_base =
        [VV "x",
         VV "y",
         VV "z",
         $$ "leaf",
         VV "x" // VV "y",
         "x" \\ VV "x",
         "x" \\ VV "y",
         "x" \\ (VV "x" // VV "x"),
         "x" \\ (SS [VV "x", VV "x", VV "y"]),
         "x" \\ "x" \\ VV "x",
         "x" \\ "y" \\ VV "x",
         "x" \\ "y" \\ VV "y",
         "x" \\ (VV "x" // "x" \\ VV "x"),
         BB (["x", "y"], VV "x"),
         BB (["y", "x"], VV "x"),
         BB ([], VV "x"),
         BB ([], $$ "leaf"),
         VV "x" // ("x" \\ VV "x")]
        
      val () = app self_equal terms_base
      val () = app (correct_count vars) terms_base
        
      (* [t/x]t'  for every term, var, term above *)
      val terms_subst =
        List.concat
        (
         map (fn t' =>
              List.concat
              (map (fn t =>
                    (map (fn v => sub t' v t) vars)) terms_base)) terms_base
         )
        
      val () = app self_equal terms_subst
      val () = app (correct_count vars) terms_subst
        
    in
      ()
    end handle (e as Conformance s) =>
      let in
        print (s ^ "\n");
        raise e
      end

end
