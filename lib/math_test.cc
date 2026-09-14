#include "lib/math.h"

#include <gtest/gtest.h>

namespace math {

TEST(MathTest, Add) {
  EXPECT_EQ(Add(2, 3), 5);
  EXPECT_EQ(Add(-1, 1), 0);
  EXPECT_EQ(Add(0, 0), 0);
}

TEST(MathTest, Subtract) {
  EXPECT_EQ(Subtract(5, 3), 2);
  EXPECT_EQ(Subtract(1, 1), 0);
  EXPECT_EQ(Subtract(-1, 1), -2);
}

TEST(MathTest, Multiply) {
  EXPECT_EQ(Multiply(2, 3), 6);
  EXPECT_EQ(Multiply(0, 100), 0);
  EXPECT_EQ(Multiply(-2, 3), -6);
}

TEST(MathTest, Divide) {
  EXPECT_EQ(Divide(6, 2), 3);
  EXPECT_EQ(Divide(10, 2), 5);
}

TEST(MathTest, DivideByZero) {
  EXPECT_THROW(Divide(10, 0), std::invalid_argument);
}

TEST(MathTest, Square) {
  EXPECT_DOUBLE_EQ(Square(2.0), 4.0);
  EXPECT_DOUBLE_EQ(Square(3.5), 12.25);
  EXPECT_DOUBLE_EQ(Square(0.0), 0.0);
}

TEST(MathTest, Sqrt) {
  EXPECT_DOUBLE_EQ(Sqrt(4.0), 2.0);
  EXPECT_DOUBLE_EQ(Sqrt(9.0), 3.0);
  EXPECT_DOUBLE_EQ(Sqrt(0.0), 0.0);
}

TEST(MathTest, SqrtNegative) {
  EXPECT_THROW(Sqrt(-1.0), std::invalid_argument);
}

}  // namespace math
