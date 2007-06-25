
(* Has to be hoisted out because we can't
   say "where type t = datatype ..." *)
structure HttpPacket =
struct

  datatype http_packet =
    Headers of string list
  | Content of string

end
