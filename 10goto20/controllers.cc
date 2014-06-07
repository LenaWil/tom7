
#include "10goto20.h"
#include "controllers.h"

void Controllers::Reserve(int s) {
  // check-fail?
  if (s <= size)
    return;

  if (s < capacity) {
    size = s;
  } else {
    int cap = (int)capacity;
    if (!cap) cap = 1;
    while (cap < s)
      cap <<= 1;
    
    // Never need more than 255.
    if (cap > 255) cap = 255;
    
    char *ntypes = (char*)malloc(cap);
    double *nvalues = (double*)malloc(sizeof (double) * cap);
    for (int i = 0; i < size; i++) {
      ntypes[i] = types[i];
      nvalues[i] = values[i];
    }
    for (int i = size; i < cap; i++) {
      ntypes[i] = INVALID_CONTROLLER;
      nvalues[i] = 0.0;
    }

    free(types);
    free(values);
    types = ntypes;
    values = nvalues;
  }
}

void Controllers::Set(Controller c, double v) {
  for (int i = 0; i < size; i++) {
    if (types[i] == (char)c) {
      values[i] = v;
      return;
    }
  }

  // Add it.
  int idx = size;
  Reserve(size + 1);

  types[idx] = c;
  values[idx] = v;
}

bool Controllers::Get(Controller c, double *v) {
  for (int i = 0; i < size; i++) {
    if (types[i] == (char)c) {
      *v = values[i];
      return true;
    }
  }
  return false;
}

double Controllers::GetRequired(Controller c) {
  for (int i = 0; i < size; i++)
    if (types[i] == (char)c)
      return values[i];

  CHECK(!"The required controller was not found.");
  return 0.0;
}

Controllers::Controllers(const Controllers &rhs)
  : size(rhs.size), capacity(rhs.capacity) {
  types = (char*)malloc(capacity);
  values = (double*)malloc(sizeof (double) * capacity);
  for (int i = 0; i < size; i++) {
    types[i] = rhs.types[i];
    values[i] = rhs.values[i];
  }
}

Controllers &Controllers::operator =(const Controllers &rhs) {
  if (this == &rhs)
    return *this;

  free(types);
  free(values);
  size = rhs.size;
  capacity = rhs.capacity;
  types = (char*)malloc(capacity);
  values = (double*)malloc(sizeof (double) * capacity);
  for (int i = 0; i < size; i++) {
    types[i] = rhs.types[i];
    values[i] = rhs.values[i];
  }
  return *this;
}
