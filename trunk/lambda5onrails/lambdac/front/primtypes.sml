
structure PrimTypes :> PRIMTYPES =
struct

    exception Unimplemented
    
    fun typeof "halt" = raise Unimplemented
        

end
