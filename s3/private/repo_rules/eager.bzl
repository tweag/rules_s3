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

load("//s3/private:util.bzl", "bucket_url", "deps_from_file", "have_unblocked_downloads")

def info_is_reproducible(info):
    """Check if download info has integrity information (sha256 or integrity)."""
    return "sha256" in info or "integrity" in info

def _eager_impl(repository_ctx):
    repository_ctx.report_progress("Downloading files from s3://{}".format(repository_ctx.attr.lockfile))
    deps = deps_from_file(repository_ctx, repository_ctx.attr.lockfile, repository_ctx.attr.lockfile_jsonpath)
    # start downloads
    waiters = []
    reproducible = True
    for local_path, info in deps.items():
        args = info_to_download_args(repository_ctx.attr, repository_ctx.attr.bucket, local_path, info)
        waiters.append(repository_ctx.download(**args))
        reproducible = reproducible and info_is_reproducible(info)

    # populate BUILD file
    repository_ctx.file("BUILD.bazel", "exports_files(glob([\"**\"]))")

    # wait for downloads to finish
    if have_unblocked_downloads():
        for waiter in waiters:
            waiter.wait()

    if hasattr(repository_ctx, "repo_metadata"):
        return repository_ctx.repo_metadata(reproducible = reproducible)
    return None

def info_to_download_args(attr, bucket_name, local_path, info):
    """Convert download info to repository_ctx.download arguments.

    Args:
        attr: Repository rule attributes.
        bucket_name: S3 bucket name.
        local_path: Local path for the downloaded file.
        info: Download information dict containing remote_path and optionally sha256/integrity.

    Returns:
        Dict of arguments for repository_ctx.download().
    """
    args = {
        "url": bucket_url(attr, bucket_name, info["remote_path"]),
        "output": local_path,
        "executable": True,
        "block": False,
    }
    if not have_unblocked_downloads():
        args.pop("block")
    if "sha256" in info:
        args["sha256"] = info["sha256"]
    if "integrity" in info:
        args["integrity"] = info["integrity"]
    return args

eager = repository_rule(
    implementation = _eager_impl,
    attrs = {
        "bucket": attr.string(),
        "endpoint": attr.string(default = "s3.amazonaws.com"),
        "endpoint_style": attr.string(values = ["virtual-hosted", "path"]),
        "lockfile": attr.label(
            doc = "Map of dependency files to load from the S3 bucket",
        ),
        "lockfile_jsonpath": attr.string(),
    },
)
