"""Generate synthetic two-voice support calls as MP3 files, plus truth.csv.

macOS only: uses the built-in `say` voices and ffmpeg. The repo ships the MP3s,
so you need this script only to regenerate them.
Usage: python3 tools/make_calls.py [count]   (default 40)
"""
import csv
import random
import subprocess
import sys
import tempfile
from pathlib import Path

import phrases as P

SEED = 20261022
OUT = Path(__file__).resolve().parent.parent / "data" / "calls"
AGENT_VOICES = ["Samantha", "Karen"]
CUSTOMER_VOICES = ["Daniel", "Fred", "Moira"]


def turns(script):
    """Split a script into alternating agent/customer turns at sentence ends."""
    sentences = [s.strip() for s in script.replace("?", "?|").replace(".", ".|").split("|") if s.strip()]
    out, cur, speaker = [], [], 0
    for s in sentences:
        cur.append(s)
        if s.endswith("?") or len(cur) == 2:
            out.append((speaker, " ".join(cur))); cur = []; speaker = 1 - speaker
    if cur:
        out.append((speaker, " ".join(cur)))
    return out


def main():
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 40
    r = random.Random(SEED)
    OUT.mkdir(parents=True, exist_ok=True)
    truth = []
    for i in range(count):
        outcome, sentiment, tpl = P.CALL_SCRIPTS[i % len(P.CALL_SCRIPTS)]
        script = tpl.format(order=f"A-{r.randint(100000, 999999)}", product=r.choice(P.PRODUCTS))
        voices = (r.choice(AGENT_VOICES), r.choice(CUSTOMER_VOICES))
        name = f"call_{i + 1:03d}.mp3"
        with tempfile.TemporaryDirectory() as tmp:
            parts = []
            for k, (spk, text) in enumerate(turns(script)):
                aiff = Path(tmp) / f"{k:02d}.aiff"
                subprocess.run(["say", "-v", voices[spk], "-o", str(aiff), text], check=True)
                parts.append(aiff)
            listing = Path(tmp) / "list.txt"
            listing.write_text("".join(f"file '{p}'\n" for p in parts))
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(listing),
                            "-ac", "1", "-ar", "16000", "-b:a", "32k", str(OUT / name)], check=True)
        truth.append([name, outcome, sentiment, script])
    with open(OUT / "truth.csv", "w", newline="") as f:
        w = csv.writer(f); w.writerow(["FILE", "OUTCOME", "TRUE_SENTIMENT", "SCRIPT"]); w.writerows(truth)
    print(f"{count} calls -> {OUT}")


if __name__ == "__main__":
    main()
