
default : wikiplia


wikiplia : *.sml wikiplia.cm raw-network.c
	mlton -default-ann 'allowFFI true' wikiplia.cm raw-network.c
