#include "app/hello.h"

#include <gtest/gtest.h>

TEST(HelloTest, PrintHello) {
  // This is a basic test - in real code you'd capture output
  EXPECT_NO_THROW(PrintHello());
}

TEST(HelloTest, PrintMathOperations) {
  EXPECT_NO_THROW(PrintMathOperations());
}
