
(* Contexts for elaboration. *)
signature CONTEXT =
sig
    (* what sort of thing (world, type, val), id *)
    exception Absent of string * string
    (* other problems *)
    exception Context of string

    type context
    datatype varsort = datatype IL.varsort

    val empty : context

    val stol : varsort -> Layout.layout
    val ctol : context -> Layout.layout

    (* lookup operations *)

    (* resolve a value identifier in the current context, return its type and
       status and world *)
    val var : context -> string -> IL.typ IL.poly * Variable.var * IL.idstatus * varsort

    (* resolve a type/con identifer in the current context, return its kind
       and binding *)
    val con : context -> string -> IL.kind * IL.con * IL.tystatus

    val world : context -> string -> IL.world

    (* has_evar ctx n
       Does the context contain the free type evar n in the type of any
       bound variable?*)
    val has_evar  : context -> int -> bool
    (* same, but for free world evars *)
    val has_wevar : context -> int -> bool


    (* context extension operations *)
    
    (* bind a world *)
    val bindw : context -> string -> Variable.var -> context
    val bindwlab : context -> string -> IL.worldkind -> context

    (* bind an identifier to a variable and give that variable 
       the indicated type at the indicated world *)
    val bindv : context -> string -> IL.typ IL.poly -> Variable.var -> IL.world -> context
    (* also idstatus, if not Normal; not necessary to give EL name *)
    val bindex : context -> string option -> IL.typ IL.poly -> Variable.var -> IL.idstatus -> varsort -> context

    (* bind an identifier to a type constructor with the indicated kind *)
    val bindc : context -> string -> IL.con -> IL.kind -> IL.tystatus -> context

    (* note that an IL type variable is mobile. *)
    val bindmobile : context -> Variable.var -> context
    val ismobile : context -> Variable.var -> bool

end
