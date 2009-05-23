
default : tosvg makepoints points.kml

colorize : colorize.sml colorize.cm ../sml-lib/files/xml/xml.sml ../sml-lib/files/xml/xml-sig.sml ../sml-lib/misc/color*.sml
	mlton colorize.cm

tosvg : tosvg.sml pactom*.sml tosvg.cm ../sml-lib/files/xml/xml.sml ../sml-lib/files/xml/xml-sig.sml ../sml-lib/misc/color*.sml ../sml-lib/misc/latlon*.sml
	mlton tosvg.cm

elevsvg : elevsvg.sml elevsvg.cm ../sml-lib/files/xml/xml.sml ../sml-lib/files/xml/xml-sig.sml ../sml-lib/misc/color*.sml
	mlton elevsvg.cm

makepoints : makepoints.sml makepoints.cm  ../sml-lib/files/xml/xml.sml ../sml-lib/files/xml/xml-sig.sml 
	mlton makepoints.cm

points.kml : makepoints neighborhoods.kml
	time ./makepoints > points.kml
