load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_library")

# Heavy computation library for cache benchmarking
cc_library(
    name = "compute_lib",
    srcs = [
        "compute_matrix.cc",
        "compute_sorting.cc",
        "compute_crypto.cc",
        "compute_encoding.cc",
        "compute_neural.cc",
    ],
    hdrs = ["heavy_compute.h"],
    copts = ["-std=c++17", "-fPIC"],
)

# Cache demonstration binary - shows remote cache benefits with heavy workload
cc_binary(
    name = "cache_demo",
    srcs = ["benchmark.cc"],
    deps = [":compute_lib"],
    copts = ["-std=c++17", "-O2"],
)
