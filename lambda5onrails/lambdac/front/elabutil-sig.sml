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

    (* also consider using IL.CompileWarn expression *)
    val warn : Pos.pos -> string -> unit

    (* generate a new string with arg as base *)
    val newstr : string -> string

    (* polygen sctx t
       
       perform polymorphic generalization on a type.
       If t if t has unset evars that do not appear anywhere
       in the context sctx, then they will be generalized.

       returns a new generalized type along with the bound
       type variables. *)
    val polygen : Context.context -> IL.typ -> IL.typ * Variable.var list

    (* instantiate all of the bound type and world variables with new evars and wevars;
       return the types and worlds used to instantiate the type *)
    val evarize : IL.typ IL.poly -> IL.typ * IL.world list * IL.typ list
    (* same, but list of types (result will have the same length) *)
    val evarizes : IL.typ list IL.poly -> IL.typ list * IL.world list * IL.typ list


    val unroll : Pos.pos -> IL.typ -> IL.typ

    val mono : 'a -> 'a IL.poly


    (* call this to clear the mobile check queue *)
    val clear_mobile : unit -> unit

    (* require that the type be mobile. If the type is not
       yet determined, then it will be placed in a queue to
       check after elaboration has finished. *)
    val require_mobile : Context.context -> Pos.pos -> string -> IL.typ -> unit

    val check_mobile : unit -> unit

    val ptoil : Primop.potype -> IL.typ

end
