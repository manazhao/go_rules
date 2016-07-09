# get golang archives.

GOLANG_BUILD_CONTENT = """
package(
	default_visibility = [ "//visibility:public" ]
)

filegroup(
	name = "toolchain",
	srcs = glob(["go/bin/*", "go/pkg/**", ]),
)

filegroup(
	name = "go_tool",
	srcs = [ "go/bin/go" ],
)

filegroup(
	name = "go_include",
	srcs = [ "go/pkg/include" ],
)
"""
def golang_repositories():
  native.new_http_archive(
	  name=  "golang_linux_amd64",
	  url = "https://storage.googleapis.com/golang/go1.6.2.linux-amd64.tar.gz",
	  build_file_content = GOLANG_BUILD_CONTENT,
	  sha256 = "e40c36ae71756198478624ed1bb4ce17597b3c19d243f3f0899bb5740d56212a"
	  )

  native.new_http_archive(
	  name=  "golang_darwin_amd64",
	  url = "https://storage.googleapis.com/golang/go1.6.2.darwin-amd64.tar.gz",
	  build_file_content = GOLANG_BUILD_CONTENT,
	  sha256 = "6ebbafcac53bbbf8c4105fa84b63cca3d6ce04370f5a04ac2ac065782397fc26"
	)

# golang tools.
_go_env_attrs = {
	"toolchain": attr.label(
		default = Label("//:toolchain"),
		allow_files = True,
		cfg = HOST_CFG,
		),
	"go_tool": attr.label(
		default = Label("//:go_tool"),
		single_file = True,
		allow_files = True,
		cfg = HOST_CFG,
		),
	"go_include": attr.label(
		default = Label("//:go_include"),
		single_file = True,
		allow_files = True,
		cfg = HOST_CFG,
		),
	}


def _test_go_impl(ctx):
  content = ctx.label.name + ctx.file.go_tool.path
  ctx.file_action(ctx.outputs.out, content)


test_go = rule(
  _test_go_impl,
  attrs =  _go_env_attrs,
  outputs = {"out" : "%{name}.txt"}
  )
