#!/usr/bin/env python3
"""Extract PPTX slide text, images, and optional JPG references for branded HTML conversion."""

from __future__ import annotations

import argparse
import json
import posixpath
import re
from pathlib import Path
from xml.etree import ElementTree as ET
from zipfile import ZipFile

NS = {
    "p": "http://schemas.openxmlformats.org/presentationml/2006/main",
    "a": "http://schemas.openxmlformats.org/drawingml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
    "pr": "http://schemas.openxmlformats.org/package/2006/relationships",
}


def rels_for_slide(zip_file: ZipFile, slide_no: int) -> dict[str, str]:
    rel_path = f"ppt/slides/_rels/slide{slide_no}.xml.rels"
    if rel_path not in zip_file.namelist():
        return {}
    root = ET.fromstring(zip_file.read(rel_path))
    rels = {}
    for rel in root:
        rel_type = rel.attrib.get("Type", "")
        if rel_type.endswith("/image"):
            target = rel.attrib["Target"]
            rels[rel.attrib["Id"]] = posixpath.normpath(posixpath.join("ppt/slides", target))
    return rels


def text_from_shape(shape: ET.Element) -> str:
    paragraphs: list[str] = []
    for para in shape.findall(".//a:p", NS):
        parts: list[str] = []
        for node in para:
            name = node.tag.rsplit("}", 1)[-1]
            if name in {"r", "fld"}:
                text_node = node.find("a:t", NS)
                if text_node is not None and text_node.text:
                    parts.append(text_node.text)
            elif name == "br":
                parts.append("\\n")
        text = "".join(parts).strip()
        if text:
            paragraphs.append(text)
    return "\\n".join(paragraphs).strip()


def box_from_shape(shape: ET.Element) -> dict[str, int] | None:
    xfrm = shape.find(".//a:xfrm", NS)
    if xfrm is None:
        return None
    off = xfrm.find("a:off", NS)
    ext = xfrm.find("a:ext", NS)
    if off is None or ext is None:
        return None
    return {
        "x": int(float(off.attrib.get("x", 0))),
        "y": int(float(off.attrib.get("y", 0))),
        "cx": int(float(ext.attrib.get("cx", 0))),
        "cy": int(float(ext.attrib.get("cy", 0))),
    }


def slide_count(zip_file: ZipFile) -> int:
    names = zip_file.namelist()
    nums = []
    for name in names:
        match = re.fullmatch(r"ppt/slides/slide(\d+)\.xml", name)
        if match:
            nums.append(int(match.group(1)))
    return max(nums) if nums else 0


def extract(pptx: Path, out_dir: Path, refs_zip: Path | None = None) -> Path:
    media_dir = out_dir / "assets" / "media"
    ref_dir = out_dir / "assets" / "reference"
    media_dir.mkdir(parents=True, exist_ok=True)
    ref_dir.mkdir(parents=True, exist_ok=True)
    slides: list[dict] = []

    with ZipFile(pptx) as z:
        for slide_no in range(1, slide_count(z) + 1):
            slide_path = f"ppt/slides/slide{slide_no}.xml"
            root = ET.fromstring(z.read(slide_path))
            rels = rels_for_slide(z, slide_no)
            texts = []
            images = []

            for shape in root.findall(".//p:sp", NS):
                text = text_from_shape(shape)
                if text:
                    texts.append({"text": text, "box": box_from_shape(shape)})
                blip = shape.find(".//a:blip", NS)
                if blip is not None:
                    rid = blip.attrib.get(f"{{{NS['r']}}}embed")
                    target = rels.get(rid or "")
                    if target:
                        name = Path(target).name
                        (media_dir / name).write_bytes(z.read(target))
                        images.append({"src": f"assets/media/{name}", "box": box_from_shape(shape)})

            for pic in root.findall(".//p:pic", NS):
                blip = pic.find(".//a:blip", NS)
                rid = blip.attrib.get(f"{{{NS['r']}}}embed") if blip is not None else None
                target = rels.get(rid or "")
                if target:
                    name = Path(target).name
                    (media_dir / name).write_bytes(z.read(target))
                    images.append({"src": f"assets/media/{name}", "box": box_from_shape(pic)})

            slides.append({"slide": slide_no, "texts": texts, "images": images})

    if refs_zip and refs_zip.exists():
        with ZipFile(refs_zip) as z:
            for name in z.namelist():
                if name.lower().endswith((".jpg", ".jpeg", ".png")):
                    (ref_dir / Path(name).name).write_bytes(z.read(name))

    manifest = out_dir / "assets" / "pptx-manifest.json"
    manifest.write_text(json.dumps({"pptx": str(pptx), "slides": slides}, indent=2), encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("pptx", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--refs-zip", type=Path)
    args = parser.parse_args()
    manifest = extract(args.pptx, args.out, args.refs_zip)
    print(manifest)


if __name__ == "__main__":
    main()
