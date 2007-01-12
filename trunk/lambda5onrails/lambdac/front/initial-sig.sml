
(* The initial context. *)

signature INITIAL =
sig

    val ilint : IL.typ
    val ilchar : IL.typ
    val ilstring : IL.typ

    val initial : Context.context
    val home : IL.world

    (* wrap with declarations and imports needed 
       by the compiler (bool, exceptions) *)
    val wrap : EL.elunit -> EL.elunit

    val trueexp  : Pos.pos -> EL.exp
    val falseexp : Pos.pos -> EL.exp

    val trueexpil  : IL.exp
    val falseexpil : IL.exp

    val truepat  : EL.pat
    val falsepat : EL.pat

    val matchname : string
    (* value of exception Match *)
    val matchexp : Pos.pos -> EL.exp

    val boolname : string
    val truename : string
    val falsename : string
    val exnname : string
    val listname : string


end