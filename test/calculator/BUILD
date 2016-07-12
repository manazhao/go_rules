package(
		default_visibility = ["//test:__subpackages__"],
		)

load("//:def.bzl","go_library", "go_test")

go_library(
		name = "default",
		srcs = ["sum.go"],
		deps = ["//:golang_protobuf"],
		)


go_test(
		name = "calculator_test",
		srcs = ["calculator_test.go"],
		deps = [":default"],
		)
