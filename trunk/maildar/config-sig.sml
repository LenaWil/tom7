
signature CONFIG =
sig

    (* you must implement a structure Config
       with this signature! *)

    datatype action =
        MessageBoard of int
      | Radar of int

    (* Passwords, which don't have to be correct
       if you don't want to use these features *)
    val MSG_ADMINPASS : string
    val WEBLOG_PASS : string

    (* What is the name of the mail host? *)
    val HOST : string

    val WEBLOG_HOST : string
    val WEBLOG_PORT : int

    val MSG_HOST : string
    val MSG_PORT : int
    val MSG_POSTNAME : string
    val MSG_IMGTITLE : string

    (* After getting this many bytes, give up. *)
    val MAX_MESSAGE : int

    (* is this from address allowed? *)
    val senderok : string -> bool

    (* determine the intended action from the to: addr *)
    val what_action : string -> action

    (* applied to each textual line in the input; if false,
       that line is excised *)
    val linefilter : string -> bool

end
