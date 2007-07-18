structure CSS =
struct

  val css = 
      "<STYLE TYPE="text/css">\n" ^

      "P { font: 10pt Verdana,Arial,Helvetica }\n" ^ 

      "TH { font: bold 10pt Verdana,Arial,Helvetica ; text-align: center}\n" ^ 

      "TD { font: 10pt Verdana,Arial,Helvetica }\n" ^ 

      "TR.row_even { background : #DDFFDD }\n" ^
      "TR.row_odd  { background : #FFDDFF }\n" ^

      "A:link { color: #4444DD } \n" ^
      "A:visited { color: #9999FF } \n" ^
      "A:active { color: #DDDD44 } \n" ^

      "</STYLE>\n"


end