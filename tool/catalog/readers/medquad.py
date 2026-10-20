"""MedQuAD (CC BY 4.0, Ben Abacha & Demner-Fushman 2019): question-answer pairs from NIH websites, raw_medquad. Every
pair with an answer, all topics (docs/PLAN.md "Catalogue v4", decision 6), quoted as published: only whitespace is
tidied. The three MedlinePlus subsets whose answers the authors removed (copyright) have none and add nothing."""

import re
import xml.etree.ElementTree as ET


def read(data):
    for folder in sorted((data / "raw_medquad/MedQuAD").glob("*_QA*")):
        for path in sorted(folder.glob("*.xml")):
            doc = ET.parse(path).getroot()
            for pair in doc.iter("QAPair"):
                q, a = pair.find("Question"), pair.find("Answer")
                if q is None or a is None or not (a.text or "").strip():
                    continue
                answer = "\n\n".join(re.sub(r"[ \t]+", " ", p).strip() for p in re.split(r"\n\s*\n", a.text) if p.strip())
                yield {
                    "kind": "qa",
                    "focus": (doc.findtext("Focus") or "").strip(),
                    "question": re.sub(r"\s+", " ", q.text or "").strip(),
                    "text": answer,
                    "source_id": "medquad_" + doc.get("source", "nih").lower(),
                    "url": doc.get("url"),
                }
