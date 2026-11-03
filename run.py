"""
run.py - runs every query in queries.sql against churn.db and prints the results.

Usage:  python run.py          (runs all queries)
        python run.py Q7       (runs only the query whose title starts with Q7)
"""
import sqlite3
import sys

con = sqlite3.connect("churn.db")
only = sys.argv[1].upper() + ":" if len(sys.argv) > 1 else None

# Read queries.sql line by line. Comment lines (--) are collected for the title.
# A statement ends at a line whose last character is ';' (comments are ignored when looking for it).
queries = []
comments, sql_lines = [], []
for line in open("queries.sql", encoding="utf-8"):
    stripped = line.strip()
    if stripped.startswith("--"):
        comments.append(stripped.lstrip("- ").strip())
    elif stripped:
        sql_lines.append(stripped)
        if stripped.endswith(";"):
            title = next((c for c in comments if c.startswith("Q")), "(untitled)")
            queries.append((title, " ".join(sql_lines)))
            comments, sql_lines = [], []

for title, sql in queries:
    if only and not title.upper().startswith(only):
        continue
    cur = con.execute(sql)
    cols = [d[0] for d in cur.description]
    rows = cur.fetchall()
    widths = [max(len(str(x)) for x in [c] + [r[i] for r in rows]) for i, c in enumerate(cols)]

    print("\n" + title)
    print("  ".join(c.ljust(w) for c, w in zip(cols, widths)))
    print("  ".join("-" * w for w in widths))
    for r in rows:
        print("  ".join(str(v).ljust(w) for v, w in zip(r, widths)))

con.close()
