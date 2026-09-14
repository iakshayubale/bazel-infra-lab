#include "lib/math.h"

#include <cmath>
#include <stdexcept>

namespace math {

int Add(int a, int b) {
  return a + b;
}

int Subtract(int a, int b) {
  return a - b;
}

int Multiply(int a, int b) {
  return a * b;
}

int Divide(int a, int b) {
  if (b == 0) {
    throw std::invalid_argument("Division by zero");
  }
  return a / b;
}

double Square(double x) {
  return x * x;
}

double Sqrt(double x) {
  if (x < 0) {
    throw std::invalid_argument("Cannot take square root of negative number");
  }
  return std::sqrt(x);
}

}  // namespace math
