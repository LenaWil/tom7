
signature PASSWD =
sig

   exception Passwd of string

   type entry = {login : string,
		 uid : int,
		 gid : int,
		 name : string,
		 home : string,
		 shell : string}

   (* initialize the database from the supplied
      filename, typically /etc/passwd *)
   val readdb : string -> unit

   (* return info for a login name *)
   val lookup : string -> entry option    

   val lookupuid : int -> entry option

end
