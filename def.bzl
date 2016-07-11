# golang repository prefix
def _go_prefix_impl(ctx):
	return struct(prefix = ctx.attr.prefix)

_go_prefix_rule = rule(
		_go_prefix_impl,
		attrs = {
				"prefix" : attr.string(mandatory = True)
				}
		)


def go_prefix(prefix):
	_go_prefix_rule(
			name = "go_prefix",
			prefix = prefix,
			visibility = ["//visibility:public"]
			)

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
_golang_attrs = {
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
		"go_prefix": attr.label(
				default = Label("//:go_prefix"),
				allow_files = False
				)
		}

def _go_env(ctx):
	return {
			"k8": {"GOOS": "linux",
					"GOARCH": "amd64"},
			"piii": {"GOOS": "linux",
						"GOARCH": "386"},
			"darwin": {"GOOS": "darwin",
							"GOARCH": "amd64"},
			"freebsd": {"GOOS": "freebsd",
							 "GOARCH": "amd64"},
			"armeabi-v7a": {"GOOS": "linux",
									 "GOARCH": "arm"},
			"arm": {"GOOS": "linux",
					 "GOARCH": "arm"}
			}.get(ctx.fragments.cpp.cpu, {"GOOS": "linux", "GOARCH": "amd64"});


# for testing purpose only, to make sure the go binary can be accessed.
def _test_go_impl(ctx):
	content = ctx.label.name + ctx.file.go_tool.path
	ctx.file_action(ctx.outputs.out, content)

shell_env = {
		"PATH" :"/usr/bin:/bin"
		}

test_go = rule(
		_test_go_impl,
		attrs =  _golang_attrs,
		outputs = {"out" : "%{name}.txt"}
		)


# Downads and install golang packages.
def _go_package_impl(ctx):
	if ctx.label.package != "":
		fail("golang package rule must be at root directory: %s" % ctx.label.package)
	remote = ctx.attr.remote
	# Removes trailing slash.
	if remote.endswith("/"):
		remote = remote[:remote.rfind("/") - 1]
	if not remote.endswith("/..."):
		remote = remote + "/..."
	cmds = [
			"echo %s > %s" % (ctx.attr.remote, ctx.outputs.out.path),
			"mkdir -p $(pwd)/external/golang_packages/src",
			"export GOPATH=$(pwd)/external/golang_packages",
			"%s get -d %s" % (ctx.file.go_tool.path, remote),
			];

	ctx.action(outputs = [ctx.outputs.out], command = " && ".join(cmds), env = _go_env(ctx) + shell_env)
	return struct(files = set([ctx.outputs.out]))

def _go_package_out(attr):
	remote = attr.remote
	# Removes the /... suffix if exists.
	if remote.endswith("/..."):
		remote = remote[:remote.rfind("/...") - 1]
	remote = "@" + "_".join(remote.split("/"))
	return {"out" : remote + ".marker"}

_go_package_rule = rule(
		_go_package_impl,
		attrs = _golang_attrs + {
				"remote": attr.string(mandatory = True),
				},
		outputs = _go_package_out,
		fragments = ["cpp"]
		);

def go_package(name, remote):
	_go_package_rule(
			name = name,
			remote = remote,
			visibility = ["//visibility:public"],
			)

# Builds and installs golang library.

def _go_library_impl(ctx):
	gc_flags = "'-I $(pwd)/external -I ./'"
	goos = _go_env(ctx)["GOOS"]
	goarch = _go_env(ctx)["GOARCH"]
	if len(ctx.files.srcs) == 0:
		fail("go source files must be provided")
	# verify all the source files must be under the same directory
	package_dir = ctx.files.srcs[0].dirname
	for f in ctx.files.srcs:
		if f.dirname != package_dir:
			fail("all source files must be under the same directory")

	prefix = ctx.attr.go_prefix.prefix
	if prefix == None:
		fail("go_prefix is not set")

	inputs = ctx.files.srcs
	for d in ctx.attr.deps:
		inputs += list(d.files)

	prefix_last= prefix[prefix.rfind("/") + 1:]
	prefix_all_but_last = prefix[:prefix.rfind("/")]
	go_pkg_dir = "$GOPATH/pkg/%s_%s" % (goos, goarch)
	short_path = ctx.outputs.out.short_path
	basename = ctx.outputs.out.basename
	short_path = short_path[:short_path.rfind(basename) - 1]
	installed_object_path = "/".join(
			[
					"$GOPATH/pkg",
					"%s_%s" %(goos, goarch),
					prefix,
					short_path + ".a"
					])

	cmd = " && ".join([
			"export GOROOT=$(pwd)/%s/.." % ctx.file.go_tool.dirname,
			"export GOPATH=$(pwd)/external/golang_packages",
			"mkdir -p $GOPATH/src/%s" % prefix_all_but_last,
			"ln -s $(pwd) $GOPATH/src/%s" % prefix,
			"mkdir -p $GOPATH/pkg",
			"%s install %s" % (ctx.file.go_tool.path, prefix + "/" + package_dir),
			"mv %s %s" % (installed_object_path, ctx.outputs.out.path),
			"ln -s $(pwd)/%s %s" % (ctx.outputs.out.path, installed_object_path)
			])
	ctx.action(
			inputs = inputs,
			outputs = [ctx.outputs.out],
			command = cmd,
			env = _go_env(ctx) + shell_env
			)
	return struct(files=set([ctx.outputs.out]))

go_library = rule(
		_go_library_impl,
		attrs = _golang_attrs + {
				"srcs" : attr.label_list(allow_files = True),
				"deps": attr.label_list(allow_files = True)
				},
		outputs =  {"out" : "%{name}.a"},
		fragments = ["cpp"]
		)
