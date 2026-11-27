"""一問一答データ(JSON)と検証シート(PDF)を生成する。使い方: python3 content/build.py fin"""
import sys, json, html, subprocess, pathlib, importlib
ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "content"))
SUBJ = {"fin": "財務・会計"}
sid = sys.argv[1]
Q = importlib.import_module(f"{sid}_questions").Q
items = []
for i, (topic, diff, q, c, a, e) in enumerate(Q, 1):
    tf = c == "tf"
    items.append({"id": f"{sid}-{i:03d}", "subject": sid, "topic": topic, "level": diff,
                  "type": "tf" if tf else "mc4", "question": q,
                  "choices": ["○", "×"] if tf else c, "answer": a, "explanation": e})
(ROOT / "app/assets/questions" / f"{sid}.json").write_text(json.dumps(items, ensure_ascii=False, indent=1), encoding="utf-8")

h = lambda s: html.escape(str(s))
rows = []
for it in items:
    ch = "".join(f'<div class="{"ok" if k == it["answer"] else ""}">{"ABCD"[k] + ". " if it["type"]=="mc4" else ""}{h(c)}</div>' for k, c in enumerate(it["choices"]))
    rows.append(f'<tr><td class="id">{it["id"]}<br><span>{h(it["topic"])}</span><br><span>難{"★"*it["level"]}</span></td>'
                f'<td><b>{h(it["question"])}</b><div class="ch">{ch}</div><div class="ex">解説：{h(it["explanation"])}</div></td>'
                f'<td class="chk">□OK<br>□要修正</td></tr>')
doc = f"""<!doctype html><html lang="ja"><head><meta charset="utf-8"><style>
@page{{size:A4;margin:12mm}} body{{font-family:"IPAGothic",sans-serif;font-size:9pt;color:#1d2340;line-height:1.55}}
h1{{font-size:15pt;margin:0 0 2mm}} p{{margin:0 0 3mm}}
table{{border-collapse:collapse;width:100%}} tr{{page-break-inside:avoid}}
td{{border:1px solid #b8bde0;padding:2mm;vertical-align:top}}
td.id{{width:22mm;font-size:8pt;font-weight:bold}} td.id span{{font-weight:normal;color:#555c80}}
td.chk{{width:16mm;font-size:8pt;color:#555c80}}
.ch{{margin:1.5mm 0;display:grid;grid-template-columns:1fr 1fr;gap:0.5mm 4mm}} .ch .ok{{font-weight:bold;color:#0a7a2f}} .ch .ok::after{{content:" ← 正解"}}
.ex{{color:#444;font-size:8.5pt;border-left:2px solid #f2c14e;padding-left:2mm}}
</style></head><body><h1>一問一答 検証シート：{SUBJ[sid]}（{len(items)}問）</h1>
<p>Claudeが作成したオリジナル問題です。正解（緑字）と解説が正しいか確認し、誤りがあれば「問題ID＋どこが違うか」をチャットで送ってください。アプリでは選択肢の並び順を毎回シャッフルします。</p>
<table>{''.join(rows)}</table></body></html>"""
out = ROOT / "docs" / f"verify_{sid}.html"
out.write_text(doc, encoding="utf-8")
pdf = ROOT / "docs" / f"検証シート_{SUBJ[sid].replace('・','')}.pdf"
subprocess.run(["node", "-e", f"""const {{chromium}}=require('playwright');(async()=>{{const b=await chromium.launch();const p=await b.newPage();await p.goto('file://{out}');await p.pdf({{path:'{pdf}',format:'A4',displayHeaderFooter:true,headerTemplate:'<div></div>',footerTemplate:'<div style="font-size:7px;width:100%;text-align:center;color:#888"><span class=pageNumber></span>/<span class=totalPages></span></div>',margin:{{top:'12mm',bottom:'14mm',left:'12mm',right:'12mm'}}}});await b.close()}})()"""], check=True)
out.unlink()
print("ok", len(items), pdf)
