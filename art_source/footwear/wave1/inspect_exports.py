"""Read-only GLB structural measurements; author QA, never independent art review.

Run with ordinary Python after export. No Blender/Godot/browser import occurs.
Prints actual primitive/material counts and sampled wheel-rotation evidence.
"""
import hashlib
import json
import math
import struct
from pathlib import Path

SOURCE = Path(__file__).resolve().parent
PROJECT = SOURCE.parents[2]
RUNTIME = PROJECT / "assets/models/footwear/wave1"


def glb(path):
    raw = path.read_bytes()
    magic, version, size = struct.unpack_from("<4sII", raw)
    assert magic == b"glTF" and version == 2 and size == len(raw), path
    chunks = {}
    at = 12
    while at < len(raw):
        size, kind = struct.unpack_from("<II", raw, at)
        chunks[kind] = raw[at+8:at+8+size]
        at += size+8
    return raw, json.loads(chunks[0x4E4F534A]), chunks[0x004E4942]


def values(doc, binary, index):
    accessor = doc["accessors"][index]
    view = doc["bufferViews"][accessor["bufferView"]]
    count = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[accessor["type"]]
    kind = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}[accessor["componentType"]]
    form = "<"+kind*count
    step = view.get("byteStride", struct.calcsize(form))
    offset = view.get("byteOffset", 0)+accessor.get("byteOffset", 0)
    return [struct.unpack_from(form, binary, offset+i*step) for i in range(accessor["count"])]


def multiply(a, b):
    return [[sum(a[i][k]*b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


IDENTITY = [[int(i == j) for j in range(4)] for i in range(4)]


def transform(node):
    if "matrix" in node:
        return [[node["matrix"][j*4+i] for j in range(4)] for i in range(4)]
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    rotation = [[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w), 0],
                [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w), 0],
                [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y), 0], [0, 0, 0, 1]]
    scale = node.get("scale", [1, 1, 1])
    for i in range(3):
        for j in range(3):
            rotation[i][j] *= scale[j]
        rotation[i][3] = node.get("translation", [0, 0, 0])[i]
    return rotation


def inspect(path):
    raw, doc, binary = glb(path)
    points = []
    triangles = 0
    for mesh in doc.get("meshes", []):
        for primitive in mesh["primitives"]:
            assert primitive.get("mode", 4) == 4, path
            triangles += doc["accessors"][primitive["indices"]]["count"]//3
    def visit(index, parent):
        node = doc["nodes"][index]
        world = multiply(parent, transform(node))
        if "mesh" in node:
            for primitive in doc["meshes"][node["mesh"]]["primitives"]:
                for p in values(doc, binary, primitive["attributes"]["POSITION"]):
                    q = [sum(world[i][j]*((*p, 1)[j]) for j in range(4)) for i in range(3)]
                    assert all(math.isfinite(x) for x in q), path
                    points.append(q)
        for child in node.get("children", []):
            visit(child, world)
    for index in doc["scenes"][doc.get("scene", 0)]["nodes"]:
        visit(index, IDENTITY)
    lo = [min(p[i] for p in points) for i in range(3)]
    hi = [max(p[i] for p in points) for i in range(3)]
    assert .12 <= hi[0]-lo[0] <= .22, (path, lo, hi)
    assert .27 <= hi[2]-lo[2] <= .36, (path, lo, hi)
    assert -.07 <= lo[1] <= -.048, (path, lo, hi)
    animation = []
    for clip in doc.get("animations", []):
        channels = []
        for channel in clip["channels"]:
            sampler = clip["samplers"][channel["sampler"]]
            times = values(doc, binary, sampler["input"])
            output = values(doc, binary, sampler["output"])
            channels.append({"target": doc["nodes"][channel["target"]["node"]].get("name"),
                "path": channel["target"]["path"], "samples": len(times),
                "duration_s": times[-1][0]-times[0][0],
                "distinct_sample_values": len({tuple(round(v, 5) for v in p) for p in output})})
        animation.append({"name": clip.get("name"), "channels": channels})
    wheel_names = [n["name"] for n in doc["nodes"] if n.get("name", "").startswith("WheelSpin_") and "mesh" not in n]
    if path.stem in ["SlipstreamInlines", "HeelspinQuads"]:
        assert len(wheel_names) == 4, (path, wheel_names)
        moving = {c["target"] for a in animation for c in a["channels"] if c["path"] == "rotation" and c["distinct_sample_values"] > 4 and abs(c["duration_s"]-1) < .01}
        assert set(wheel_names) <= moving, (path, animation)
    return {"file": str(path.relative_to(PROJECT)), "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest(),
        "triangles": triangles, "mesh_count": len(doc["meshes"]),
        "primitive_count": sum(len(m["primitives"]) for m in doc["meshes"]),
        "materials": [m["name"] for m in doc.get("materials", [])],
        "bounds_godot_m": {"min": lo, "max": hi, "size": [hi[i]-lo[i] for i in range(3)]},
        "wheel_nodes": wheel_names, "animations": animation, "external_buffers": [b.get("uri") for b in doc["buffers"] if b.get("uri")],
        "classification": "author_structural_QA_only; actual runtime visual assessment pending"}


if __name__ == "__main__":
    files = sorted(RUNTIME.glob("*.glb"))
    assert len(files) == 8, "Eight exported assets required"
    print(json.dumps({"assets": [inspect(path) for path in files], "HUMAN": False, "RC2": False, "V1": False}, indent=2))
