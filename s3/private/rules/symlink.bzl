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

def _symlink_impl(ctx):
    lnk = ctx.actions.declare_file(ctx.attr.name)
    ctx.actions.symlink(output = lnk, target_file = ctx.file.target, is_executable = True)
    return [
        RemotePath(remote_path = ctx.attr.target[RemotePath].remote_path),
        DefaultInfo(
            files = depset([lnk]),
            executable = lnk,
        ),
    ]

symlink = rule(
    implementation = _symlink_impl,
    attrs = {
        "target": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "target",
            providers = [RemotePath],
        ),
    },
    executable = True,
)
