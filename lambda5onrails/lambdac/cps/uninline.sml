(* This simply removes the Inline constructor,
   which persists even after inlining. It does
   no harm but can prevent us from recognizing
   syntactic forms. *)

structure CPSUninline :> CPSUNINLINE =
struct

  structure V = Variable
  open CPS CPSUtil

  fun I x = x

  exception Uninline of string

  fun uninlinee e = pointwisee I uninlinev uninlinee e
  and uninlinev v =
      case cval v of
        Inline v => pointwisev I uninlinev uninlinee v
      | _ => pointwisev I uninlinev uninlinee v

  fun optimize G e = uninlinee e

end