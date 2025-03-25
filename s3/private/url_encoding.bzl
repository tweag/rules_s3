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

UNRESERVED_CHARS = \
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ" + \
    "abcdefghijklmnopqrstuvwxyz" + \
    "0123456789-._~"

I_TO_C = \
    "\0\1\2\3\4\5\6\7\10\11\12\13\14\15\16\17" + \
    "\20\21\22\23\24\25\26\27\30\31\32\33\34\35\36\37" + \
    "\40\41\42\43\44\45\46\47\50\51\52\53\54\55\56\57" + \
    "\60\61\62\63\64\65\66\67\70\71\72\73\74\75\76\77" + \
    "\100\101\102\103\104\105\106\107\110\111\112\113\114\115\116\117" + \
    "\120\121\122\123\124\125\126\127\130\131\132\133\134\135\136\137" + \
    "\140\141\142\143\144\145\146\147\150\151\152\153\154\155\156\157" + \
    "\160\161\162\163\164\165\166\167\170\171\172\173\174\175\176\177" + \
    "\200\201\202\203\204\205\206\207\210\211\212\213\214\215\216\217" + \
    "\220\221\222\223\224\225\226\227\230\231\232\233\234\235\236\237" + \
    "\240\241\242\243\244\245\246\247\250\251\252\253\254\255\256\257" + \
    "\260\261\262\263\264\265\266\267\270\271\272\273\274\275\276\277" + \
    "\300\301\302\303\304\305\306\307\310\311\312\313\314\315\316\317" + \
    "\320\321\322\323\324\325\326\327\330\331\332\333\334\335\336\337" + \
    "\340\341\342\343\344\345\346\347\350\351\352\353\354\355\356\357" + \
    "\360\361\362\363\364\365\366\367\370\371\372\373\374\375\376\377"

C_TO_I = {
    c: i
    for (i, c) in enumerate(I_TO_C.elems())
}

def url_encode(s, escape = "%", unreserved = UNRESERVED_CHARS):
    encoded = ""
    for c in s.elems():
        if c in unreserved:
            encoded += c
            continue
        encoded += "{}{}".format(escape, hex(ord(c)))
    return encoded

def url_decode(s, escape = "%"):
    decoded = ""
    i = 0
    skip = 0
    for i in range(len(s)):
        if skip > 0:
            skip -= 1
            continue
        if s[i] == escape:
            decoded += chr(int(s[i + 1:i + 3], 16))
            skip = 2
        else:
            decoded += s[i]
    return decoded

def ord(c):
    return C_TO_I[c]

def chr(i):
    return I_TO_C[i]

def digit_to_hex_char(n):
    return ("0123456789abcdef")[n]

def hex(i):
    if i < 0 or i > 0x10FFFD:
        fail("url_encode is only defined for strings of valid unicode chars")
    hex_string = ""

    # we are operating on unicode code points
    # and need a maximum of six iterations
    # log16(0x10FFFD) < 6
    for _ in range(6):
        if i > 0:
            rem = i % 16
            hex_string = digit_to_hex_char(rem) + hex_string
            i //= 16
        else:
            break

    if not hex_string:
        hex_string = "00"

    pad = "0" * (len(hex_string) % 2)
    return pad + hex_string
