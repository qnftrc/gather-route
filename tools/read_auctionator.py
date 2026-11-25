#!/usr/bin/env python3
import argparse
import datetime
import json
import os
import re
import struct
import sys

DAY_ZERO = datetime.date(2020, 1, 1)
ESCAPES = {ord("n"): 10, ord("r"): 13, ord("t"): 9, ord('"'): 34, ord("\\"): 92, ord("'"): 39,
           ord("a"): 7, ord("b"): 8, ord("f"): 12, ord("v"): 11}


def unescape(seg, start):
    out = bytearray()
    k = start
    while True:
        c = seg[k]
        if c == 0x5C:
            n = seg[k + 1]
            if 0x30 <= n <= 0x39:
                m = re.match(rb"\d{1,3}", seg[k + 1:])
                out.append(int(m.group(0)) & 255)
                k += 1 + len(m.group(0))
            else:
                out.append(ESCAPES.get(n, n))
                k += 2
        elif c == 0x22:
            return bytes(out)
        else:
            out.append(c)
            k += 1


def cbor(b, i=0):
    ib = b[i]
    mt, ai = ib >> 5, ib & 31
    i += 1
    if ai < 24:
        v = ai
    elif ai == 24:
        v = b[i]
        i += 1
    elif ai == 25:
        v = struct.unpack(">H", b[i:i + 2])[0]
        i += 2
    elif ai == 26:
        v = struct.unpack(">I", b[i:i + 4])[0]
        i += 4
    elif ai == 27:
        v = struct.unpack(">Q", b[i:i + 8])[0]
        i += 8
    elif mt == 7 and ai in (20, 21, 22):
        return {20: False, 21: True, 22: None}[ai], i
    else:
        raise ValueError("unsupported CBOR byte %02x at %d" % (ib, i - 1))
    if mt == 0:
        return v, i
    if mt == 1:
        return -1 - v, i
    if mt in (2, 3):
        return bytes(b[i:i + v]), i + v
    if mt == 4:
        out = []
        for _ in range(v):
            x, i = cbor(b, i)
            out.append(x)
        return out, i
    if mt == 5:
        out = {}
        for _ in range(v):
            k, i = cbor(b, i)
            x, i = cbor(b, i)
            out[k] = x
        return out, i
    raise ValueError("unsupported CBOR type %d" % mt)


def read_file(path):
    raw = open(path, "rb").read()
    result = {"realms": {}, "vendor": {}, "scanTime": None}
    m = re.search(rb'\["TimeOfLastBrowseScan"\] = (\d+)', raw)
    if m:
        result["scanTime"] = int(m.group(1))
    i = raw.find(b"AUCTIONATOR_PRICE_DATABASE")
    j = raw.find(b"AUCTIONATOR_POSTING_HISTORY", i)
    seg = raw[i:j]
    for m in re.finditer(rb'\["([^"\]]+)"\] = "', seg):
        realm = m.group(1).decode("utf8", "replace")
        blob = unescape(seg, m.end())
        data, end = cbor(blob, 0)
        if end != len(blob):
            raise ValueError("trailing bytes after the %s database" % realm)
        result["realms"][realm] = data
    i = raw.find(b"AUCTIONATOR_VENDOR_PRICE_CACHE")
    if i >= 0:
        j = raw.find(b"\n}", i)
        for m in re.finditer(rb'\["(\d+)"\] = (\d+),', raw[i:j]):
            result["vendor"][int(m.group(1))] = int(m.group(2))
    return result


def day_text(day):
    return (DAY_ZERO + datetime.timedelta(days=int(day))).isoformat()


def latest(series):
    if not isinstance(series, dict) or not series:
        return None, None
    day = max(series, key=lambda d: int(d))
    return int(day), series[day]


def summarize(db):
    items, gear = {}, {}
    for key, e in db.items():
        k = key.decode("latin1")
        if not isinstance(e, dict):
            continue
        entry = {"m": e.get(b"m")}
        for field in ("l", "h", "a"):
            entry[field] = {day_text(int(d)): v for d, v in sorted((e.get(field.encode()) or {}).items(), key=lambda kv: int(kv[0]))}
        if k.isdigit():
            items[int(k)] = entry
        elif k.startswith("gr:"):
            day, low = latest(e.get(b"l"))
            gear[k] = {"m": entry["m"], "low": low, "day": day_text(day) if day is not None else None}
    return items, gear


def main(argv=None):
    ap = argparse.ArgumentParser(description="Read the price database of an Auctionator SavedVariables file (Auctionator.lua) into JSON.")
    ap.add_argument("file")
    ap.add_argument("--out", required=True, help="directory for auctionator_prices.json and auctionator_gear.json")
    ap.add_argument("--names", help="JSON file {itemID: name} used to name the items")
    args = ap.parse_args(argv)
    data = read_file(args.file)
    if not data["realms"]:
        raise SystemExit("no price database found in " + args.file)
    names = {}
    if args.names:
        names = {int(k): v for k, v in json.load(open(args.names, encoding="utf8")).items()}
    os.makedirs(args.out, exist_ok=True)
    for realm, db in data["realms"].items():
        items, gear = summarize(db)
        for item_id, e in items.items():
            e["name"] = names.get(item_id)
            e["vendor"] = data["vendor"].get(item_id)
        meta = {
            "source": "Auctionator price database (CBOR), unit = copper", "realm": realm, "scanTime": data["scanTime"],
            "scanDate": datetime.datetime.fromtimestamp(data["scanTime"], datetime.timezone.utc).isoformat() if data["scanTime"] else None,
            "dayZero": DAY_ZERO.isoformat(), "items": len(items), "gear": len(gear),
        }
        with open(os.path.join(args.out, "auctionator_prices.json"), "w", encoding="utf8") as f:
            json.dump({"meta": meta, "items": {str(k): v for k, v in sorted(items.items())}, "vendor": {str(k): v for k, v in sorted(data["vendor"].items())}}, f, ensure_ascii=False, separators=(",", ":"))
        with open(os.path.join(args.out, "auctionator_gear.json"), "w", encoding="utf8") as f:
            json.dump({"meta": meta, "gear": gear}, f, ensure_ascii=False, separators=(",", ":"))
        print("%s: %d items, %d gear entries, scan %s" % (realm, len(items), len(gear), meta["scanDate"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
