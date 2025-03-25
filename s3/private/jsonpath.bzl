"""
Copyright 2025 Modus Create LLC

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

JSONPATH_RESERVED_CHARS = """$@.[]*"'"""

def walk_jsonpath(obj, jsonpath):
    if jsonpath == None or len(jsonpath) == 0 or jsonpath == "$":
        return obj
    if type(jsonpath) != type("x"):
        fail("expected jsonpath to be a string")
    # We always start at the root object.
    # We can ignore "$".
    if jsonpath[0] == "$":
        jsonpath = jsonpath[1:]
    i = 0
    for _ in range(len(jsonpath)):
        if i >= len(jsonpath):
            break
        if jsonpath[i] == ".":
            # descend to child in object
            # we expect a string without quotes
            key, rest = jsonpath_split_key(jsonpath[i + 1:])
            if key not in obj:
                fail("key {} not found in object".format(key))
            obj = obj[key]
            i += len(key) + 1
        elif jsonpath[i] == "[":
            # descend to child in array or object
            # we expect a number or a string with single quotes
            key, rest = jsonpath_split_array_subscript(jsonpath[i + 1:])
            if len(rest) == 0 or rest[0] != "]":
                fail("expected closing bracket")
            obj = obj[key]
            i = len(jsonpath) - len(rest) + 1
        else:
            fail("We only support a subset of JSONPath using dot and array notation to access children via \".foo\", \"[0]\", or \"['foo']\"")
    return obj

def jsonpath_split_key(path):
    if len(path) == 0:
        return ("", "")
    for i in range(len(path)):
        if path[i] in JSONPATH_RESERVED_CHARS:
            return (path[:i], path[i:])
    return (path, "")

def jsonpath_split_decimal_int(path):
    if len(path) == 0:
        fail("expected non-empty decimal integer")
    if not path[0].isdigit():
        fail("expected decimal integer to start with a digit")
    for i in range(len(path)):
        if not path[i].isdigit():
            return (path[:i], path[i:])
    return (path, "")

def jsonpath_split_array_subscript(path):
    if len(path) == 0:
        fail("expected non-empty array access")
    if path[0] == "'":
        # we expect a string with single quotes
        if len(path) < 3:
            fail("expected array access with single quotes to be at least 3 characters long")
        components = path[1:].split("'", 1)
        if len(components) != 2:
            fail("expected array access with single quotes to have a closing quote")
        return tuple(components)
    # we expect a number
    num, rest = jsonpath_split_decimal_int(path)
    return (int(num), rest)
