load("@rules_testing//lib:analysis_test.bzl", "test_suite", "analysis_test")
load("@rules_testing//lib:util.bzl", "util")
load("//s3/private:url_encoding.bzl", "url_encode", "url_decode")

def _test_url_encode(env):
    env.expect.that_str(url_encode("foo")).equals("foo")
    env.expect.that_str(url_encode("a/b/c")).equals("a%2fb%2fc")
    env.expect.that_str(url_encode("🖥️")).equals("%f0%9f%96%a5%ef%b8%8f")

def _test_url_decode(env):
    env.expect.that_str(url_decode("foo")).equals("foo")
    env.expect.that_str(url_decode("a%2fb%2fc")).equals("a/b/c")
    env.expect.that_str(url_decode("%f0%9f%96%a5%ef%b8%8f")).equals("🖥️")

def _test_invariant_holds(env):
    _invariant(env, """ !"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~""")

def _invariant(env, s):
    env.expect.that_str(url_decode(url_encode(s))).equals(s)

def url_encoding_test_suite(name):
    test_suite(
        name = name,
        basic_tests = [
            _test_url_encode,
            _test_url_decode,
            _test_invariant_holds,
        ]
    )
