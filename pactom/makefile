
default : tosvg makepoints points.kml radial

colorize : colorize.sml colorize.cm ../sml-lib/files/xml/xml.sml ../sml-lib/files/xml/xml-sig.sml ../sml-lib/misc/color*.sml
	mlton colorize.cm

tosvg : tosvg.sml pactom*.sml tosvg.cm ../sml-lib/files/xml/xml.sml ../sml-lib/files/xml/xml-sig.sml ../sml-lib/misc/color*.sml ../sml-lib/misc/latlon*.sml
	mlton tosvg.cm

elevsvg : elevsvg.sml elevsvg.cm ../sml-lib/files/xml/xml.sml ../sml-lib/files/xml/xml-sig.sml ../sml-lib/misc/color*.sml
	mlton elevsvg.cm

makepoints : makepoints.sml makepoints.cm ../sml-lib/files/xml/xml.sml ../sml-lib/files/xml/xml-sig.sml  ../sml-lib/geom/*.sml ../sml-lib/misc/latlon*.sml
	mlton makepoints.cm

points.kml : makepoints neighborhoods.kml
	time ./makepoints > points.kml

radial : radial.sml pactom*.sml ../sml-lib/files/xml/xml*.sml ../sml-lib/geom/*.sml ../sml-lib/misc/latlon*.sml radial.cm
	mlton radial.cm

radial.svg : radial
	time ./radial > radial.svg
