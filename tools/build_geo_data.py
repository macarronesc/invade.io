#!/usr/bin/env python3
"""Genera assets/data/geo.json a partir de Natural Earth (dominio público).

Uso:
    python3 -m venv .venv && .venv/bin/pip install pyshp shapely
    .venv/bin/python tools/build_geo_data.py [directorio_cache]

Salida (coordenadas lon/lat planas y redondeadas para que el JSON sea pequeño):
    {"land": [[lon, lat, lon, lat, ...], ...],
     "borders": [[lon, lat, ...], ...],
     "cities": [[clave, nombre_es, nombre_en, lon, lat, población], ...]}
"""
import io
import json
import os
import re
import sys
import unicodedata
import urllib.request
import zipfile

import shapefile
from shapely.geometry import LineString, Polygon, shape

SOURCES = {
    "land": "50m/physical/ne_50m_land",
    "borders": "50m/cultural/ne_50m_admin_0_boundary_lines_land",
    "places": "10m/cultural/ne_10m_populated_places",
}
LAND_TOLERANCE = 0.08       # grados; ~9 km, invisible a la escala de un nivel
BORDER_TOLERANCE = 0.06
MIN_ISLAND_AREA = 0.02      # grados²; conserva Samoa, Fiyi, Malta...
MAX_CITY_RANK = 4           # SCALERANK de Natural Earth (0 = megaciudad)
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "data", "geo.json")


def fetch(name: str, cache: str) -> shapefile.Reader:
    folder = os.path.join(cache, os.path.basename(SOURCES[name]))
    if not os.path.isdir(folder):
        url = "https://naciscdn.org/naturalearth/%s.zip" % SOURCES[name]
        data = urllib.request.urlopen(url).read()
        zipfile.ZipFile(io.BytesIO(data)).extractall(folder)
    shp = next(f for f in os.listdir(folder) if f.endswith(".shp"))
    return shapefile.Reader(os.path.join(folder, shp))


def flat(coords) -> list:
    return [round(v, 2) for pt in coords for v in pt]


def slug(text: str) -> str:
    ascii_text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "_", ascii_text.lower()).strip("_")


def build_land(reader) -> list:
    out = []
    for shp in reader.shapes():
        geom = shape(shp.__geo_interface__)
        for poly in getattr(geom, "geoms", [geom]):
            if poly.area < MIN_ISLAND_AREA:
                continue
            simple = Polygon(poly.exterior).simplify(LAND_TOLERANCE, preserve_topology=True)
            if simple.is_empty or len(simple.exterior.coords) < 4:
                continue
            out.append(flat(simple.exterior.coords[:-1]))
    return out


def build_borders(reader) -> list:
    out = []
    for shp in reader.shapes():
        geom = shape(shp.__geo_interface__)
        for line in getattr(geom, "geoms", [geom]):
            simple = LineString(line.coords).simplify(BORDER_TOLERANCE)
            if len(simple.coords) >= 2:
                out.append(flat(simple.coords))
    return out


def build_cities(reader) -> list:
    rows = [r for r in reader.records() if r["SCALERANK"] <= MAX_CITY_RANK]
    rows.sort(key=lambda r: -r["POP_MAX"])
    out, used = [], set()
    for r in rows:
        key = slug(r["NAMEASCII"])
        if key in used:
            key = "%s_%s" % (key, r["ADM0_A3"].lower())
        if key in used:
            continue
        used.add(key)
        out.append([key, r["NAME_ES"] or r["NAME"], r["NAME_EN"] or r["NAME"],
                    round(r["LONGITUDE"], 3), round(r["LATITUDE"], 3), int(r["POP_MAX"])])
    return out


def main() -> None:
    cache = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), ".ne_cache")
    os.makedirs(cache, exist_ok=True)
    data = {
        "land": build_land(fetch("land", cache)),
        "borders": build_borders(fetch("borders", cache)),
        "cities": build_cities(fetch("places", cache)),
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    print("land=%d borders=%d cities=%d -> %s (%d KB)" % (
        len(data["land"]), len(data["borders"]), len(data["cities"]), OUT, os.path.getsize(OUT) // 1024))


if __name__ == "__main__":
    main()
