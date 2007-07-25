
signature BYTETOKENIZE =
sig
    (* Parser for tokens *)
    val token : (ByteTokens.token * Pos.pos,char) Parsing.parser

end
