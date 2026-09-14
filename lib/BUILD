load("@rules_cc//cc:defs.bzl", "cc_library", "cc_test")

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "math",
    srcs = ["math.cc"],
    hdrs = ["math.h"],
    copts = [
        "-Wall",
        "-Wextra",
        "-Werror",
    ],
)

cc_test(
    name = "math_test",
    srcs = ["math_test.cc"],
    deps = [
        ":math",
        "@com_google_googletest//:gtest_main",
    ],
)
