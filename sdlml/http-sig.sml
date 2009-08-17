(* Code for making HTTP queries with SDL_Net. *)
signature HTTP =
sig
    datatype result =
	(* Success, with the data *)
	Success of string
	(* Can't connect, etc. With error message. *)
      | NetworkFailure of string
	(* Server 404, etc. With error message. *)
      | Rejected of string

    exception HTTP of string

    (* get_url url callback 
       Fetch the URL (must be of the form http://site[:port]/path)
       using HTTP GET. The callback is called periodically with
       the number of bytes received and the total number of bytes
       we're expecting, if known. Returns a result which can be
       either success, a network failure, or a server error. Raises
       HTTP if the URL is ill-formed. *)
    val get_url : string -> (int * int option -> unit) -> result

end