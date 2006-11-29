
signature CONTEXT =
sig
    exception Absent of string * string

    type context

    val empty : context


    (* lookup operations *)
   
    (* resolve a value identifier in the current context, return its type and
       status and world *)
    datatype varsort =
      Modal of IL.world
    | Valid

    val var : context -> string -> IL.typ IL.poly * Variable.var * IL.idstatus * varsort

    (* resolve a type/con identifer in the current context, return its kind
       and binding *)
    val con : context -> string -> IL.kind * IL.con * IL.tystatus

    val world : context -> string -> Variable.var

    (* has_evar ctx n
       Does the context contain the free evar n in the type of any
       term? *)
    val has_evar : context -> int -> bool



    (* context extension operations *)
    
    (* bind a valid variable *)
    val bindu : context -> string -> IL.typ IL.poly -> Variable.var -> IL.idstatus -> context

    (* bind a world *)
    val bindw : context -> string -> Variable.var -> context

    (* bind an identifier to a variable and give that variable 
       the indicated type at the indicated world *)
    val bindv : context -> string -> IL.typ IL.poly -> Variable.var -> IL.world -> context
    (* also idstatus, if not Normal *)
    val bindex : context -> string -> IL.typ IL.poly -> Variable.var -> IL.idstatus -> varsort -> context

    (* bind an identifier to a type constructor with the indicated kind *)
    val bindc : context -> string -> IL.con -> IL.kind -> IL.tystatus -> context

end
