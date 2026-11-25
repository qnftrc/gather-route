#!/usr/bin/env python3
import json
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import read_auctionator as ra


def enc_int(v):
    if v < 24:
        return bytes([v])
    if v < 256:
        return bytes([0x18, v])
    if v < 65536:
        return bytes([0x19]) + v.to_bytes(2, "big")
    return bytes([0x1A]) + v.to_bytes(4, "big")


def enc_bytes(s):
    s = s.encode()
    return bytes([0x40 | len(s)]) + s


def enc_map(pairs):
    return bytes([0xA0 | (len(pairs) // 2)]) + b"".join(pairs)


def lua_escape(blob):
    out = []
    for c in blob:
        if c in (0x22, 0x5C):
            out.append("\\" + chr(c))
        elif c == 10:
            out.append("\\n")
        elif c == 13:
            out.append("\\r")
        elif c < 32 or c > 126:
            out.append("\\%03d" % c)
        else:
            out.append(chr(c))
    return "".join(out)


def main():
    day = lambda n: enc_bytes(str(n))
    item = enc_map([
        enc_bytes("a"), enc_map([day(2519), enc_int(300), day(2520), enc_int(5)]),
        enc_bytes("l"), enc_map([day(2519), enc_int(1500), day(2520), enc_int(70000)]),
        enc_bytes("h"), enc_map([day(2520), enc_int(80000)]),
        enc_bytes("m"), enc_int(70000),
    ])
    gear = enc_map([enc_bytes("a"), enc_map([day(2520), enc_int(1)]), enc_bytes("l"), enc_map([day(2520), enc_int(9900)]), enc_bytes("m"), enc_int(9900)])
    db = bytes([0xA3]) + enc_bytes("2319") + item + enc_bytes("gr:15502:of the Monkey") + gear + enc_bytes("version") + enc_int(8)
    text = ('AUCTIONATOR_SAVEDVARS = {\n["TimeOfLastBrowseScan"] = 1795645305,\n}\nAUCTIONATOR_PRICE_DATABASE = {\n["__dbversion"] = 8,\n'
            '["PvE Horde"] = "%s",\n}\nAUCTIONATOR_POSTING_HISTORY = {\n}\nAUCTIONATOR_VENDOR_PRICE_CACHE = {\n["2319"] = 52,\n["__dbversion"] = 8,\n}\n') % lua_escape(db)
    with tempfile.TemporaryDirectory() as tmp:
        src = os.path.join(tmp, "Auctionator.lua")
        with open(src, "w", encoding="utf8", newline="") as f:
            f.write(text)
        names = os.path.join(tmp, "names.json")
        json.dump({"2319": "Medium Leather"}, open(names, "w"))
        out = os.path.join(tmp, "out")
        assert ra.main([src, "--out", out, "--names", names]) == 0
        prices = json.load(open(os.path.join(out, "auctionator_prices.json")))
        e = prices["items"]["2319"]
        assert e["name"] == "Medium Leather" and e["m"] == 70000 and e["vendor"] == 52
        assert e["l"] == {"2026-11-24": 1500, "2026-11-25": 70000}, e["l"]
        assert prices["meta"]["scanDate"].startswith("2026-11-25")
        gear_data = json.load(open(os.path.join(out, "auctionator_gear.json")))
        assert gear_data["gear"]["gr:15502:of the Monkey"]["low"] == 9900
    print("READ AUCTIONATOR TESTS OK")


if __name__ == "__main__":
    main()
