# rules_s3

Bazel rules for downloading files from [Amazon Simple Storage Service (S3)][s3] and S3-compatible object storage.

## Features

- Can be used as a drop-in replacement for `http_file` (`s3_file`) and `http_archive` (`s3_archive`)
- Can fetch large amounts of objects lazily from a bucket using the `s3_bucket` module extension
- Supports fetching from private buckets using a credential helper
- Uses Bazel's downloader and the repository cache
- No dependencies like the AWS cli (`aws`) need to be installed

## Installation

You can find the latest version of [`rules_s3` on the Bazel Central Registry][bcr]. Installation works by adding a `bazel_dep` line to `MODULE.bazel`.

```starlark
bazel_dep(name = "rules_s3", version = "1.0.1")
```

Additionally, you need to configure a credential helper for the S3 endpoint of your choice. In theory, you can use any credential helper that can generate [request header signatures for S3][s3-signature].
In practice, the recommended credential helper is [`tweag-credential-helper`][tweag-credential-helper]. The project README will guide you through the required setup. An example is also provided [here](/examples/full).

## Usage

`rules_s3` offers two repository rules [`s3_file`](#s3_file) and [`s3_archive`](#s3_archive) for fetching individual objects.
If you need to download multiple objects from a bucket, use the [`s3_bucket`](#s3_bucket) module extension instead.

To see how it all comes together, take a look at the [full example][example].

<a id="s3_archive"></a>

## s3_archive

<pre>
load("@rules_s3//s3:repo_rules.bzl", "s3_archive")

s3_archive(<a href="#s3_archive-name">name</a>, <a href="#s3_archive-build_file">build_file</a>, <a href="#s3_archive-build_file_content">build_file_content</a>, <a href="#s3_archive-canonical_id">canonical_id</a>, <a href="#s3_archive-integrity">integrity</a>, <a href="#s3_archive-patch_strip">patch_strip</a>, <a href="#s3_archive-patches">patches</a>,
            <a href="#s3_archive-rename_files">rename_files</a>, <a href="#s3_archive-repo_mapping">repo_mapping</a>, <a href="#s3_archive-sha256">sha256</a>, <a href="#s3_archive-strip_prefix">strip_prefix</a>, <a href="#s3_archive-type">type</a>, <a href="#s3_archive-url">url</a>)
</pre>

Downloads a Bazel repository as a compressed archive file from an S3 bucket, decompresses it,
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

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="s3_archive-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="s3_archive-build_file"></a>build_file |  The file to use as the BUILD file for this repository.This attribute is an absolute label (use '@//' for the main repo). The file does not need to be named BUILD, but can be (something like BUILD.new-repo-name may work well for distinguishing it from the repository's actual BUILD files. Either build_file or build_file_content can be specified, but not both.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="s3_archive-build_file_content"></a>build_file_content |  The content for the BUILD file for this repository. Either build_file or build_file_content can be specified, but not both.   | String | optional |  `""`  |
| <a id="s3_archive-canonical_id"></a>canonical_id |  A canonical ID of the file downloaded.<br><br>If specified and non-empty, Bazel will not take the file from cache, unless it was added to the cache by a request with the same canonical ID.<br><br>If unspecified or empty, Bazel by default uses the URLs of the file as the canonical ID. This helps catch the common mistake of updating the URLs without also updating the hash, resulting in builds that succeed locally but fail on machines without the file in the cache.   | String | optional |  `""`  |
| <a id="s3_archive-integrity"></a>integrity |  Expected checksum in Subresource Integrity format of the file downloaded.<br><br>This must match the checksum of the file downloaded. It is a security risk to omit the checksum as remote files can change. At best omitting this field will make your build non-hermetic. It is optional to make development easier but either this attribute or `sha256` should be set before shipping.   | String | optional |  `""`  |
| <a id="s3_archive-patch_strip"></a>patch_strip |  Strip the specified number of leading components from file names.   | Integer | optional |  `0`  |
| <a id="s3_archive-patches"></a>patches |  A list of files that are to be applied as patches after extracting the archive. It uses the Bazel-native patch implementation which doesn't support fuzz match and binary patch.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="s3_archive-rename_files"></a>rename_files |  An optional dict specifying files to rename during the extraction. Archive entries with names exactly matching a key will be renamed to the value, prior to any directory prefix adjustment. This can be used to extract archives that contain non-Unicode filenames, or which have files that would extract to the same path on case-insensitive filesystems.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="s3_archive-repo_mapping"></a>repo_mapping |  In `WORKSPACE` context only: a dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.<br><br>For example, an entry `"@foo": "@bar"` declares that, for any time this repository depends on `@foo` (such as a dependency on `@foo//some:target`, it should actually resolve that dependency within globally-declared `@bar` (`@bar//some:target`).<br><br>This attribute is _not_ supported in `MODULE.bazel` context (when invoking a repository rule inside a module extension's implementation function).   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  |
| <a id="s3_archive-sha256"></a>sha256 |  The expected SHA-256 of the file downloaded.<br><br>This must match the SHA-256 of the file downloaded. It is a security risk to omit the SHA-256 as remote files can change. At best omitting this field will make your build non-hermetic. It is optional to make development easier but either this attribute or `integrity` should be set before shipping.   | String | optional |  `""`  |
| <a id="s3_archive-strip_prefix"></a>strip_prefix |  A directory prefix to strip from the extracted files.<br><br>Many archives contain a top-level directory that contains all of the useful files in archive. Instead of needing to specify this prefix over and over in the `build_file`, this field can be used to strip it from all of the extracted files.<br><br>For example, suppose you are using `foo-lib-latest.zip`, which contains the directory `foo-lib-1.2.3/` under which there is a `WORKSPACE` file and are `src/`, `lib/`, and `test/` directories that contain the actual code you wish to build. Specify `strip_prefix = "foo-lib-1.2.3"` to use the `foo-lib-1.2.3` directory as your top-level directory.<br><br>Note that if there are files outside of this directory, they will be discarded and inaccessible (e.g., a top-level license file). This includes files/directories that start with the prefix but are not in the directory (e.g., `foo-lib-1.2.3.release-notes`). If the specified prefix does not match a directory in the archive, Bazel will return an error.   | String | optional |  `""`  |
| <a id="s3_archive-type"></a>type |  The archive type of the downloaded file.<br><br>By default, the archive type is determined from the file extension of the URL. If the file has no extension, you can explicitly specify one of the following: `"zip"`, `"jar"`, `"war"`, `"aar"`, `"tar"`, `"tar.gz"`, `"tgz"`, `"tar.xz"`, `"txz"`, `"tar.zst"`, `"tzst"`, `"tar.bz2"`, `"ar"`, or `"deb"`.   | String | optional |  `""`  |
| <a id="s3_archive-url"></a>url |  A URL to a file that will be made available to Bazel. This must be a 's3://' URL.   | String | required |  |


<a id="s3_file"></a>

## s3_file

<pre>
load("@rules_s3//s3:repo_rules.bzl", "s3_file")

s3_file(<a href="#s3_file-name">name</a>, <a href="#s3_file-canonical_id">canonical_id</a>, <a href="#s3_file-downloaded_file_path">downloaded_file_path</a>, <a href="#s3_file-executable">executable</a>, <a href="#s3_file-integrity">integrity</a>, <a href="#s3_file-repo_mapping">repo_mapping</a>, <a href="#s3_file-sha256">sha256</a>, <a href="#s3_file-url">url</a>)
</pre>

Downloads a file from an S3 bucket and makes it available to be used as a file group.

Examples:
  Suppose you need to have a large file that is read during a test and is stored in a private bucket.
  This file is available from s3://my_org_assets/testdata.bin.
  Then you can add to your MODULE.bazel file:

  ```starlark
  s3_file = use_repo_rule("@rules_s3//s3:repo_rules.bzl", "s3_file")

  s3_file(
      name = "my_testdata",
      url = "s3://my_org_assets/testdata.bin",
      sha256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  )
  ```

  Targets would specify `@my_testdata//file` as a dependency to depend on this file.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="s3_file-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="s3_file-canonical_id"></a>canonical_id |  A canonical ID of the file downloaded.<br><br>If specified and non-empty, Bazel will not take the file from cache, unless it was added to the cache by a request with the same canonical ID.<br><br>If unspecified or empty, Bazel by default uses the URLs of the file as the canonical ID. This helps catch the common mistake of updating the URLs without also updating the hash, resulting in builds that succeed locally but fail on machines without the file in the cache.   | String | optional |  `""`  |
| <a id="s3_file-downloaded_file_path"></a>downloaded_file_path |  Optional output path for the downloaded file. The remote path from the URL is used as a fallback.   | String | optional |  `""`  |
| <a id="s3_file-executable"></a>executable |  If the downloaded file should be made executable.   | Boolean | optional |  `False`  |
| <a id="s3_file-integrity"></a>integrity |  Expected checksum in Subresource Integrity format of the file downloaded.<br><br>This must match the checksum of the file downloaded. It is a security risk to omit the checksum as remote files can change. At best omitting this field will make your build non-hermetic. It is optional to make development easier but either this attribute or `sha256` should be set before shipping.   | String | optional |  `""`  |
| <a id="s3_file-repo_mapping"></a>repo_mapping |  In `WORKSPACE` context only: a dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.<br><br>For example, an entry `"@foo": "@bar"` declares that, for any time this repository depends on `@foo` (such as a dependency on `@foo//some:target`, it should actually resolve that dependency within globally-declared `@bar` (`@bar//some:target`).<br><br>This attribute is _not_ supported in `MODULE.bazel` context (when invoking a repository rule inside a module extension's implementation function).   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  |
| <a id="s3_file-sha256"></a>sha256 |  The expected SHA-256 of the file downloaded.<br><br>This must match the SHA-256 of the file downloaded. _It is a security risk to omit the SHA-256 as remote files can change._ At best omitting this field will make your build non-hermetic. It is optional to make development easier but should be set before shipping.   | String | optional |  `""`  |
| <a id="s3_file-url"></a>url |  A URL to a file that will be made available to Bazel. This must be a 's3://' URL.   | String | required |  |

<a id="s3_bucket"></a>

## s3_bucket

<pre>
s3_bucket = use_extension("@rules_s3//s3:extensions.bzl", "s3_bucket")
s3_bucket.from_file(<a href="#s3_bucket.from_file-name">name</a>, <a href="#s3_bucket.from_file-bucket">bucket</a>, <a href="#s3_bucket.from_file-dev_dependency">dev_dependency</a>, <a href="#s3_bucket.from_file-lockfile">lockfile</a>, <a href="#s3_bucket.from_file-lockfile_jsonpath">lockfile_jsonpath</a>, <a href="#s3_bucket.from_file-method">method</a>)
</pre>

Downloads a collection of objects from an S3 bucket and makes them available under a single hub repository name.

Examples:
  Suppose your code depends on a collection of large assets that are used during code generation or testing. Those assets are stored in a private S3 bucket `s3://my_org_assets`.

  In the local repository, the user creates a `s3_lock.json` JSON lockfile describing the required objects, including their expected hashes:

  ```json
    {
        "trainingdata/model/small.bin": {
            "sha256": "abd83816bd236b266c3643e6c852b446f068fe260f3296af1a25b550854ec7e5"
        },
        "trainingdata/model/medium.bin": {
            "sha256": "c6f9568f930b16101089f1036677bb15a3185e9ed9b8dbce2f518fb5a52b6787"
        },
        "trainingdata/model/large.bin": {
            "sha256": "b3ccb0ba6f7972074b0a1e13340307abfd5a5eef540c521a88b368891ec5cd6b"
        },
        "trainingdata/model/very_large.bin": {
            "remote_path": "weird/nested/path/extra/model/very_large.bin",
            "integrity": "sha256-Oibw8PV3cDY84HKv3sAWIEuk+R2s8Hwhvlg6qg4H7uY="
        }
    }
  ```

  The exact format for the lockfile is a JSON object where each key is a path to a local file in the repository and the value is a JSON object with the following keys:

  - `sha256`: the expected sha256 hash of the file. Required unless `integrity` is used.
  - `integrity`: the expected SRI value of the file. Required unless `sha256` is used.
  - `remote_path`: name of the object within the bucket. If not set, the local path is used.

  Targets in the main repository can depend on this target if the
  following lines are added to `MODULE.bazel`:

  ```starlark
  s3_bucket = use_extension("@rules_s3//s3:extensions.bzl", "s3_bucket")
  s3_bucket.from_file(
      name = "trainingdata",
      bucket = "my_org_assets",
      lockfile = "@//:s3_lock.json",
  )
  ```

  Then targets would specify labels like `@trainingdata//:trainingdata/model/very_large.bin` as a dependency.


**TAG CLASSES**

<a id="s3_bucket.from_file"></a>

### from_file

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="s3_bucket.from_file-name"></a>name |  Name of the hub repository containing referencing all blobs   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="s3_bucket.from_file-bucket"></a>bucket |  Name of the S3 bucket   | String | required |  |
| <a id="s3_bucket.from_file-dev_dependency"></a>dev_dependency |  If true, this dependency will be ignored if the current module is not the root module or `--ignore_dev_dependency` is enabled.   | Boolean | optional |  `False`  |
| <a id="s3_bucket.from_file-lockfile"></a>lockfile |  JSON lockfile containing objects to load from the S3 bucket   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="s3_bucket.from_file-lockfile_jsonpath"></a>lockfile_jsonpath |  JSONPath expression referencing the dict of paths. By default, the top-level object is used.   | String | optional |  `""`  |
| <a id="s3_bucket.from_file-method"></a>method |  Method used for downloading:<br><br>`symlink`: lazy fetching with symlinks, `alias`: lazy fetching with alias targets, `copy`: lazy fetching with full file copies, `eager`: all objects are fetched eagerly   | String | optional |  `"symlink"`  |

## Troubleshooting

- Credential helper not found

    ```
    WARNING: Error retrieving auth headers, continuing without: Failed to get credentials for 'https://storage.googleapis.com/broad-public-datasets/intervals_hg38.list' from helper 'tools/credential-helper': Cannot run program "tools/credential-helper" (in directory "..."): error=2, No such file or directory
    ```

    You need to install a credential helper (either [`tweag-credential-helper`][tweag-credential-helper], the [shell script][credential-helper], or your own) as explained [above](#installation).

- Credential helper not working

    ```
    WARNING: Error retrieving auth headers, continuing without: Failed to get credentials for 'https://storage.googleapis.com/...' from helper 'tools/credential-helper': process timed out
    ```

    Run `gcloud auth application-default print-access-token` to see why it fails and ensure you are logged in and have application default credentials configured.

- HTTP 401 or 403 error codes

    ```
    ERROR: Target parsing failed due to unexpected exception: java.io.IOException: Error downloading [https://storage.googleapis.com/...] to ...: GET returned 403 Forbidden
    ```

    Ensure the user you are logged in as has access to the bucket using `gsutil ls s3://<BUCKET_NAME>/<OBJECT>` and check if the credential helper is configured in `.bazelrc` like this: `--credential_helper=storage.googleapis.com=%workspace%/tools/credential-helper`.

-  Checksum mismatch (empty file downloaded)

    ```
    Error in wait: com.google.devtools.build.lib.bazel.repository.downloader.UnrecoverableHttpException: Checksum was e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 but wanted <actual>
    ```

    Check if you are using `--experimental_remote_downloader`. If you do, the remote cache may drop your auth header and silently give you empty files instead. One workaround is setting `--experimental_remote_downloader_local_fallback` in `.bazelrc`.

## Acknowledgements

_`rules_s3` is based on [`rules_gcs`][rules_gcs_github], which was initially developed by [IMAX][imax]. Both projects are maintained by Tweag._

[example]: /examples/full/
[s3]: https://aws.amazon.com/s3/
[s3-signature]: https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-authenticating-requests.html
[rules_gcs_github]: https://github.com/tweag/rules_gcs
[credential-helper]: /tools/credential-helper
[bcr]: https://registry.bazel.build/modules/rules_s3
[imax]: https://www.imax.com/en/us/sct
[tweag-credential-helper]: https://github.com/tweag/credential-helper
