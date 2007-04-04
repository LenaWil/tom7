
structure Web =
struct

  structure R = RawNetwork
  exception Web of string

  val PORT = 2222

  val log = TextIO.openAppend ("log.txt")

  fun message (Eval.Abort s) = "abort: " ^ s
    | message (Web s) = "web: " ^ s
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

          (* put form elements in database *)
          val G = map (fn (k, v) => ("form." ^ k, (Bytes.String v))) kvp

          (* val () = ignore (DB.insert "request.method" "GET") *)
          val G = ("request.url", Bytes.String url) :: G
          val ip = let val (a, b, c, d) = R.addressip addr
                   in StringUtil.delimit "." (map Int.toString [a, b, c, d])
                   end
          val G = ("request.ip", Bytes.String ip) :: G

          val G = ("request.time", Bytes.String nows) :: G

          val () = TextIO.output(log, nows ^ " | " ^ ip ^ " | " ^
                                url ^ "\n")
          val () = TextIO.flushOut log

          fun http code = ("HTTP/1.1 " ^ code ^ "\r\n" ^
          "Date: " ^ nows ^ "\r\n" ^
           "Server: Wikiplia\r\n" ^
           "Connection: close\r\n");


        in
          print ("URL: [" ^ url ^ "]\n");
          (* app (fn (k, v) => print ("[" ^ k ^ "]=[" ^ v ^ "]\n")) kvp; *)
          
          (* print "send response...\n"; *)

          (let
             val (res, steps) = 
               case Eval.eval G (DB.head "main") of
                 (Bytes.String s, steps) => (s, steps)
               | (_, steps) => ("Content-Type: text/html; charset=utf-8\r\n" ^
                                "\r\n" ^
                                "(complex data)", steps)
           in
             print ("took " ^ Int.toString steps ^ " steps\n");
             if StringUtil.matchhead "Location:" res
             then 
               let in
                 (* print ("Redirect: [" ^ res ^ "]\n"); *)
                 sendall p (http "302 Found" ^ res)
               end
             else
               let in
                 (* print ("Result: [" ^ res ^ "]\n"); *)
                 sendall p (http "200 OK" ^ res)
               end
           end handle e => (print "ERROR.\n";
                            (* XXX internal server error? *)
                            sendall p (http "200 OK");
                            sendall p ("Content-Type: text/html; charset=utf-8\r\n" ^
                                       "\r\n");
                            sendall p ("ERROR. " ^ message e))) handle R.RawNetwork _ => ();
          print "hangup...\n";
          (R.hangup p) handle _ => ();
          (* PERF not on every request, surely! *)
          if DB.changed ()
          then (DB.save Initial.DBFILE;
                print "Saved.\n")
          else ()
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