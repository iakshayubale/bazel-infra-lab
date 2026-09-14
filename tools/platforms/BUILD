# Platform definitions for remote build execution

package(default_visibility = ["//visibility:public"])

# Linux with GCC
platform(
    name = "linux_gcc",
    constraint_values = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
        "//tools/platforms:gcc",
    ],
)

# Linux with Clang
platform(
    name = "linux_clang",
    constraint_values = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
        "//tools/platforms:clang",
    ],
)

# Linux ARM64 with GCC
platform(
    name = "linux_arm64_gcc",
    constraint_values = [
        "@platforms//os:linux",
        "@platforms//cpu:aarch64",
        "//tools/platforms:gcc",
    ],
)

# Compiler constraints
constraint_setting(name = "compiler")

constraint_value(
    name = "gcc",
    constraint_setting = ":compiler",
)

constraint_value(
    name = "clang",
    constraint_setting = ":compiler",
)
