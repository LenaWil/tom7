signature BYTEPRINT =
sig

  exception BytePrint of string

  val stol  : Bytecode.statement -> Layout.layout
  val etol  : Bytecode.exp -> Layout.layout
  val pdtol : Bytecode.primdict -> Layout.layout
  val ptol  : Bytecode.program -> Layout.layout

end
