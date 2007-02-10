
structure Web =
struct

  structure R = RawNetwork
  exception Web of string

  val PORT = 2222

  fun go () =
    let
      val server = R.listen PORT

      fun loop () =


        (let
           val () = print "accept...\n"
           val (peer, peera) = R.accept server
         in
           print "process request...\n";
           request peer;
           loop ()
         end)

      and request p =
        let
          val () = print "receive message..."
          val (hdrs, content) = recvhttp p

          val kvp = String.fields (StringUtil.ischar #"&") content
          val kvp = List.mapPartial (fn one =>
                                     case String.fields (StringUtil.ischar #"=") one of
                                       [key, value] => (case StringUtil.urldecode value of
                                                          NONE => NONE
                                                        | SOME s => SOME (key, s))
                                     | _ => NONE) kvp

          (* put form elements in database *)
          (* should we also put a parsed/tokenized version of these? *)
          val () = app (fn (k, v) => ignore (DB.insert ("form." ^ k) (Bytes.String v))) kvp

        in
          app (fn (k, v) => print ("[" ^ k ^ "]=[" ^ v ^ "]\n")) kvp;

          print "send response...\n";
          sendall p
          ("HTTP/1.1 200 OK\r\n" ^
          "Date: " ^ (Date.fmt "%a, %d %b %Y %H:%M:%S %Z" (Date.fromTimeLocal (Time.now ()))) ^ "\r\n" ^
           "Server: Wikiplia\r\n" ^
           "Connection: close\r\n" ^
           "Content-Type: text/html; charset=utf-8\r\n" ^
           "\r\n");
    (*
          sendall p "<p><b>We have received your message and will delete it promptly.</b></p>\n";
          sendall p ("<p>P.S. your headers were: [" ^ hdrs ^ "]</p>\n");
          sendall p ("<p>P.S. and your content was: [" ^ content ^ "]</p>\n");
          sendall p ("<p><form action=\"whatever\" method=\"post\"><input type=text name=a><textarea name=b>woo</textarea><input type=submit value=\"go\"></form></p>");
    *)
          (let
             val res = 
               case Eval.eval (DB.head "") of
                 Bytes.String s => s
               | _ => "(complex data)"
           in
             print ("Result: [" ^ res ^ "]\n");
             sendall p res
           end handle e => (print "ERROR.\n"; sendall p ("ERROR. " ^ exnMessage e)));
          print "hangup...\n";
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
            (print ("sofar: [" ^ s ^ "]\n");
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
                         | NONE => (* XXX? *) (print "bad content length...\n"; raise R.RawNetwork "uhhh"))
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