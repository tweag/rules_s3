"""
Copyright 2024 IMAX Corporation
Copyright 2024 Modus Create LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""

load("//s3/private:providers.bzl", "RemotePath")

# TODO: support Windows

def _copy_impl(ctx):
    out = ctx.actions.declare_file(ctx.attr.name)
    ctx.actions.run_shell(
        inputs = [ctx.file.src],
        outputs = [out],
        command = "cp -f \"$1\" \"$2\"",
        arguments = [ctx.file.src.path, out.path],
        progress_message = "Copying s3 file {}".format(ctx.attr.name),
        use_default_shell_env = True,
    )
    return [
        RemotePath(remote_path = ctx.attr.src[RemotePath].remote_path),
        DefaultInfo(
            files = depset([out]),
            runfiles = ctx.runfiles(files = [out]),
            executable = out,
        ),
    ]

copy = rule(
    implementation = _copy_impl,
    attrs = {
        "src": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "target",
            providers = [RemotePath],
        ),
    },
    executable = True,
)
