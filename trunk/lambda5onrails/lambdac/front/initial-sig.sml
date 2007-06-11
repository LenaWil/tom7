
(* The initial context. *)

signature INITIAL =
sig

    val ilint : IL.typ
    val ilchar : IL.typ
    val ilstring : IL.typ
    val ilexn : IL.typ

    (* these are abstract type variables *)
    val intvar : Variable.var
    val charvar : Variable.var
    val stringvar : Variable.var
    val exnvar : Variable.var

    val initial : Context.context
    val homename : string
    val home : IL.world
    val homekind : IL.worldkind

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


    val mobiletvars : Variable.Set.set

end