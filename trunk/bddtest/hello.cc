
struct A {
  A() {
    for(;;);
  }
};

int main () {
  A *a = new A;
  return 0;
}
