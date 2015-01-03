#ifndef __FDS_H
#define __FDS_H

class FceuFile;

void FCEU_FDSInsert();
void FCEU_FDSSelect();

int FDSLoad(const char *name, FceuFile *fp);

#endif
