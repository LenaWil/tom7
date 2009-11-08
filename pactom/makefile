
# default : programs outputs
default : kmlcat
# default : shortestpaths shortest.kml
# default : llt.svg

PACTOMLIB=pactom.sml pactom-sig.sml ../sml-lib/files/xml/xml*.sml ../sml-lib/misc/color*.sml ../sml-lib/misc/latlon*.sml ../sml-lib/geom/latlontree*.sml ../sml-lib/geom/quadtree*.sml ../sml-lib/geom/pointlocation*.sml ../sml-lib/data/undirected-graph*.sml ../sml-lib/util/growarray*.sml ../sml-lib/algo/heap*.sml

# Generating programs.
programs : shortestpaths colorize tosvg elevsvg makepoints radial lltsvg kmlcat

kmlcat : kmlcat.sml kmlcat.cm ../sml-lib/util/*.sml
	mlton kmlcat.cm

shortestpaths : shortestpaths.sml shortestpaths.cm ${PACTOMLIB} 
	mlton shortestpaths.cm

colorize : colorize.sml colorize.cm ${PACTOMLIB}
	mlton colorize.cm

tosvg : tosvg.sml tosvg.cm ${PACTOMLIB}
	mlton tosvg.cm

elevsvg : elevsvg.sml elevsvg.cm ${PACTOMLIB}
	mlton elevsvg.cm

makepoints : makepoints.sml makepoints.cm ${PACTOMLIB} ../sml-lib/geom/*.sml
	mlton makepoints.cm

radial : radial.sml radial.cm ${PACTOMLIB} ../sml-lib/geom/*.sml
	mlton radial.cm

lltsvg : lltsvg.sml lltsvg.cm ${PACTOMLIB}
	mlton lltsvg.cm

# outputs
# XXX these should explicitly depend on inputs, like pactom.kml

outputs : radial.svg points.kml llt.svg

radial.svg : radial
	time ./radial > radial.svg

points.kml : makepoints neighborhoods.kml
	time ./makepoints > points.kml

shortest.kml : shortestpaths pactom.kml pac2.kml
	time ./shortestpaths > shortest.kml

llt.svg : lltsvg pactom.kml pac2.kml
	time ./lltsvg > llt.svg


# For release, we expect the following files in the current directory:
#   pac.kml
#   pac2.kml

release : release/pactom.kmz


# XXX also annotations, neighborhood, etc.
release/pactom.kmz : pac.kml pac2.kml kmlcat
	rm -f _pactom.kml
	./kmlcat pac.kml pac2.kml > _pactom.kml
	rm -f release/pactom.kmz
	zip release/pactom.kmz _pactom.kml


clean :
	rm -f _pactom.kml release/pactom.kmz *~
