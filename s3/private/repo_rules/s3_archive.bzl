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

load("@bazel_tools//tools/build_defs/repo:utils.bzl", "patch")
load("//s3/private:util.bzl", "download_and_extract_args", "parse_s3_url", "workspace_and_buildfile")

def _s3_archive_impl(repository_ctx):
    s3_url = repository_ctx.attr.url
    target = parse_s3_url(s3_url)
    repository_ctx.report_progress("Fetching {}".format(s3_url))

    # download && extract the repo
    args = download_and_extract_args(repository_ctx.attr, target["bucket_name"], target["remote_path"])
    repository_ctx.download_and_extract(**args)

    # apply patches after extraction has finished
    patch(repository_ctx)

    # populate BUILD files
    workspace_and_buildfile(repository_ctx)

_s3_archive_doc = """Downloads a Bazel repository as a compressed archive file from an S3 bucket, decompresses it,
and makes its targets available for binding.

It supports the following file extensions: `"zip"`, `"jar"`, `"war"`, `"aar"`, `"tar"`,
`"tar.gz"`, `"tgz"`, `"tar.xz"`, `"txz"`, `"tar.zst"`, `"tzst"`, `tar.bz2`, `"ar"`,
or `"deb"`.

Examples:
  Suppose your code depends on a private library packaged as a `.tar.gz`
  which is available from s3://my_org_code/libmagic.tar.gz. This `.tar.gz` file
  contains the following directory structure:

  ```
 MODULE.bazel
  src/
    magic.cc
    magic.h
  ```

  In the local repository, the user creates a `magic.BUILD` file which
  contains the following target definition:

  ```starlark
  cc_library(
      name = "lib",
      srcs = ["src/magic.cc"],
      hdrs = ["src/magic.h"],
  )
  ```

  Targets in the main repository can depend on this target if the
  following lines are added to `MODULE.bazel`:

  ```starlark
  s3_archive = use_repo_rule("@rules_s3//s3:repo_rules.bzl", "s3_archive")

  s3_archive(
      name = "magic",
      url = "s3://my_org_code/libmagic.tar.gz",
      sha256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
      build_file = "@//:magic.BUILD",
  )
  ```

  Then targets would specify `@magic//:lib` as a dependency.
"""

_s3_archive_attrs = {
    "build_file": attr.label(
        allow_single_file = True,
        doc =
            "The file to use as the BUILD file for this repository." +
            "This attribute is an absolute label (use '@//' for the main " +
            "repo). The file does not need to be named BUILD, but can " +
            "be (something like BUILD.new-repo-name may work well for " +
            "distinguishing it from the repository's actual BUILD files. " +
            "Either build_file or build_file_content can be specified, but " +
            "not both.",
    ),
    "build_file_content": attr.string(
        doc =
            "The content for the BUILD file for this repository. " +
            "Either build_file or build_file_content can be specified, but " +
            "not both.",
    ),
    "patches": attr.label_list(
        default = [],
        doc =
            "A list of files that are to be applied as patches after " +
            "extracting the archive. By default, it uses the Bazel-native patch implementation " +
            "which doesn't support fuzz match and binary patch, but Bazel will fall back to use " +
            "patch command line tool if `patch_tool` attribute is specified or there are " +
            "arguments other than `-p` in `patch_args` attribute.",
    ),
    "remote_patches": attr.string_dict(
        default = {},
        doc =
            "A map of patch file URL to its integrity value, they are applied after extracting " +
            "the archive and before applying patch files from the `patches` attribute. " +
            "It uses the Bazel-native patch implementation, you can specify the patch strip " +
            "number with `remote_patch_strip`",
    ),
    "remote_patch_strip": attr.int(
        default = 0,
        doc =
            "The number of leading slashes to be stripped from the file name in the remote patches.",
    ),
    "patch_tool": attr.string(
        default = "",
        doc = "The patch(1) utility to use. If this is specified, Bazel will use the specified " +
              "patch tool instead of the Bazel-native patch implementation.",
    ),
    "patch_args": attr.string_list(
        default = [],
        doc =
            "The arguments given to the patch tool. Defaults to -p0 (see the `patch_strip` " +
            "attribute), however -p1 will usually be needed for patches generated by " +
            "git. If multiple -p arguments are specified, the last one will take effect." +
            "If arguments other than -p are specified, Bazel will fall back to use patch " +
            "command line tool instead of the Bazel-native patch implementation. When falling " +
            "back to patch command line tool and patch_tool attribute is not specified, " +
            "`patch` will be used. This only affects patch files in the `patches` attribute.",
    ),
    "patch_strip": attr.int(
        default = 0,
        doc = "When set to `N`, this is equivalent to inserting `-pN` to the beginning of `patch_args`.",
    ),
    "patch_cmds": attr.string_list(
        default = [],
        doc = "Sequence of Bash commands to be applied on Linux/Macos after patches are applied.",
    ),
    "patch_cmds_win": attr.string_list(
        default = [],
        doc = "Sequence of Powershell commands to be applied on Windows after patches are " +
              "applied. If this attribute is not set, patch_cmds will be executed on Windows, " +
              "which requires Bash binary to exist.",
    ),
    "rename_files": attr.string_dict(
        doc =
            "An optional dict specifying files to rename during the extraction. " +
            "Archive entries with names exactly matching a key will be renamed to " +
            "the value, prior to any directory prefix adjustment. This can be used " +
            "to extract archives that contain non-Unicode filenames, or which have " +
            "files that would extract to the same path on case-insensitive filesystems.",
    ),
    "canonical_id": attr.string(
        doc = """A canonical ID of the file downloaded.

If specified and non-empty, Bazel will not take the file from cache, unless it
was added to the cache by a request with the same canonical ID.

If unspecified or empty, Bazel by default uses the URLs of the file as the
canonical ID. This helps catch the common mistake of updating the URLs without
also updating the hash, resulting in builds that succeed locally but fail on
machines without the file in the cache.
""",
    ),
    "integrity": attr.string(
        doc = """Expected checksum in Subresource Integrity format of the file downloaded.

This must match the checksum of the file downloaded. It is a security risk
to omit the checksum as remote files can change. At best omitting this
field will make your build non-hermetic. It is optional to make development
easier but either this attribute or `sha256` should be set before shipping.""",
    ),
    "sha256": attr.string(
        doc = """The expected SHA-256 of the file downloaded.

This must match the SHA-256 of the file downloaded. It is a security risk
to omit the SHA-256 as remote files can change. At best omitting this
field will make your build non-hermetic. It is optional to make development
easier but either this attribute or `integrity` should be set before shipping.""",
    ),
    "strip_prefix": attr.string(
        doc = """A directory prefix to strip from the extracted files.

Many archives contain a top-level directory that contains all of the useful
files in archive. Instead of needing to specify this prefix over and over
in the `build_file`, this field can be used to strip it from all of the
extracted files.

For example, suppose you are using `foo-lib-latest.zip`, which contains the
directory `foo-lib-1.2.3/` under which there is a `WORKSPACE` file and are
`src/`, `lib/`, and `test/` directories that contain the actual code you
wish to build. Specify `strip_prefix = "foo-lib-1.2.3"` to use the
`foo-lib-1.2.3` directory as your top-level directory.

Note that if there are files outside of this directory, they will be
discarded and inaccessible (e.g., a top-level license file). This includes
files/directories that start with the prefix but are not in the directory
(e.g., `foo-lib-1.2.3.release-notes`). If the specified prefix does not
match a directory in the archive, Bazel will return an error.""",
    ),
    "type": attr.string(
        doc = """The archive type of the downloaded file.

By default, the archive type is determined from the file extension of the
URL. If the file has no extension, you can explicitly specify one of the
following: `"zip"`, `"jar"`, `"war"`, `"aar"`, `"tar"`, `"tar.gz"`, `"tgz"`,
`"tar.xz"`, `"txz"`, `"tar.zst"`, `"tzst"`, `"tar.bz2"`, `"ar"`, or `"deb"`.""",
    ),
    "url": attr.string(
        mandatory = True,
        doc = "A URL to a file that will be made available to Bazel.\nThis must be a 's3://' URL.",
    ),
    "endpoint": attr.string(
        default = "s3.amazonaws.com",
        doc = """Optional S3 endpoint (for AWS regional endpoint or S3-compatible object storage).
If not set, the AWS S3 global endpoint "s3.amazonaws.com" is used.

Examples: AWS regional endpoint (`s3.<region-code>.amazonaws.com`): `"s3.us-west-2.amazonaws.com"`, Cloudflare R2 endpoint (`<accountid>.r2.cloudflarestorage.com`): `"12345.r2.cloudflarestorage.com"`.
""",
    ),
    "endpoint_style": attr.string(
        values = ["virtual-hosted", "path"],
        doc = """Optional URL style to be used.
AWS strongly recommends virtual-hosted-style, where the request is encoded as follows:
    https://bucket-name.s3.region-code.amazonaws.com/key-name

Path-style URLs on the other hand include the bucket name as part of the URL path:
    https://s3.region-code.amazonaws.com/bucket-name/key-name

S3-compatible object storage varies in the supported styles, but the path-style is more common.
If unset, a default style is chosen based on the endpoint: "*.amazonaws.com": virtual-hosted, "*.r2.cloudflarestorage.com": path, generic: path.
""",
    ),
}

s3_archive = repository_rule(
    implementation = _s3_archive_impl,
    attrs = _s3_archive_attrs,
    doc = _s3_archive_doc,
)
