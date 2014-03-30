
default : topstreets.exe mergestreets.exe filterosm.exe

MLTON=/c/mlton/bin/mlton.bat -target x86_64-w64-mingw32 -codegen amd64

topstreets.exe : topstreets.cm topstreets.sml
	$(MLTON) -output $@ topstreets.cm

mergestreets.exe : mergestreets.cm mergestreets.sml
	$(MLTON) -output $@ mergestreets.cm

filterosm.exe : filterosm.cm filterosm.sml
	$(MLTON) -output $@ filterosm.cm


statecounts : alabama-counts.txt alaska-counts.txt arizona-counts.txt arkansas-counts.txt california-counts.txt colorado-counts.txt connecticut-counts.txt delaware-counts.txt district-of-columbia-counts.txt florida-counts.txt georgia-counts.txt hawaii-counts.txt idaho-counts.txt illinois-counts.txt indiana-counts.txt iowa-counts.txt kansas-counts.txt kentucky-counts.txt louisiana-counts.txt maine-counts.txt maryland-counts.txt massachusetts-counts.txt michigan-counts.txt minnesota-counts.txt mississippi-counts.txt missouri-counts.txt montana-counts.txt nebraska-counts.txt nevada-counts.txt new-hampshire-counts.txt new-jersey-counts.txt new-mexico-counts.txt new-york-counts.txt north-carolina-counts.txt north-dakota-counts.txt ohio-counts.txt oklahoma-counts.txt oregon-counts.txt pennsylvania-counts.txt rhode-island-counts.txt south-carolina-counts.txt south-dakota-counts.txt tennessee-counts.txt texas-counts.txt utah-counts.txt vermont-counts.txt virginia-counts.txt washington-counts.txt west-virginia-counts.txt wisconsin-counts.txt wyoming-counts.txt

merged.txt : statecounts mergestreets.exe
	./mergestreets.exe alabama-counts.txt alaska-counts.txt arizona-counts.txt arkansas-counts.txt california-counts.txt colorado-counts.txt connecticut-counts.txt delaware-counts.txt district-of-columbia-counts.txt florida-counts.txt georgia-counts.txt hawaii-counts.txt idaho-counts.txt illinois-counts.txt indiana-counts.txt iowa-counts.txt kansas-counts.txt kentucky-counts.txt louisiana-counts.txt maine-counts.txt maryland-counts.txt massachusetts-counts.txt michigan-counts.txt minnesota-counts.txt mississippi-counts.txt missouri-counts.txt montana-counts.txt nebraska-counts.txt nevada-counts.txt new-hampshire-counts.txt new-jersey-counts.txt new-mexico-counts.txt new-york-counts.txt north-carolina-counts.txt north-dakota-counts.txt ohio-counts.txt oklahoma-counts.txt oregon-counts.txt pennsylvania-counts.txt rhode-island-counts.txt south-carolina-counts.txt south-dakota-counts.txt tennessee-counts.txt texas-counts.txt utah-counts.txt vermont-counts.txt virginia-counts.txt washington-counts.txt west-virginia-counts.txt wisconsin-counts.txt wyoming-counts.txt

sorted.txt : merged.txt
	/bin/sort -n merged.txt > $@

alaska-counts.txt : alaska-latest.osm topstreets.exe
	time ./topstreets.exe alaska

alabama-counts.txt : alabama-latest.osm topstreets.exe
	time ./topstreets.exe alabama

arizona-counts.txt : arizona-latest.osm topstreets.exe
	time ./topstreets.exe arizona

arkansas-counts.txt : arkansas-latest.osm topstreets.exe
	time ./topstreets.exe arkansas

california-counts.txt : california-latest.osm topstreets.exe
	time ./topstreets.exe california

colorado-counts.txt : colorado-latest.osm topstreets.exe
	time ./topstreets.exe colorado

connecticut-counts.txt : connecticut-latest.osm topstreets.exe
	time ./topstreets.exe connecticut

delaware-counts.txt : delaware-latest.osm topstreets.exe
	time ./topstreets.exe delaware

district-of-columbia-counts.txt : district-of-columbia-latest.osm topstreets.exe
	time ./topstreets.exe district-of-columbia

florida-counts.txt : florida-latest.osm topstreets.exe
	time ./topstreets.exe florida

georgia-counts.txt : georgia-latest.osm topstreets.exe
	time ./topstreets.exe georgia

hawaii-counts.txt : hawaii-latest.osm topstreets.exe
	time ./topstreets.exe hawaii

idaho-counts.txt : idaho-latest.osm topstreets.exe
	time ./topstreets.exe idaho

illinois-counts.txt : illinois-latest.osm topstreets.exe
	time ./topstreets.exe illinois

indiana-counts.txt : indiana-latest.osm topstreets.exe
	time ./topstreets.exe indiana

iowa-counts.txt : iowa-latest.osm topstreets.exe
	time ./topstreets.exe iowa

kansas-counts.txt : kansas-latest.osm topstreets.exe
	time ./topstreets.exe kansas

kentucky-counts.txt : kentucky-latest.osm topstreets.exe
	time ./topstreets.exe kentucky

louisiana-counts.txt : louisiana-latest.osm topstreets.exe
	time ./topstreets.exe louisiana

maine-counts.txt : maine-latest.osm topstreets.exe
	time ./topstreets.exe maine

maryland-counts.txt : maryland-latest.osm topstreets.exe
	time ./topstreets.exe maryland

massachusetts-counts.txt : massachusetts-latest.osm topstreets.exe
	time ./topstreets.exe massachusetts

michigan-counts.txt : michigan-latest.osm topstreets.exe
	time ./topstreets.exe michigan

minnesota-counts.txt : minnesota-latest.osm topstreets.exe
	time ./topstreets.exe minnesota

mississippi-counts.txt : mississippi-latest.osm topstreets.exe
	time ./topstreets.exe mississippi

missouri-counts.txt : missouri-latest.osm topstreets.exe
	time ./topstreets.exe missouri

montana-counts.txt : montana-latest.osm topstreets.exe
	time ./topstreets.exe montana

nebraska-counts.txt : nebraska-latest.osm topstreets.exe
	time ./topstreets.exe nebraska

nevada-counts.txt : nevada-latest.osm topstreets.exe
	time ./topstreets.exe nevada

new-hampshire-counts.txt : new-hampshire-latest.osm topstreets.exe
	time ./topstreets.exe new-hampshire

new-jersey-counts.txt : new-jersey-latest.osm topstreets.exe
	time ./topstreets.exe new-jersey

new-mexico-counts.txt : new-mexico-latest.osm topstreets.exe
	time ./topstreets.exe new-mexico

new-york-counts.txt : new-york-latest.osm topstreets.exe
	time ./topstreets.exe new-york

north-carolina-counts.txt : north-carolina-latest.osm topstreets.exe
	time ./topstreets.exe north-carolina

north-dakota-counts.txt : north-dakota-latest.osm topstreets.exe
	time ./topstreets.exe north-dakota

ohio-counts.txt : ohio-latest.osm topstreets.exe
	time ./topstreets.exe ohio

oklahoma-counts.txt : oklahoma-latest.osm topstreets.exe
	time ./topstreets.exe oklahoma

oregon-counts.txt : oregon-latest.osm topstreets.exe
	time ./topstreets.exe oregon

pennsylvania-counts.txt : pennsylvania-latest.osm topstreets.exe
	time ./topstreets.exe pennsylvania

rhode-island-counts.txt : rhode-island-latest.osm topstreets.exe
	time ./topstreets.exe rhode-island

south-carolina-counts.txt : south-carolina-latest.osm topstreets.exe
	time ./topstreets.exe south-carolina

south-dakota-counts.txt : south-dakota-latest.osm topstreets.exe
	time ./topstreets.exe south-dakota

tennessee-counts.txt : tennessee-latest.osm topstreets.exe
	time ./topstreets.exe tennessee

texas-counts.txt : texas-latest.osm topstreets.exe
	time ./topstreets.exe texas

utah-counts.txt : utah-latest.osm topstreets.exe
	time ./topstreets.exe utah

vermont-counts.txt : vermont-latest.osm topstreets.exe
	time ./topstreets.exe vermont

virginia-counts.txt : virginia-latest.osm topstreets.exe
	time ./topstreets.exe virginia

washington-counts.txt : washington-latest.osm topstreets.exe
	time ./topstreets.exe washington

west-virginia-counts.txt : west-virginia-latest.osm topstreets.exe
	time ./topstreets.exe west-virginia

wisconsin-counts.txt : wisconsin-latest.osm topstreets.exe
	time ./topstreets.exe wisconsin

wyoming-counts.txt : wyoming-latest.osm topstreets.exe
	time ./topstreets.exe wyoming
