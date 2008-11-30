(* Makes crossword puzzles. 

   The difficulty (because it is a large search space) comes from the
   placement of some set of clues into the grid in such a way that
   they cover as much of the grid as possible.

   Let's say there are two modes:

   (Place mode.) Try to fit every word in our required list into the
   grid. There are many such placements; we simply enumerate them.

   (Fill mode.) For each placement above, try to fill the rest of the
   grid with legal words from the dictionary. Here the difference is
   that instead of searching over words, are searching over grid
   cells.

*)
structure XWord =
struct

    

end
