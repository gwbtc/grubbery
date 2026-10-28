#!/usr/bin/env python3
"""Extract a city's POIs from Overture Maps places into a JSON file.

Queries the public Overture parquet remotely (DuckDB, bbox row-group
pruning — no full download) and writes {city, bbox, release, places}.
Each place: {name, cat, lat, lng, conf, addr}.

Usage:
  python3 scripts/extract-places.py turin 7.62 45.03 7.72 45.11 out/turin.json
  python3 scripts/extract-places.py soverato 16.52 38.66 16.58 38.71 out/soverato.json

Filtered to confidence >= MIN_CONF. Feed the output to the places
nexus (one grub per city under /apps/places.places/cities/).
"""
import sys, json, time

RELEASE = "2026-08-19.0"
MIN_CONF = 0.60

def main():
    if len(sys.argv) != 7:
        print(__doc__)
        sys.exit(1)
    city, xmin, ymin, xmax, ymax, out = sys.argv[1:]
    xmin, ymin, xmax, ymax = map(float, (xmin, ymin, xmax, ymax))

    import duckdb
    con = duckdb.connect()
    con.execute("INSTALL httpfs; LOAD httpfs; SET s3_region='us-west-2';")
    base = f"s3://overturemaps-us-west-2/release/{RELEASE}/theme=places/type=place/*.parquet"

    t0 = time.time()
    rows = con.execute(f"""
      SELECT names."primary" AS name,
             categories."primary" AS cat,
             round((bbox.ymin + bbox.ymax) / 2, 5) AS lat,
             round((bbox.xmin + bbox.xmax) / 2, 5) AS lng,
             round(confidence, 3) AS conf,
             addresses[1].freeform AS addr
      FROM read_parquet('{base}', hive_partitioning=1)
      WHERE bbox.xmin > {xmin} AND bbox.xmax < {xmax}
        AND bbox.ymin > {ymin} AND bbox.ymax < {ymax}
        AND confidence >= {MIN_CONF}
        AND names."primary" IS NOT NULL
      ORDER BY confidence DESC
    """).fetchall()

    places = [
        {"name": n, "cat": c or "", "lat": lat, "lng": lng,
         "conf": conf, "addr": a or ""}
        for (n, c, lat, lng, conf, a) in rows
    ]
    doc = {
        "city": city,
        "bbox": [xmin, ymin, xmax, ymax],
        "release": RELEASE,
        "count": len(places),
        "places": places,
    }
    with open(out, "w") as f:
        json.dump(doc, f, ensure_ascii=False, separators=(",", ":"))
    print(f"{city}: {len(places)} places in {time.time()-t0:.1f}s -> {out}")

if __name__ == "__main__":
    main()
