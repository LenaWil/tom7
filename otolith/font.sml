structure Font =
struct

  type font = { width : int, height : int,
                image : Images.image,
                chars : string,
                table : int Array.array }

  fun make { width, height, image, chars } : font =
    let
      val table = Array.array(255, 0)
      val () =
        (* invert the map *)
        Util.for 0 (size chars - 1)
        (fn i =>
         Array.update (table, ord (String.sub(chars, i)), i))
    in
      { width = width, height = height, image = image,
        chars = chars, table = table }
    end

  val pxfont = make
    { width = 6,
      height = 5,
      image = Images.pxfont,
      chars = " ABCDEFGHIJKLMNOPQRSTUVWXYZ" ^
      "abcdefghijklmnopqrstuvwxyz0123456789" ^
      "`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?" (* " *)
      (* CHECKMARK ESC HEART LCMARK1 LCMARK2
         BAR_0 BAR_1 BAR_2 BAR_3 BAR_4 BAR_5 BAR_6
         BAR_7 BAR_8 BAR_9 BAR_10 BARSTART LRARROW LLARROW *)
      }

end
