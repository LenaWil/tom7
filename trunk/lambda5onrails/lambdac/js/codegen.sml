structure JSCodegen :> JSCODEGEN =
struct

  infixr 9 `
  fun a ` b = a b

  exception JSCodegen of string

  open JSSyntax

  structure C = CPS

  fun vtoi v = $(Variable.tostring v)

  (* convert the expression exp and send the result to the continuation k *)
  fun cvte exp k : Statement.t list =
    [Throw ` String ` String.fromString "unimplemented exp"]

  fun generate { labels, labelmap } (lab, SOME global) =
    let
      (* In this type-erasing translation there are a lot of things
         we'll ignore, including the difference between PolyCode and Code. *)
      val va = 
        (case C.cglo global of
           C.PolyCode (_, va, _) => va
         | C.Code (va, _, _) => va)
    in
      (case C.cval va of
         C.AllLam { worlds = _, tys = _, vals, body } =>
           (case C.cval body of
              C.Lams fl =>
                Array ` % ` map SOME `
                map (fn (f, args, e) =>
                     let
                     in
                       Function { args = % ` map (vtoi o #1) args,
                                  name = NONE,
                                  body = % ` cvte e (fn je =>
                                                     [Return je])
                                  }
                     end) fl

            | C.AllLam _ => raise JSCodegen "hoisted alllam unimplemented"
            | _ => raise JSCodegen ("expected label " ^ lab ^ 
                                    " to be alllam then lams/alllam"))

         | _ => raise JSCodegen ("expected label " ^ lab ^ 
                                 " to be a (possibly empty) AllLam"))
    end
    | generate _ (lab, NONE) = 
    Function { args = %[],
               name = NONE,
               body = %[Throw ` String ` 
                        String.fromString "wrong world"] }

end