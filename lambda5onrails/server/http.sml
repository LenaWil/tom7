(*
  http packetizer based on Tom's LinePackets.  It's kind of
  odd, because the the sizes of the headers and body of an
  http request are determined in different ways.  The headers
  run until a blank line (that is, CRLFCRLF).  The length of
  the body is deteremined by the Content-Length header line.

  The heart of this is the parse function.  It take a partial
  packet of the form (string * int option).  The string is the
  request received so far, and the int option is the value
  carried by the Content-Length line, if any.  Parse tokenizes
  this string by newlines.  It then splits the resulting list
  into two parts, headers and body, by finding the first
  CRLFCRLF pair.

  It then checks to see if it yet knows the value of
  Content-Length.  If it does, it checks to see if the whole
  body has arrived.  If the body is all there, it cuts out the
  amount of data required and returns SOME of that as the  second
  element of a singleton list of a tuple, the rest of the tuple
  being a list of the http headers, along with the partial packet
  that is the rest of the data not sent.  If it does not yet have
  the entire body, it returns nil and the partial packet containing
  all the data for the current request received so far.

  If parse does not have value of the Content-Length header, it
  checks to see if it has yet received a blank line as part of
  this request.  If it has, it returns everything up to the
  blank line as headers, and the rest of the data as the next
  partial packet.  If it has not, it returns nil and the
  partial packet containing all the data for the current request
  received so far.
*)

structure Http :> PACKETIZER where type packet =
    string list * string option =
struct

    exception Http of string

    (*This will be a list of http headers
      cross the optional body *)
    type packet = string list * string option

    (* Piece of packet * contents of Content-length header if we've
       reached it *)
    type partialpacket = string * int option

    val empty = ("", NONE)

    fun parse (old, len) new =
        let
            (* split the data received so far into lines *)
            val pkt = (String.fields (fn c => c = #"\n") (old ^ new))
            (* break the list of lines into headers and body
            *)
            val (head, body, done) = foldl (fn (curr, (head, body, b)) =>
                if
                    b
                then
                    if body = ""
                    then (head, curr, b)
                    else (head, body ^ "\n" ^ curr, b)
                else
                    if curr = "" orelse curr = "\r"
                    then (head, body, true)
                    else (curr::head, body, b)
                ) ([], "", false) pkt
            (* find the total size of the body received so far *)
            val pos = String.size body
            (* find the contents of the Content-Length line, if known *)
            val len' = case len of
                           SOME n => SOME n
                         | NONE =>
                           case List.find
                                    (String.isSubstring "content-length:" o
                                     StringUtil.lcase)
                                    head
                            of SOME n => Int.fromString(List.last
                                                       (String.tokens
                                                       (fn c => c = #" " orelse
                                                                c = #"\t") n))
                             | NONE => NONE
        in
            (* if the length is known *)
            case len' of SOME n =>
                if
                    (* and we have all the data *)
                    pos >= n-1
                then
                    (* return it *)
                    ([(rev head, SOME (String.substring(body, 0, n)))],

                    (* rest of data is a partial packet *)
                    (* possible bug in MLton's String.extract...the basis
                       is unclear as to how to treat the length of zero
                       case. *)
                    (if pos >= n
                    then ""
                    else
                        String.extract(body, n, NONE), NONE))
                else
                    (nil, (old ^ new, len'))

               (* we don't know the length. *)
               | NONE =>
                   (* if we're done with the headers, then there is
                      no body *)
                   if done
                   then
                       (* return headers, and rest is a partial packet *)
                       ([(rev head, NONE)], (body, NONE))
                   (* not done, so return nil *)
                   else (nil, (old ^ new, len'))
        end

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
