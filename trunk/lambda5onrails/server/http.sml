(* XXX this should be a functor so we can decide how to chunk up the
   incoming contents. For now we just parse the whole thing as one *)

(* PERF this is written for simplicity, not speed. All the concatenation
   and repeated searching for the header terminator is a real waste. *)

structure Http :> PACKETIZER where type packet = HttpPacket.http_packet =
struct

    open HttpPacket

    type packet = http_packet

    (* we either have some partial headers, or we've seen all the headers,
       including a content-length field that tells us how much data is
       coming, and now we're working on the contents *)
    datatype partialpacket =
      Phead of string
    | Pcont of int * string
    | Pdone

    val empty = Phead ""

    fun parse (Phead s) new =
      let val a = s ^ new
      in
        case StringUtil.find "\r\n\r\n" a of
          (* headers not done yet.. *)
          NONE => (nil, Phead a)
        | SOME i =>
            let val hchunk = String.substring(a, 0, i)
                val hchunk = StringUtil.filter (fn #"\r" => false | _ => true) hchunk
                val headers = String.tokens (fn #"\n" => true | _ => false) hchunk

                val cl =
                  case List.find (StringUtil.matchhead "Content-Length:") headers of
                    NONE => (* XXX? *) raise Http "no content-length header"
                  | SOME h => 
                      case 
                        Int.fromString(List.last
                                       (String.tokens
                                        (fn c => c = #" " orelse
                                         c = #"\t") n)) of
                        NONE => raise Http "content-length wasn't an integer?"
                      | SOME x => x

            in
              ([Phead headers], Pcont (cl, String.substring(a, i, size a - i)))
            end
        end
      | parse (Pcont (len, s)) new =
        let
          val a = s ^ new
        in
          if size a >= len
          then ([String.substring(a, 0, len)], Pdone)
          else (nil, Pcont (len, a))
        end
      (* we'll never return any more packets... *)
      | parse Pdone _ = (nil, Pdone)

    (* inserts CRLF at the end of http lines *)
    fun make (head, body) =
        (foldr (fn (curr, acc) => curr ^ "\r\n" ^ acc) "" head) ^
        (case body of SOME s =>
                          String.concat["Content-length: ",
                              Int.toString(size s), "\r\n\r\n", s]
                    | NONE => "\r\n")

    val protocol = Network.protocol { make = make,
                                      parse = parse,
                                      empty = empty,
                                      desc = "HTTP" }

end
