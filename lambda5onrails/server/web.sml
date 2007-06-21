
structure Web =
struct

  structure R = RawNetwork
  exception Web of string

  val PORT = 5555

  val log = TextIO.openAppend "log.txt"

  fun message (Web s) = "web: " ^ s
    | message (RawNetwork.RawNetwork s) = "raw net: " ^ s
    | message e = "?:" ^ exnMessage e

  fun go () =
    let
      val server = R.listen PORT

      fun loop () =
        (let
           val () = print "accept...\n"
           val (peer, peera) = R.accept server
         in
           print "process request...\n";
           request (peer, peera);
           loop ()
         end)

      and request (p, addr) =
        let
          val () = print "receive message..."
          val (hdrs, content) = recvhttp p
          val (method, h') = StringUtil.token (StringUtil.ischar #" ") hdrs
          val (url, h') = StringUtil.token (StringUtil.ischar #" ") h'

          val now = (Time.now ())

          fun nocr s = StringUtil.filter (fn #"\r" => false | _ => true) s
            
          val kvp = String.fields (StringUtil.ischar #"&") content
          val kvp = List.mapPartial (fn one =>
                                     case String.fields (StringUtil.ischar #"=") one of
                                       [key, value] => (case StringUtil.urldecode value of
                                                          NONE => NONE
                                                        | SOME s => SOME (key, nocr s))
                                     | _ => NONE) kvp

          val nows = (Date.fmt "%a, %d %b %Y %H:%M:%S %Z" (Date.fromTimeLocal now))

          (* val () = ignore (DB.insert "request.method" "GET") *)
          val url = case StringUtil.urldecode url of
                             NONE => url (* ?*)
                           | SOME u => u

          val ip = let val (a, b, c, d) = R.addressip addr
                   in StringUtil.delimit "." (map Int.toString [a, b, c, d])
                   end

(*
          (* put form elements in database *)
          val G = map (fn (k, v) => ("form." ^ k, (Bytes.String v))) kvp
          val G = ("request.url", Bytes.String url) :: G
          val G = ("request.ip", Bytes.String ip) :: G
          val G = ("request.time", Bytes.String nows) :: G
*)

          val () = TextIO.output(log, nows ^ " | " ^ ip ^ " | " ^
                                url ^ "\n")
          val () = TextIO.flushOut log

          fun http code = ("HTTP/1.1 " ^ code ^ "\r\n" ^
                           "Date: " ^ nows ^ "\r\n" ^
                           "Server: Server5\r\n" ^
                           "Connection: close\r\n");

          (* FIXME totally ad hoc! *)
          val sbc = BytecodeParse.parsefile "../lambdac/tests/get_server.b5"

        in
          print ("URL: [" ^ url ^ "]\n");
          (* app (fn (k, v) => print ("[" ^ k ^ "]=[" ^ v ^ "]\n")) kvp; *)
          
          (* print "send response...\n"; *)

          

          (let
             (* FIXME totally ad hoc! *)

             val rt = StringUtil.readfile "../lambdac/js/runtime.js"
             val js = StringUtil.readfile "../lambdac/tests/get_home.js"
             val data =
               "<html><head>\n" ^
               "<title>Server 5 Test Page!</title>\n" ^
               "<script language=\"JavaScript\">\n" ^ rt ^ "\n</script>\n" ^
               "<script language=\"JavaScript\">\n" ^ js ^ "\n</script>\n" ^
               "</head>\n" ^
               "<body>\n" ^
               "Welcome to Server 5!\n" ^
               "</body></html>\n";


             val res = ("Content-Type: text/html; charset=utf-8\r\n" ^
                        "\r\n" ^
                        data)
           in
             sendall p (http "200 OK" ^ res)
           end handle e => (print "ERROR.\n";
                            (* XXX internal server error? *)
                            sendall p (http "200 OK");
                            sendall p ("Content-Type: text/html; charset=utf-8\r\n" ^
                                       "\r\n");
                            sendall p ("ERROR. " ^ message e))) handle R.RawNetwork _ => ();

          (R.hangup p) handle _ => ()
        end

      and sendall p s =
        let
          val x = R.send p s
        in
          if x < 0
          then raise R.RawNetwork "sendall to closed" (* closed? *)
          else
            if x < size s
            then sendall p (String.substring(s, x, size s - x))
            else () 
        end

      and recvhttp p =
        let
          val headerlength = ref NONE (* length of headers string up to and including
                                         the terminating \r\n\r\n *)
          val contentlength = ref NONE

          (* string preceding content length int *)
          val cls = "Content-Length: "

          (* XXX I think HTTP/1.0 can also be connection:close w/o content length? *)
          fun more s =
            ((* print ("sofar: [" ^ s ^ "]\n"); *)
             case R.recv p of
               "" => (s, "") (* XXX what do we assume if connection closed? *)
             | s' => 
                 let val s = s ^ s'
                   fun next () =
                   (case !headerlength of
                      SOME h =>
                        (case !contentlength of
                           SOME cl =>
                             (* did we read enough? *)
                             if size s >= h + cl
                             then (String.substring(s, 0, h),
                                   String.substring(s, h, cl))
                             else more s
                         | NONE => (* XXX? *) (print "bad content length...\n"; 
                                               raise R.RawNetwork "uhhh"))
                    | NONE =>
                           (case StringUtil.find "\r\n\r\n" s of
                              SOME n => (headerlength := SOME (n + 4);
                                         (case StringUtil.find cls s of
                                            SOME cl => 
                                              (contentlength :=
                                               Int.fromString(String.substring(s,
                                                                               cl + size cls,
                                                                               size s - (cl + size cls)));
                                               next ())
                                          | NONE => (* assume no content... *) (s, "")))
                            | NONE => more s))
                 in
                      next ()
                 end)
        in
          more ""
        end
    in
      loop ()
    end

end