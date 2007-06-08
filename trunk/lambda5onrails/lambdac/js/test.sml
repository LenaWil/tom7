
structure JSTest =
struct

  structure J = Javascript

  val $ = J.Id.fromString
  val % = Vector.fromList

  open J.Joint

  val j = J.Program.T (%[FunctionDec { args = %[$"x"],
                                       name = $"myfunction",
                                       body = %[Exp (Call { func = Id ($"alert"),
                                                            args = %[Id($"x")] }),
                                                Return NONE] }
                         ])

  val () = Layout.print (J.Program.layout j, print)

end
