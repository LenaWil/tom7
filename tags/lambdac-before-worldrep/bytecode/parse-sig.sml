
signature BYTECODEPARSE =
sig
    exception BytecodeParse of string
    
    val program : (Bytecode.program, ByteTokens.token) Parsing.parser

    val parsefile : string -> Bytecode.program
end
