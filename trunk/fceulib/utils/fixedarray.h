// Templated array of fixed size.
#ifndef _FIXEDARRAY_H_
#define _FIXEDARRAY_H_

template<typename T, int N>
struct FixedArray {
  T data[N];
  FixedArray() {}
  explicit FixedArray(const T &value) {
    for (int i = 0; i < N; i++)
      data[i] = value;
  }
  T &operator[](int index) {
    return data[index]; 
  }
  const T &operator[](int index) const {
    return data[index];
  }
  static constexpr int size = N;
  bool operator!=(const FixedArray<T,N> &other) const { 
    return !operator==(other); 
  }
  bool operator==(const FixedArray<T,N> &other) const {
    for(int i=0;i<size;i++)
      if(data[i] != other[i])
	return false;
    return true;
  }
};

#endif

