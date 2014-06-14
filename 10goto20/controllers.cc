
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
    size = s;
    capacity = cap;
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

bool Controllers::Get(Controller c, double *v) const {
  for (int i = 0; i < size; i++) {
    if (types[i] == (char)c) {
      *v = values[i];
      return true;
    }
  }
  return false;
}

double Controllers::GetRequired(Controller c) const {
  for (int i = 0; i < size; i++)
    if (types[i] == (char)c)
      return values[i];

  for (int i = 0; i < size; i++) {
    fprintf(stderr, "%d: %d = %f\n", i, types[i], values[i]);
  }
  CHECK(!"The required controller was not found.");
  return 0.0;
}

Controllers::Controllers(const Controllers &rhs)
  : size(rhs.size), capacity(rhs.capacity) {
  types = (char*)malloc(capacity);
  values = (double*)malloc(sizeof (double) * capacity);
  for (int i = 0; i < capacity; i++) {
    types[i] = rhs.types[i];
    values[i] = rhs.values[i];
    // printf("%d %f\n", i, values[i]);
  }
  // printf("Controllers copy %d--%d\n", size, capacity);
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
  // printf("Controllers =\n");
}
#if 0
Controllers::Controllers(Controllers &&rhs) {
  this->size = rhs.size;
  this->capacity = rhs.capacity;
  this->types = rhs.types;
  this->values = rhs.values;
  rhs.size = 0;
  rhs.capacity = 0;
  rhs.types = NULL;
  rhs.values = NULL;
  printf("Controllers &&\n");
}

Controllers &Controllers::operator =(Controllers &&rhs) {
  // Is this impossible? How can the rhs be a temporary?
  if (this == &rhs)
    return *this;

  free(this->types);
  free(this->values);
  this->size = rhs.size;
  this->capacity = rhs.capacity;
  this->types = rhs.types;
  this->values = rhs.values;
  rhs.size = 0;
  rhs.capacity = 0;
  rhs.types = NULL;
  rhs.values = NULL;
  return *this;
  printf("Controllers =&&\n");
}
#endif

Controllers::~Controllers() {
  free(types);
  free(values);
}
