
    Twelf code for Proposal / Thesis   -      Tom Murphy  14 Nov 2007

These files constitute the formalization of the calculi in my thesis
work.

 el.elf - The external language 
 il.elf - Internal language with dynamic semantics
 elab.elf - Translation from external language to internal
 cps.elf - CPS language and dynamic semantics
 tocps.elf - Converts to CPS language
 cc.elf - Closure conversion ("specification")

Things I didn't do:
 - letcc/throw
 - type polymorphism
 - sums
 - recursive types
 - hoisting after closure conversion

