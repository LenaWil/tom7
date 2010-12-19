
#ifndef __EXTENT_H
#define __EXTENT_H

/* provides 'auto'-style deallocation
   for pointers with 'destroy' method. */

template <class P>
struct extent {
  
  P * ptr;

  extent(P * p) : ptr(p) {}

  void release() { ptr = 0; }

  void replace(P * p) { ptr = p; }

  ~extent() { if (ptr) ptr->destroy(); }

};

/* for destructor */
template <class P>
struct extentd {
  
  P * ptr;

  extentd(P * p) : ptr(p) {}

  void release() { ptr = 0; }

  void replace(P * p) { ptr = p; }

  ~extentd() { if (ptr) delete ptr; }

};

/* for destructor, array of */
template <class P>
struct extentda {
  
  P * ptr;

  extentda(P * p) : ptr(p) {}

  void release() { ptr = 0; }

  void replace(P * p) { ptr = p; }

  ~extentda() { if (ptr) delete [] ptr; }

};

/* for call to 'free' */
template <class P>
struct extentf {
  P * ptr;
  extentf(P * p) : ptr(p) {}
  void release () { ptr = 0; }
  void replace(P * p) { ptr = p; }
  ~extentf() { if (ptr) free(ptr); }
};

#endif
