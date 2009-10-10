
default : shortestpaths tosvg makepoints points.kml radial

PACTOMLIB=pactom.sml pactom-sig.sml ../sml-lib/files/xml/xml*.sml ../sml-lib/misc/color*.sml ../sml-lib/misc/latlon*.sml

shortestpaths : shortestpaths.sml shortestpaths.cm ${PACTOMLIB} ../sml-lib/geom/*.sml ../sml-lib/data/undirected-graph*.sml

colorize : colorize.sml colorize.cm ${PACTOMLIB}
	mlton colorize.cm

tosvg : tosvg.sml tosvg.cm ${PACTOMLIB}
	mlton tosvg.cm

elevsvg : elevsvg.sml elevsvg.cm ${PACTOMLIB}
	mlton elevsvg.cm

makepoints : makepoints.sml makepoints.cm ${PACTOMLIB} ../sml-lib/geom/*.sml
	mlton makepoints.cm

points.kml : makepoints neighborhoods.kml
	time ./makepoints > points.kml

radial : radial.sml radial.cm ${PACTOMLIB} ../sml-lib/geom/*.sml
	mlton radial.cm

radial.svg : radial
	time ./radial > radial.svg
