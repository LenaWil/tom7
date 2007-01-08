
(* Dictionary-passing transformation. 

   This pass transforms polymorphic code to insert dictionaries at
   'Get' expressions. The dictionary is a value that contains functions
   for marshalling and unmarshalling the type 

*)


structure ILDict :> ILDICT =
struct


  fun transform _ = raise ILDict "unimplemented"

end