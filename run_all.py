import sqlite3, re

con = sqlite3.connect("churn.db")
out = []
label, buf = "", []

for line in open("queries.sql", encoding="utf-8"):
    s = line.strip()
    m = re.match(r"-- (Q\d+:.*)", s)
    if m:
        label = m.group(1)
    if s.startswith("--"):
        continue
    buf.append(line)
    if s.endswith(";"):
        sql = "".join(buf)
        buf = []
        cur = con.execute(sql)
        cols = [d[0] for d in cur.description]
        out.append("\n=== " + label + " ===")
        out.append(" | ".join(cols))
        for row in cur.fetchall():
            out.append(" | ".join(str(v) for v in row))

text = "\n".join(out)
print(text)
open("results.txt", "w", encoding="utf-8").write(text)
