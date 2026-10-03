# Phase 0 – Recherchebericht

Stand: 2026-10-03 · Status: **erste Rechercherunde abgeschlossen, nicht vollständig**

Dieser Bericht fasst zusammen, was über die chinesische Woniu-Version von
航海世纪 (Voyage Century) aus öffentlichen Quellen belegt ist. Die Einzelbefunde
mit Quelle und Confidence stehen maschinenlesbar in
[`../reconstruction_db/`](../reconstruction_db/). Bei Abweichungen gilt die Datenbank.

## 1. Methode und Einschränkungen

| Punkt | Stand |
|---|---|
| Recherchemittel | Websuche (chinesisch und englisch) |
| Direkter Seitenabruf | **blockiert** durch die Netzwerk-Policy der Arbeitsumgebung (vc.woniu.com, baike.baidu.com, wikipedia.org, fandom.com) |
| Folge | Alle Befunde stammen aus Suchmaschinen-Auszügen. Keine Quelle wurde im Volltext gelesen. |
| Confidence | Deshalb ist **kein einziger Datensatz CONFIRMED**. Höchststufe ist LIKELY. |
| Videos und Screenshots | nicht ausgewertet (kein Zugriff), Priorität-3-Quellen fehlen komplett |
| Bereitgestellte Dateien | keine vorhanden |

Ergebnis: 97 Datensätze aus 28 Quellen, davon 58 LIKELY, 36 UNCERTAIN, 3 UNKNOWN.
Validierung: `python3 tools/validate_reconstruction_db.py`.

### Confidence-Regeln

| Stufe | Bedingung |
|---|---|
| CONFIRMED | Priorität-1- oder -2-Quelle **direkt gelesen** (vom Validator erzwungen) |
| LIKELY | Priorität-2-Quelle als Auszug, oder zwei unabhängige Quellen stimmen überein |
| UNCERTAIN | Einzelquelle Priorität 3–5, unklare Zuordnung oder Vermischungsgefahr |
| UNKNOWN | keine Quelle; Wert bleibt leer und wird nicht erfunden |

### Warnung: Verwechslungsgefahr mit anderen Spielen

Viele chinesische Suchtreffer betreffen **andere** Seefahrtsspiele:
大航海时代 Online (Koei, "Uncharted Waters Online"), 大航海时代 Origin,
航海纪元, 大航海家OL und 小小航海士. Deren Systeme (z. B. 副官, Schiffs-Neubau,
Seegebiets-Einteilung) ähneln sich, sind aber **nicht** Teil von 航海世纪.
Befunde mit diesem Risiko sind in der Datenbank als UNCERTAIN markiert und
in den notes vermerkt (z. B. `REGION-LIST-17173`, `SYS-OFFICER-CARDS`).

## 2. Kernbefunde

### 2.1 Spiel

* 3D-MMORPG von 蜗牛 / Snail Games (Woniu), international von IGG als
  *Voyage Century Online* betrieben. Setting: Seefahrt und Kolonialzeit
  (16. Jh.), reale Weltkarte ("五大洲七大洋"). `GAME-VC` LIKELY
* 2026 weiterhin in Betrieb (Event-News 2026-09, Forenbereich zum 20. Jubiläum).
* Beworbene Kernfeatures: Land- und Seekampf, **Stadtbelagerung**,
  Echtzeit-Seeschlachten mit "hunderten" Schiffen, Schiffsumbau,
  Matrosen-Anwerbung, historische Story-Missionen.
* Startdatum widersprüchlich (`CONTRA-001`).

### 2.2 Charakter und Berufe

Fünf Berufe (职业), wählbar bei Spielbeginn, später wechselbar (转职, UNCERTAIN):

| Beruf | See | Land | Confidence |
|---|---|---|---|
| 皇家军官 Königlicher Offizier | gesamter Kanonen-Zweig | Schwert | LIKELY |
| 帝国禁卫军 Kaiserliche Garde | Entern | Klinge, Schwert, Axt; schwere Rüstung | LIKELY |
| 加勒比海盗 Karibik-Pirat | Nahkanonen, Enterhaken, Rammen | Klinge, Axt | LIKELY |
| 宝藏猎人 Schatzjäger | Fernbeschuss, Minen, Rammen | Schusswaffen | UNCERTAIN |
| 武装商人 Bewaffneter Händler | Reparatur, Schiffsverstärkung, Matrosen heilen | Schusswaffen, Heilung, Support | LIKELY |

Daneben gibt es einen **Militärrang 军阶** (mind. Rang 8 über die Hauptquest),
dessen Wirkung UNKNOWN ist.

### 2.3 Level

| Stand | Wert | Confidence |
|---|---|---|
| international, früh | Berufsstufe max. 120, je Stufe +10 HP / +5 SP | UNCERTAIN |
| CN ab 2011-07-05 (Addon 暴风岛疑云) | Berufsstufe 160 | LIKELY |
| CN später | Sets auf Stufe 168, Quest-Set "170" → Cap ≥ 168 | LIKELY |
| CN 2026 | Ausrüstung "230" in Event-News | UNCERTAIN |
| aktuelles Cap | — | **UNKNOWN** |
| XP-Kurve | — | **UNKNOWN** |

Das Projektziel 230 ist plausibel, aber **nicht belegt** (`CONTRA-002`).

### 2.4 Skills

* **17 Skills**: Navigation, Seekampf, Rhetorik, Schwert, Klinge, Axt,
  Schusswaffen, Medizin, Unbewaffnet, Bergbau, Holzfällerei, Landwirtschaft,
  Fischen, Schmieden, Schneiderei, Alchemie, Schiffbau. LIKELY
* Originale Einteilung in **4 Kategorien**: 战斗系 Kampf, 贸易系 Handel,
  采集系 Sammeln, 生产系 Herstellung. LIKELY
* **Drei Skillstufen**: Grundstufe bis 31, zweite Stufe bis 100, dritte Stufe bis 120. LIKELY
* **Gesamtsumme aller Skillstufen max. 1700** (= 17 × 100) → Spezialisierungszwang. LIKELY
* Navigation bestimmt nutzbare Schiffstypen und Spezialfähigkeiten.
* Schiffbau stellt **Panzerung und Galionsfiguren** her, aber **keine Schiffe**.

### 2.5 Schiffe

* Drei Klassen, die den drei Umbaurichtungen entsprechen:

  | Klasse | Profil | Umbau-Attribut | Steigt auf durch |
  |---|---|---|---|
  | 战船 Kriegsschiff | meiste Kanonen, meiste HP | 武装 Bewaffnung: Kanonenplätze | Schlachtfeld-Kämpfe (intl.) |
  | 探险船 Erkundungsschiff | schnellstes, meiste Matrosen | 机动 Mobilität: Matrosen, Tempo, Vortrieb | Erkundung (intl.) |
  | 商船 Handelsschiff | langsamstes, größter Laderaum | 构造 Struktur: Haltbarkeit, Ladung | Handel (intl.) |

* Schiffe gibt es nur beim NPC 船老板 (Werftmeister).
* Jedes Schiff hat drei **Schiffs-Skills** (Bewaffnung, Mobilität, Struktur),
  die für höhere Schiffsstufen bestimmte Werte erreichen müssen (intl.).
* **Schiffsumbau 1–14**, Kosten steigen, Voraussetzungen Stufe + Material + Geld.
  Umbau-Städte (Stand 2005): 1 Athen, 2 Genua, 3–4 Algier, 5–6 Sevilla,
  7–8 Hamburg, 9 Maskat, 10 Zhigu (Tianjin) und Seoul. 11–14 UNKNOWN.
* **Galionsfiguren** mit drei Elementen: Wasser (Haltbarkeit, Ladung),
  Feuer (Kanonenplätze), Wind (Tempo, Matrosen).
* **Matrosen** sind gesund, verletzt oder tot; mehr Matrosen = schneller,
  aber mehr Proviantverbrauch.
* **Alle Einzelwerte (HP, Tempo, Ladung, Kanonen …) sind UNKNOWN.** Kein
  einziger Schiffsname ist belegt.

### 2.6 Welt

* Belegte Städte (LIKELY): London, Athen, Genua, Sevilla, Hamburg, Seoul, Quanzhou.
* Weitere (UNCERTAIN): Algier, Maskat, Zhigu sowie eine Liste von 21 Häfen
  von Amsterdam bis Taiwan. Amerika fehlt in allen Listen.
* Quellkoordinaten werden unverändert übernommen (`N38E23` usw.).

### 2.7 Ausrüstung und Verfeinerung

* Sets (LIKELY): 国王 148, 西多尼亚 150, 托马斯 155 (Schaden), 塔洛斯 168 (Schaden).
* **Ausrüstungs-Synthese** (装备合成) als Herstellungsweg für Sets.
* **Sockeln** (打孔镶嵌): bis zu 3 Sockel beobachtet, ein Attribut pro Sockel. LIKELY
* **Verfeinerung** (精炼) mit Stein + Edelstein, aufsteigende Steinstufen. UNCERTAIN
* Item-Seltenheitsstufen: UNKNOWN.

### 2.8 Inhalte, Gilden, PvP

* Dungeons: See-Dungeon 波托洛维海湾 (ca. 2010), 暴风岛 (2011), 黄金塔 (Art unbekannt).
* Gilden: Gründung mit Name und Banner; Gildenoffiziere können **Städte kaufen
  und besetzen** und erhalten Verwaltungsrechte. Gildenquests existieren.
* Stadtbelagerung und große Seeschlachten sind Kernfeatures; **Regeln UNKNOWN**.
* Offizierssystem 副官 über **Offizierskarten**, Tauschhändler in London. UNCERTAIN

## 3. Abgleich mit dem Master-Prompt

| Vorgabe im Master-Prompt | Befund | Konsequenz |
|---|---|---|
| Skills: Kampf / Seefahrt / Berufe | Original: 4 Kategorien | Originalkategorie als Daten, Prompt-Gruppen nur als UI (`CONTRA-005`) |
| Spieler betreiben Schiffbau | Schiffbau stellt nur Teile her | Schiffe nur beim Werftmeister; Schiffbau-Skill für Panzerung und Galionsfiguren |
| Offiziersrollen Captain, Navigator … | nicht belegt | Rollen bleiben Designplatzhalter |
| Seltenheit Common … Endgame | nicht belegt | Designentscheidung, als solche markiert |
| Level-Cap 230 | ≥ 168 belegt, 230 nur Indiz | Datenmodell ohne festes Cap; Cap kommt aus `level_table` |
| Segelphysik mit Wind, Strömung, Wellen | nicht belegt | eigenes Design, Werte erst nach Videoanalyse |
| Feuer, Lecks, Segelschaden | nicht belegt | als optionale Schadenskanäle modellieren |
| Militärrang, Offizierskarten, Galionsfiguren, Matrosenzustände, Gesamt-Skillcap | im Prompt **nicht** enthalten | ergänzen, da im Original belegt |

## 4. Widersprüche

| ID | Thema | Kurzfassung |
|---|---|---|
| CONTRA-001 | Startdatum | 2005-12-08 gegen 9. Jubiläum 2013 |
| CONTRA-002 | Level-Cap | 120 → 160 → ≥168 → 230? (Zeitstände) |
| CONTRA-003 | Schiffsstufen | 10 Stufen (intl.) gegen Umbau 1–14 (CN) |
| CONTRA-004 | Berufsnamen | 帝国禁卫军/帝国卫士, 宝藏猎人/寻宝人 |
| CONTRA-005 | Skill-Gruppen | Original gegen Prompt (gelöst: Original = Daten) |

## 5. Offene Fragen nach Priorität

1. **Aktuelles Level-Cap** und XP-Tabelle.
2. **Schiffsliste** mit Werten je Klasse und Stufe (offizielle Seite `SRC-002`).
3. Ablauf von **Stadtbelagerung** und **Seeschlachtfeld** (Zeitplan, Teilnehmer, Siegbedingung, Belohnung).
4. Steuerung und **Segelmodell**: Gibt es Wind? Wie schnell drehen Schiffe? Gibt es Breitseiten-Winkel?
5. **Handelssystem**: Warenliste, Preisbildung, Steuern, Einfluss von Rhetorik.
6. **Offiziere**: Rollen, Werte, Bezugsquellen.
7. **Attribute** des Charakters (Namen und Wirkung).
8. Übergang **Stadt ↔ See ↔ Land**: nahtlos oder mit Ladebildschirm.
9. HUD-Layout (nur über Screenshots lösbar).
10. Militärrang: Wirkung und Obergrenze.

## 6. Was als Nächstes am meisten hilft

| Beitrag | Klärt |
|---|---|
| Netzwerkfreigabe für vc.woniu.com, baike.baidu.com, tieba.baidu.com, bilibili.com | Volltext der Priorität-2/4-Quellen, erste CONFIRMED-Einträge |
| Screenshots: Charakterfenster, Skillfenster, Schiffsfenster, Werft, Weltkarte, HUD auf See und an Land | Fragen 1, 2, 4, 7, 9 |
| Gameplay-Videos (Bilibili) von Seeschlacht und Stadtbelagerung | Fragen 3, 4, 8 |
| Clientdateien (falls rechtlich zulässig) | Tabellen für Items, Schiffe, Skills; Ablauf siehe [04_FILE_ANALYSIS_PROTOCOL.md](04_FILE_ANALYSIS_PROTOCOL.md) |

## 7. Quellen

Vollständiges Register mit Priorität und Zugriffsart:
[`../reconstruction_db/sources.json`](../reconstruction_db/sources.json).

* [航海世纪官方网站 – 暴风岛疑云 Update](http://vc.woniu.com/news/note/2011-07/04231210.html)
* [航海世纪官方网站 – 船只类型/船只装备](http://vc.woniu.com/2j/czzb_1.htm)
* [航海世纪官方网站 – 常见问题](http://vc.woniu.com/xsrm/cjwt.html)
* [航海世纪官方网站 – 装备合成](http://vc.woniu.com/jjzl/zbhc.html)
* [航海世纪官方网站](http://vc.woniu.com/)
* [航海世纪 – 维基百科](https://zh.wikipedia.org/zh-hans/%E8%88%AA%E6%B5%B7%E4%B8%96%E7%BA%AA)
* [航海世纪 – 百度百科](https://baike.baidu.com/item/%E8%88%AA%E6%B5%B7%E4%B8%96%E7%BA%AA/2116840)
* [航海中各种技能的介绍 – 新浪游戏](http://games.sina.com.cn/z/hhsj/2004-07-02/148339.shtml)
* [船只改造 – 新浪游戏](http://games.sina.com.cn/o/z/hhsj/2005-01-14/198481.shtml)
* [17173 航海世纪专区 – 地图](http://hhsj.17173.com/map/map3.htm)
* [17173 航海世纪专区 – Gilde](http://hhsj.17173.com/guide/47.htm)
* [17173 News 2026-09-21](https://news.17173.com/content/09212026/235608094.shtml)
* [Woniu-Forum – 伞兵新手攻略](http://bbs.woniu.com/forum.php?mod=viewthread&tid=2637265)
* [Woniu-Forum – 纯新手小白入门](https://pixark.bbs.woniu.com/forum.php?mod=viewthread&tid=2637225)
* [Woniu-Forum – 新手成老手一点建议](http://ml.bbs.woniu.com/forum.php?mod=viewthread&tid=2637205)
* [Tieba – 波托洛维海湾副本攻略](https://tieba.baidu.com/p/1391444399)
* [IGG – Profession Skills](http://vc.igg.com/getting/index.php?ac=10&aid=83)
* [IGG – Skills Learning](https://vc.igg.com/getting/index.php?ac=10&aid=93)
* [Voyage Century Wiki – Ship](https://voyagecentury.fandom.com/wiki/Ship)
* [Voyage Century Wiki – Ship-building](https://voyagecentury.fandom.com/wiki/Ship-building)
* [Codex Gamicus – Voyage Century Online](https://gamicus.fandom.com/wiki/Voyage_Century_Online)
* [Wikipedia – Voyage Century Online](https://en.wikipedia.org/wiki/Voyage_Century_Online)
* [19yxw – 九周年庆](https://m.19yxw.com/Article/2013-12-03/59828.html)
