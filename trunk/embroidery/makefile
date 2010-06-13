
all : pe-tosvg.exe

pe-tosvg.exe : pe-tosvg.cm pe-tosvg.sml ../sml-lib/files/reader*.sml ../sml-lib/files/embroidery/*.sml ../sml-lib/files/svg/*.sml ../sml-lib/files/xml/*.sml
	mlton -output $@ pe-tosvg.cm
