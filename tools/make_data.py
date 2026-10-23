"""Generate the synthetic tables for the ten workloads, with planted ground truth.

Seeded, so every run produces the same rows. Output: data/csv/*.csv.gz
Usage: python3 tools/make_data.py
"""
import csv
import gzip
import json
import random
from datetime import datetime, timedelta
from pathlib import Path

import phrases as P

SEED = 20261022
N = 10_000
N_NEW_TICKETS = 200
OUT = Path(__file__).resolve().parent.parent / "data" / "csv"
T0 = datetime(2026, 10, 1, 8, 0, 0)


def write(name, header, rows):
    OUT.mkdir(parents=True, exist_ok=True)
    with gzip.open(OUT / f"{name}.csv.gz", "wt", newline="", encoding="utf-8") as f:
        w = csv.writer(f, quoting=csv.QUOTE_ALL)
        w.writerow(header)
        w.writerows(rows)
    print(f"{name:16s} {len(rows):>6,} rows")


def order_id(r):
    return f"A-{r.randint(100000, 999999)}"


def fill(r, s):
    return s.format(order=order_id(r), product=r.choice(P.PRODUCTS))


def ticket_body(r, cat, second=None):
    parts = [r.choice(P.OPENERS), fill(r, r.choice(P.TICKET_CATEGORIES[cat]))]
    if second:
        parts.append("Also, " + fill(r, r.choice(P.TICKET_CATEGORIES[second])).lower())
    parts += [r.choice(P.DETAILS), r.choice(P.CLOSERS)]
    return " ".join(p for p in parts if p)


def tickets(r, n, id0, t0):
    cats = list(P.TICKET_CATEGORIES)
    weights = [24, 22, 18, 14, 16, 6]  # safety is rare, as in real queues
    rows = []
    for i in range(n):
        cat = r.choices(cats, weights)[0]
        second = None
        if r.random() < 0.10:  # 10% mention two topics
            second = r.choice([c for c in cats if c != cat])
        ts = t0 + timedelta(minutes=3 * i + r.randint(0, 2))
        rows.append([id0 + i, ts.isoformat(sep=" "), ticket_body(r, cat, second), cat, second or ""])
    return rows


def reviews(r):
    complaint_of = {p: P.COMPLAINTS[i % len(P.COMPLAINTS)] for i, p in enumerate(P.REVIEW_PRODUCTS)}
    rows = []
    for i in range(N):
        prod = r.choice(P.REVIEW_PRODUCTS)
        top_key, top_text = complaint_of[prod]
        # 60% of complaints about a product name its planted top complaint
        ckey, ctext = (top_key, top_text) if r.random() < 0.6 else r.choice(P.COMPLAINTS)
        tone = r.choices(["pos", "neg", "mixed"], [55, 30, 15])[0]
        if tone == "pos":
            body, stars = r.choice(P.POS_TEMPLATES).format(p=r.choice(P.PRAISE)), r.choice([4, 5])
            ckey = ""
        elif tone == "neg":
            body, stars = r.choice(P.NEG_TEMPLATES).format(c=ctext), r.choice([1, 2])
        else:
            body = r.choice(P.MIXED_TEMPLATES).format(p=r.choice(P.PRAISE), p2=r.choice(P.PRAISE), c=ctext)
            stars = 3
        contradiction = False
        if tone != "mixed" and r.random() < 0.05:  # 5%: stars say the opposite of the text
            stars = 1 if tone == "pos" else 5
            contradiction = True
        rows.append([i + 1, prod, stars, body, contradiction, ckey, top_key])
    return rows


def person(r):
    first, last = r.choice(P.FIRST), r.choice(P.LAST)
    city, st, z = r.choice(P.CITIES)
    return {
        "name": f"{first} {last}",
        "phone": f"(503) 555-01{r.randint(0, 99):02d}",
        "email": f"{first.lower()}.{last.lower()}@example.com",
        "address": f"{r.randint(100, 9899)} {r.choice(P.STREETS)}, {city}, {st} {z}",
    }


def notes(r):
    rows = []
    for i in range(N):
        if r.random() < 0.40:
            p = person(r)
            tpl = r.choice(P.NOTE_PII)
            text = tpl.format(**p)
            planted = [p[k] for k in ("name", "phone", "email", "address") if "{" + k + "}" in tpl]
            rows.append([i + 1, text, True, json.dumps(planted)])
        else:
            rows.append([i + 1, r.choice(P.NOTE_CLEAN), False, "[]"])
    return rows


def ip(r):
    return f"{r.choice(['192.0.2', '198.51.100', '203.0.113'])}.{r.randint(1, 254)}"


def logs(r):
    rows = []
    for i in range(N):
        x = r.random()
        cls, bank = ("incident", P.LOG_INCIDENT) if x < 0.03 else ("error", P.LOG_ERROR) if x < 0.15 else ("routine", P.LOG_ROUTINE)
        line = r.choice(bank).format(
            user=f"u{r.randint(1000, 9999)}", ip=ip(r), n=r.randint(10000, 99999), ms=r.randint(20, 9000),
            s=r.randint(1, 600), w=r.randint(1, 40), a=r.randint(2, 5), k=r.randint(40, 400),
        )
        ts = T0 + timedelta(seconds=17 * i)
        rows.append([i + 1, ts.isoformat(sep=" "), line, cls])
    return rows


def products(r):
    rows = []
    for i in range(N):
        fam, desc, feats = r.choice(P.PRODUCT_FAMILIES)
        f2 = r.sample(feats, 2)
        text = (f"{r.choice(P.ADJ).capitalize()} {desc} from {r.choice(['Northpeak', 'Altura', 'Kestrel', 'Bramble', 'Solace'])}. "
                f"Highlights: {f2[0]} and {f2[1]}. {r.choice(['Ships in 2 days.', 'One-year warranty.', 'Gift ready.', 'New for this season.'])}")
        rows.append([i + 1, fam, text])
    return rows


def foreign(r):
    langs = list(P.TRANSLATIONS)
    rows = []
    for i in range(N):
        lang = r.choice(langs)
        tpl, cat = r.choice(P.TRANSLATIONS[lang])
        order = order_id(r)
        body = tpl.format(order=order, product=r.choice(P.PRODUCTS))
        rows.append([i + 1, lang, body, cat, order if "{order}" in tpl else ""])
    return rows


def main():
    r = random.Random(SEED)
    write("tickets", ["ID", "CREATED_AT", "BODY", "TRUE_CATEGORY", "ALT_CATEGORY"], tickets(r, N, 1, T0))
    write("tickets_new", ["ID", "CREATED_AT", "BODY", "TRUE_CATEGORY", "ALT_CATEGORY"],
          tickets(r, N_NEW_TICKETS, N + 1, T0 + timedelta(days=30)))
    write("reviews", ["ID", "PRODUCT", "STARS", "BODY", "TRUE_CONTRADICTION", "COMPLAINT_KEY", "TOP_COMPLAINT_KEY"], reviews(r))
    write("notes", ["ID", "NOTE", "HAS_PII", "PLANTED_PII"], notes(r))
    write("logs", ["ID", "TS", "LINE", "TRUE_CLASS"], logs(r))
    write("products", ["ID", "FAMILY", "DESCRIPTION"], products(r))
    write("foreign_tickets", ["ID", "LANG", "BODY", "TRUE_CATEGORY", "ORDER_REF"], foreign(r))


if __name__ == "__main__":
    main()
