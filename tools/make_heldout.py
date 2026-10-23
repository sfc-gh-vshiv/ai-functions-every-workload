"""Write the held-out test sets to data/csv/heldout_*.csv.gz.

The held-out phrasings (tools/heldout_phrases.py) were written separately from the prompts they test.
They share no sentence with the templates in tools/phrases.py. The shopper queries share no
family-specific word with the product descriptions (9 of 60 share only generic words such as "from"). Usage: python3 tools/make_heldout.py
"""
import csv
import gzip
from pathlib import Path

import heldout_phrases as H

OUT = Path(__file__).resolve().parent.parent / "data" / "csv"


def write(name, header, rows):
    with gzip.open(OUT / f"{name}.csv.gz", "wt", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print(f"{name}: {len(rows)} rows")


write("heldout_tickets", ["ID", "TRUE_CATEGORY", "BODY"], [[i + 1, c, b] for i, (c, b) in enumerate(H.HELDOUT_TICKETS)])
write("heldout_logs", ["ID", "TRUE_CLASS", "LINE"], [[i + 1, c, l] for i, (c, l) in enumerate(H.HELDOUT_LOGS)])
write("heldout_queries", ["ID", "FAMILY", "Q"], [[i + 1, f, q] for i, (f, q) in enumerate(H.HELDOUT_QUERIES)])
