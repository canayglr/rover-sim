#!/usr/bin/env python3
"""AutoRace dünyasını ölçekler (varsayılan 3x). Tek kaynak: orijinal/ (1x dosyalar).

Girdi : orijinal/autorace.sdf, orijinal/models/turtlebot3_autorace_2020/*/model.sdf
Çıktı : autorace.sdf, models/turtlebot3_autorace_2020/*/model.sdf  (elle DÜZENLEMEYİN)
Kullanım: python3 olcekle.py [ölçek]    (varsayılan 3)

Ölçeklenen: tüm <pose> konumları (x y z; dönüşler değil), <size>, <radius>, <length>,
ışık <range>. Rover include'u (wildthumper) için yalnızca x,y ölçeklenir (z, rover
tabanı yüksekliği değişmez); rover modeli ölçeklenmez. Dokular/sürtünme değişmez.
Tekdüze ölçek olduğu için yerden yükseklik oranları (z/boy) korunur, nesne havada/gömülü kalmaz.
"""
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

K = float(sys.argv[1]) if len(sys.argv) > 1 else 3.0
KOK = Path(__file__).resolve().parent
SCALE_TAGS = {"size", "radius", "length", "range"}


def f(v):
    return f"{round(v, 6):g}"


def olcekle_agac(kok, rover_include=False):
    parent = {c: p for p in kok.iter() for c in p}
    for e in kok.iter():
        if not isinstance(e.tag, str) or not (e.text or "").strip():
            continue
        if e.tag in SCALE_TAGS:
            e.text = " ".join(f(float(x) * K) for x in e.text.split())
        elif e.tag == "pose":
            v = [float(x) for x in e.text.split()]
            rover = parent.get(e) is not None and parent[e].tag == "include" and \
                (parent[e].findtext("uri") or "").strip() == "model://wildthumper"
            v[0] *= K
            v[1] *= K
            if not rover:
                v[2] *= K
            e.text = " ".join(f(x) for x in v)


def isle(girdi, cikti):
    ag = ET.parse(girdi, parser=ET.XMLParser(target=ET.TreeBuilder(insert_comments=True)))
    kok = ag.getroot()
    olcekle_agac(kok)
    if girdi.name == "autorace.sdf":
        c = ET.Comment(f" {K:g}x ölçekli: orijinal/autorace.sdf'den olcekle.py ile üretildi, elle düzenlemeyin. ")
        kok.find("world").insert(0, c)
    ET.indent(ag, space="  ")
    cikti.parent.mkdir(parents=True, exist_ok=True)
    ag.write(cikti, encoding="utf-8", xml_declaration=True)


isle(KOK / "orijinal/autorace.sdf", KOK / "autorace.sdf")
for g in sorted((KOK / "orijinal/models").glob("*/*/model.sdf")):
    isle(g, KOK / g.relative_to(KOK / "orijinal"))
print(f"{K:g}x ölçeklendi")
