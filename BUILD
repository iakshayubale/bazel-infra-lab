# Root BUILD file - project metadata
load("@bazel_skylib//rules:common_settings.bzl", "string_flag")

string_flag(
    name = "build_variant",
    build_setting_default = "release",
)

config_setting(
    name = "release_mode",
    flag_values = {":build_variant": "release"},
)

config_setting(
    name = "debug_mode",
    flag_values = {":build_variant": "debug"},
)
