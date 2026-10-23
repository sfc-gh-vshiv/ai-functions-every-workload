"""Generate 1-page synthetic invoice PDFs in three layouts, plus truth.csv.

Usage: python3 tools/make_invoices.py [count]   (default 200; needs reportlab)
"""
import csv
import random
import sys
from datetime import date, timedelta
from pathlib import Path

from reportlab.lib.pagesizes import LETTER
from reportlab.pdfgen import canvas

SEED = 20261022
OUT = Path(__file__).resolve().parent.parent / "data" / "invoices"
VENDORS = ["Northpeak Supply Co.", "Altura Logistics LLC", "Kestrel Office Goods", "Bramble & Finch Packaging",
           "Solace Facilities Inc.", "Cobalt Freight Partners", "Juniper Print Works", "Halcyon IT Services"]
ITEMS = [("Shipping cartons, 50 pack", 38.50), ("Pallet wrap, 6 rolls", 64.00), ("Toner cartridge", 129.99),
         ("Freight, zone 4", 412.00), ("Desk chairs", 245.00), ("Label printer rolls", 22.75),
         ("Network switch, 24 port", 389.00), ("Janitorial service, monthly", 980.00), ("Courier pickups", 15.00)]


def money(x):
    return f"${x:,.2f}"


def draw(path, layout, inv):
    c = canvas.Canvas(str(path), pagesize=LETTER)
    w, h = LETTER
    if layout == 0:  # classic: vendor top left, meta top right
        c.setFont("Helvetica-Bold", 18); c.drawString(50, h - 60, inv["vendor"])
        c.setFont("Helvetica", 10); c.drawString(50, h - 78, "1200 Commerce Way, Suite 4, Springfield")
        c.setFont("Helvetica-Bold", 22); c.drawRightString(w - 50, h - 60, "INVOICE")
        c.setFont("Helvetica", 11)
        c.drawRightString(w - 50, h - 82, f"Invoice No: {inv['invoice_no']}")
        c.drawRightString(w - 50, h - 98, f"Invoice Date: {inv['date']}")
        c.drawRightString(w - 50, h - 114, f"Due Date: {inv['due']}")
        y = h - 170
    elif layout == 1:  # banner: meta in a box, vendor in footer-style header
        c.setFillGray(0.9); c.rect(40, h - 130, w - 80, 90, fill=1, stroke=0); c.setFillGray(0)
        c.setFont("Helvetica-Bold", 16); c.drawString(55, h - 70, f"Tax Invoice #{inv['invoice_no']}")
        c.setFont("Helvetica", 11)
        c.drawString(55, h - 92, f"Issued {inv['date']}   |   Payment due {inv['due']}")
        c.drawString(55, h - 112, f"From: {inv['vendor']}")
        y = h - 180
    else:  # compact: two-column key/value block
        c.setFont("Helvetica-Bold", 14); c.drawString(50, h - 55, "Bill")
        c.setFont("Helvetica", 10)
        for k, (label, val) in enumerate([("Supplier", inv["vendor"]), ("Reference", inv["invoice_no"]),
                                          ("Date of issue", inv["date"]), ("Terms", "Net 30")]):
            c.drawString(50, h - 80 - 16 * k, label); c.drawString(170, h - 80 - 16 * k, val)
        y = h - 180
    c.setFont("Helvetica", 10); c.drawString(50, y + 24, "Bill to: Example Retail Co., 55 Market St, Portland, OR")
    c.setFont("Helvetica-Bold", 10)
    c.drawString(50, y, "Description"); c.drawRightString(400, y, "Qty"); c.drawRightString(480, y, "Unit"); c.drawRightString(w - 50, y, "Amount")
    c.setFont("Helvetica", 10)
    for desc, qty, unit in inv["lines"]:
        y -= 18
        c.drawString(50, y, desc); c.drawRightString(400, y, str(qty)); c.drawRightString(480, y, money(unit)); c.drawRightString(w - 50, y, money(qty * unit))
    y -= 30
    c.drawRightString(480, y, "Subtotal"); c.drawRightString(w - 50, y, money(inv["subtotal"]))
    c.drawRightString(480, y - 16, "Tax (8%)"); c.drawRightString(w - 50, y - 16, money(inv["tax"]))
    c.setFont("Helvetica-Bold", 12)
    c.drawRightString(480, y - 38, "Total due" if layout != 2 else "Amount payable"); c.drawRightString(w - 50, y - 38, money(inv["total"]))
    c.setFont("Helvetica", 8); c.drawString(50, 40, "Synthetic invoice for a public demo. Not a real business document.")
    c.showPage(); c.save()


def main():
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 200
    r = random.Random(SEED)
    OUT.mkdir(parents=True, exist_ok=True)
    truth = []
    for i in range(count):
        d = date(2026, 9, 1) + timedelta(days=r.randint(0, 45))
        lines = [(desc, r.randint(1, 12), unit) for desc, unit in r.sample(ITEMS, r.randint(2, 5))]
        sub = round(sum(q * u for _, q, u in lines), 2)
        tax = round(sub * 0.08, 2)
        inv = {"vendor": r.choice(VENDORS), "invoice_no": f"INV-{r.randint(20000, 89999)}",
               "date": d.isoformat(), "due": (d + timedelta(days=30)).isoformat(),
               "lines": lines, "subtotal": sub, "tax": tax, "total": round(sub + tax, 2)}
        name = f"invoice_{i + 1:04d}.pdf"
        draw(OUT / name, i % 3, inv)
        truth.append([name, i % 3, inv["vendor"], inv["invoice_no"], inv["date"], f"{inv['total']:.2f}"])
    with open(OUT / "truth.csv", "w", newline="") as f:
        w = csv.writer(f); w.writerow(["FILE", "LAYOUT", "VENDOR", "INVOICE_NO", "INVOICE_DATE", "TOTAL"]); w.writerows(truth)
    print(f"{count} invoices -> {OUT}")


if __name__ == "__main__":
    main()
