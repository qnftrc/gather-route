import json, subprocess, sys
# usage: python3 -I tools/test_math.py <planner.html> <regions_waypoints.json>
from lupa import LuaRuntime
H = sys.argv[1]
D = json.load(open(sys.argv[2], encoding="utf-8"))
cases = [
  {"region":"Stranglethorn Vale","herbs":["Fadeleaf"],"start":{"x":50,"y":50}},
  {"region":"Stranglethorn Vale","herbs":sorted(D["regions"]["Stranglethorn Vale"]["herbs"]),"start":{"x":30.5,"y":70.2}},
  {"region":"Zephras Isle","herbs":sorted(D["regions"]["Zephras Isle"]["herbs"]),"start":{"x":10,"y":10}},
  {"region":"Elwynn Forest","herbs":["Peacebloom"],"start":{"x":0,"y":0}},
]
ref = json.loads(subprocess.check_output(["node","tools/ref_route.js",H,json.dumps(cases)]))
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open("HerbRoute/Data/HerbData.lua",encoding="utf-8").read())
lua.execute("HR={}")
lua.eval("function(s) return load(s,'rm')(nil, HR) end")(open("HerbRoute/RouteMath.lua",encoding="utf-8").read())
run = lua.eval("""function(region, herbs, sx, sy)
  local pts = {}
  for _, h in ipairs(herbs) do for _, p in ipairs(HerbRoute_Data[region][h]) do pts[#pts+1] = {x=p[1], y=p[2], herb=h} end end
  local start = {x=sx, y=sy}
  local route = HR.Math.solve(pts, start)
  local first, last = {}, {}
  for i=1,5 do first[#first+1] = route[i].x..","..route[i].y end
  for i=#route-2,#route do last[#last+1] = route[i].x..","..route[i].y end
  return #pts, HR.Math.pathLength(route, start), table.concat(first, ";"), table.concat(last, ";")
end""")
ok = True
for c, r in zip(cases, ref):
    n, ln, first, last = run(c["region"], lua.table_from(c["herbs"]), c["start"]["x"], c["start"]["y"])
    rf = ";".join("%s,%s" % (str(x).rstrip('0').rstrip('.') if False else (int(x) if x==int(x) else x), (int(y) if y==int(y) else y)) for x,y in r["first"])
    same = n == r["n"] and abs(ln - r["len"]) < 1e-6 and first.replace(".0,",",").replace(".0;",";") == rf
    ok &= same
    print(c["region"], n, r["n"], round(ln,4), round(r["len"],4), "SAME" if same else "DIFF", first if not same else "")
print("ALL SAME" if ok else "MISMATCH")
