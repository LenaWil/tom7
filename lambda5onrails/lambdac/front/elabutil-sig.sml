
signature ELABUTIL =
sig

    exception Elaborate of string

    val ltos : Pos.pos -> string

    val error : Pos.pos -> string -> 'b

    val new_evar : unit -> IL.typ
    val new_wevar : unit -> IL.world

    (* unify context location message actual expected *)
    val unify : Context.context -> Pos.pos -> string -> 
                    IL.typ -> IL.typ -> unit

    val unifyw : Context.context -> Pos.pos -> string -> 
                     IL.world -> IL.world -> unit

    (* int to string *)
    val itos : int -> string

    (* generate a new string with arg as base *)
    val newstr : string -> string

    (* if t has unset evars, replace those with new type
       variables. return the list of new type variables
       and the substituted type. Pass in a "surrounding
       context" to determine which variables are (in)eligible
       for generalization. *)
    val polygen : Context.context -> IL.typ -> IL.typ * Variable.var list

    (* instantiate all of the bound type and world variables with new evars and wevars;
       return the types and worlds used to instantiate the type *)
    val evarize : IL.typ IL.poly -> IL.typ * IL.world list * IL.typ list

    val unroll : Pos.pos -> IL.typ -> IL.typ

    val mono : 'a -> 'a IL.poly

end