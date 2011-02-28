(* Coin words with coinduction. *)
structure Coin =
struct
  
  val lines = SimpleStream.tolinestream (SimpleStream.fromfilechar "wordlist.asc")

end