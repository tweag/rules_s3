load("@rules_testing//lib:analysis_test.bzl", "test_suite", "analysis_test")
load("@rules_testing//lib:util.bzl", "util")
load("//s3/private:jsonpath.bzl", "walk_jsonpath")

EXAMPLE_OBJECT = {
    "foo": "a string",
    "bar": [1, "two", 3],
    "baz": {"a": ["first", "second"], "b": None, "c": {}, "d": "another string"},
}

def _test_walk(env):
    # dollar should reference the root object
    _expect_json(env = env, jsonpath = "$", obj = EXAMPLE_OBJECT, expected_json = json.encode(EXAMPLE_OBJECT))
    # empty expression should reference the root object
    _expect_json(env = env, jsonpath = "", obj = EXAMPLE_OBJECT, expected_json = json.encode(EXAMPLE_OBJECT))
    # None expression should reference the root object
    _expect_json(env = env, jsonpath = None, obj = EXAMPLE_OBJECT, expected_json = json.encode(EXAMPLE_OBJECT))
    # Simple descend with dict keys
    _expect_json(env = env, jsonpath = ".baz.d", obj = EXAMPLE_OBJECT, expected_json = json.encode("another string"))
    # Simple descend with array subscripts
    _expect_json(env = env, jsonpath = "['foo']", obj = EXAMPLE_OBJECT, expected_json = json.encode("a string"))
    _expect_json(env = env, jsonpath = "['bar'][2]", obj = EXAMPLE_OBJECT, expected_json = json.encode(3))
    _expect_json(env = env, jsonpath = "['baz']['d']", obj = EXAMPLE_OBJECT, expected_json = json.encode("another string"))
    # mix of array subscripts and keys
    _expect_json(env = env, jsonpath = "['baz'].a[1]", obj = EXAMPLE_OBJECT, expected_json = json.encode("second"))

def _expect_json(jsonpath = None, obj = None, raw_json = None, expected_json = None, env = None):
    if raw_json != None:
        obj = json.decode(raw_json)
    got_obj = walk_jsonpath(obj, jsonpath)
    got_json = json.encode(got_obj)
    env.expect.that_str(got_json).equals(expected_json)

def jsonpath_test_suite(name):
    test_suite(
        name = name,
        basic_tests = [
            _test_walk,
        ]
    )
