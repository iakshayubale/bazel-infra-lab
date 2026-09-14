#include "app/hello.h"

#include <iostream>

void PrintHello() {
  std::cout << "Hello from Bazel Remote Build Example!!!" << std::endl;
}

void PrintMathOperations() {
  std::cout << "\nMath Operations:" << std::endl;
  std::cout << "  2 + 3 = " << math::Add(2, 3) << std::endl;
  std::cout << "  10 - 4 = " << math::Subtract(10, 4) << std::endl;
  std::cout << "  6 * 7 = " << math::Multiply(6, 7) << std::endl;
  std::cout << "  20 / 4 = " << math::Divide(20, 4) << std::endl;
}
