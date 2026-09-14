load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_library", "cc_test")

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "hello_lib",
    srcs = ["hello.cc"],
    hdrs = ["hello.h"],
    deps = ["//lib:math"],
    copts = [
        "-Wall",
        "-Wextra",
        "-Werror",
    ],
)

cc_binary(
    name = "hello",
    srcs = ["main.cc"],
    deps = [":hello_lib"],
)

cc_test(
    name = "hello_test",
    srcs = ["hello_test.cc"],
    deps = [
        ":hello_lib",
        "@com_google_googletest//:gtest_main",
    ],
)
