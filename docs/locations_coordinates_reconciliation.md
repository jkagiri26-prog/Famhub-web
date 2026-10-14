# core.locations Coordinate Reconciliation Report

**Date:** 2026-10-13
**Project:** FAMHUB (`erbxiqdfjmqnoeyjupru`) — Kenya `core.locations` GPS/PostGIS backfill
**Status:** **Applied and validated — complete.** First backfill (`docs/locations_coordinates_updates.sql`, 2026-10-13): 1,466 rows. Second backfill (remaining 8 wards, 2026-10-14): 8 rows via alternative IEBC/polygon sources (§5.4). All 1,451 Kenya wards now have coordinates; zero gps/geometry mismatches. SQL retained in `docs/` as the audit record and safe to re-run (idempotent no-op).

## 1. Sources

| Level | Source | Records |
|---|---|---|
| Sub-county | Open Admin Data Kenya — `https://openadmindata.org/api/v1/ke/subcounty.json` | 290 |
| Ward | `docs/locations_wards_seed_data.md` (remote commit `c690eb1d`) | 1,450 |

Existing DB coordinates were verified to be **byte-identical to this same source** (spot-checked Changamwe, Nyali, Kajiado North, Mt. Elgon, Westlands, Mathare), confirming the backfill continues a prior partial load of the same data.

## 2. Starting state (Kenya, `core.locations`)

| Level | Total | With coords | Missing |
|---|---|---|---|
| County | 47 | 47 | 0 |
| Sub-county | 298 | 258 | **40** |
| Ward | 1,451 | 1 (`MAHIGA`, code 483) | **1,450** |

`gps` (text `"lat, lon"`) and `geometry` (WKB, SRID 4326) are always both present or both absent. Existing non-null coordinates are never overwritten (`WHERE gps IS NULL` guard).

## 3. Method

**Sub-counties** — hierarchy + normalized-name + code cross-check. Pure code-based matching was proven **unsafe**: of the 40 missing rows, 32 share a code with a source record but several code-matches point at genuinely different entities (DB `GARISSA TOWNSHIP` vs source `Dujis` at code 27; Kajiado East/West codes swapped in the source; DB `MWINGI CENTRAL` vs source `Mwingi East` at code 69). Each of the 40 was classified against its sibling rows in the same county. The DB uses a recognizable `NAME(HQ/DIVISION)` pattern (`SAMIA(FUNYULA)`, `KIRINYAGA EAST(GICHUGU)`, `TRANSMARA WEST (KILGORIS)`), which resolved most alias cases.

**Wards** — per-ward matching inside the mapped parent sub-county, with these ordered passes (first unique hit wins):

1. `exact` — normalized name (NFKD, strip accents/punctuation, collapse spaces)
2. `wordbag` — same word multiset (word reorder: `KISUMU NORTH` ↔ `North Kisumu`)
3. `wordsubset` — one name's words contained in the other (`TOWNSHIP` ↔ `Thika Township`, `WAA` ↔ `Waa Ngombeni`)
4. `fuzzy-subset` / `wordfuzzy` — per-word Levenshtein ≤ 1–2 (`MACKINNON ROAD` ↔ `Mackinon Road`, `KAGAARI SOUTH` ↔ `Kaagari South`)
5. `lev` — whole-name Levenshtein ≤ 2
6. **county-wide fallback** — passes 1–5 repeated across *all* source wards of the same county when the parent mapping fails. Needed because the source scrambles sub-county groupings in places (source `Ndia` holds Mwea East's wards; source `West Mugirango` holds North Mugirango's wards; source `Kandara` holds Maragwa's wards). Requiring a unique county-wide name match keeps this safe.

Duplicate claims (two DB wards → one source ward) are demoted to *ambiguous*. All coordinates are bounds-checked against Kenya (`-5.0…5.6` lat, `33.0…42.0` lon).

## 4. Sub-county results — 24 matched, 16 flagged

### 4.1 Matched (24)

| DB code | DB name | Source name | Source id | lat, lon | Basis |
|---|---|---|---|---|---|
| 27 | GARISSA TOWNSHIP | Dujis | KE007027 | -0.426, 39.759 | ward-set validated (see §6) |
| 35 | TALBAJ | Tarbaj | KE008035 | 2.379, 40.251 | typo (L/R) |
| 49 | ISIOLO N. (TOWN) | Isiolo North | KE011049 | 1.441, 38.729 | HQ-qualifier alias |
| 50 | ISIOLO S.(GARBATULLA) | Isiolo South | KE011050 | 0.562, 38.453 | HQ-qualifier alias |
| 58 | IMENTI CENTRAL | Cental Imenti | KE012058 | 0.042, 37.517 | word order + source typo |
| 65 | MBEERE SOUTH | Gachoka | KE014065 | -0.727, 37.705 | known rename (HQ) |
| 66 | MBEERE NORTH | Siakago | KE014066 | -0.504, 37.791 | known rename (HQ) |
| 69 | MWINGI CENTRAL | Mwingi East | KE015069 | -0.926, 38.469 | name variant; no real "Mwingi Central" exists |
| 92 | OL JORO OROK | Ol Jorok | KE018092 | -0.178, 36.259 | typo (both = Ol Jorók) |
| 98 | MUKURWE-INI | Mukurweni | KE019098 | -0.578, 37.072 | spelling variant |
| 101 | KIRINYAGA EAST(GICHUGU) | Gichugu | KE020101 | -0.375, 37.342 | HQ parenthetical = source name |
| 102 | KIRINYAGA WEST(NDIA) | Ndia | KE020102 | -0.468, 37.199 | HQ parenthetical = source name |
| 117 | KIAMBU TOWN | Kiambu | KE022117 | -1.158, 36.847 | rename (Town suffix) |
| 133 | SAMBURU CENTRAL | Samburu West | KE025133 | 1.091, 36.605 | division name in constituency slot |
| 177 | TRANSMARA WEST (KILGORIS) | Kilgoris | KE033177 | -1.222, 34.863 | HQ parenthetical = source name |
| 178 | TRANSMARA EAST(EMURUA DIKIRR) | Emurua Dikirr | KE033178 | -1.005, 35.112 | HQ parenthetical = source name |
| 185 | KAJIADO EAST | Kajiado East | KE034186 | -1.892, 37.086 | exact name; source code is 186 (code-swap avoided) |
| 186 | KAJIADO WEST | Kajiado West | KE034185 | -1.696, 36.446 | exact name; source code is 185 (code-swap avoided) |
| 191 | BURETI | Buret | KE035191 | -0.559, 35.125 | typo (extra I) |
| 230 | SAMIA(FUNYULA) | Funyula | KE040230 | 0.244, 34.065 | HQ parenthetical = source name |
| 249 | HOMA BAY TOWN | Homa Bay | KE043249 | -0.521, 34.469 | rename (Town suffix) |
| 270 | KITUTU MASABA(MANGA) | Kitutu Masaba | KE046270 | -0.689, 34.915 | HQ parenthetical + base name |
| 271 | NYAMIRA SOUTH(WEST MUGIRANGO) | West Mugirango | KE046271 | -0.572, 34.911 | HQ parenthetical = source name |
| 272 | NYAMIRA NORTH(N.MUGIRANGO) | North Mugirango | KE046272 | -0.503, 34.982 | HQ parenthetical = source name |

### 4.2 Flagged, not updated (16)

All are split/renamed groups where the **sub-county centroid cannot be assigned confidently** — but their wards were matched individually where the source has them (so ward-level coverage is preserved).

| DB code | DB name | Reason |
|---|---|---|
| 60 | MAARA(MWIMBI) | Tharaka Nithi: DB has 6 sub-counties (Maara×2, Chuka, Igambang'ombe, Tharaka N/S); source has 3 unsplit (Nithi/Maara/Tharaka) with shifted names |
| 61 | CHUKA | same group (source slot 61 = "Maara") |
| 62 | THARAKA SOUTH | source "Tharaka" covers Tharaka South+North |
| 600 | MAARA(MUTHAMBI) | post-split; no source counterpart |
| 610 | IGAMBANG'OMBE | post-split; no source counterpart |
| 620 | THARAKA NORTH | post-split; no source counterpart |
| 95 | KIENI EAST | source "Kieni" unsplit covers Kieni East+West |
| 950 | KIENI WEST | post-split; no source counterpart |
| 96 | MATHIRA EAST | source "Mathira" unsplit covers Mathira East+West |
| 960 | MATHIRA WEST | post-split; no source counterpart |
| 100 | MWEA EAST | source "Mwea" carries only the Mwea **West** ward set |
| 1000 | MWEA WEST | post-split; wards matched via sibling parent |
| 275 | DAGORETTI NORTH | source has unsplit "Dagoretti" + a wardless "Kilimani" entry |
| 276 | DAGORETTI SOUTH | source "Dagoretti" covers Dagoretti N+S |
| 490 | ISIOLO N.(MERTI) | post-split beyond source's Isiolo North/South pair |
| 2700 | KITUTU MASABA(NORTH) | post-split; no source counterpart |

## 5. Ward results — 1,442 matched in first pass; all 1,451 wards now have coordinates (see §5.4)

| | Count | Share |
|---|---|---|
| DB wards needing coords | 1,450 | |
| **Uniquely matched → update** | **1,442** | **99.4%** |
| Ambiguous (not updated) | 2 | 0.1% |
| Unmatched (not updated) | 6 | 0.4% |
| Source wards unused | 8 | |

Match methods: `exact` 1,334 · `fuzzy-subset` 49 · `exact-county` 35 · `wordfuzzy` 11 · `wordsubset` 9 · `fuzzy-subset-county` 2 · `wordbag` 1 · `lev1` 1. Of these, **33 matched under a different sub-county parent than the DB's** (scrambled source groupings; each verified unique by name within the county).

### 5.1 Ambiguous (2) — DB duplicate — **resolved 2026-10-14**

`KIAMAIKO` existed **twice** under sub-county 290 (MATHARE), codes **1450** and **1452**, while IEBC has a single Kiamaiko ward (code 1450). Both rows were first assigned the same verified coordinates (§5.4); on 2026-10-14 the duplicate row **code 1452 was deleted** (verified: zero dependent rows across all 18 tables with `location_id`; guarded delete by code+name+parent+level). Code **1450 retained** (IEBC-authoritative code, coordinates `-1.2573, 36.8754`).

### 5.2 Unmatched (6) — absent or non-corresponding in source — **resolved 2026-10-14**

All six resolved via alternative authoritative datasets (IEBC register, mikelmaron/kenya-election-data IEBC polygons, geoBoundaries KEN ADM3, HDX COD-AB, OSM/Nominatim) — see §5.4:

| Code | Ward | Sub-county | Primary-source note |
|---|---|---|---|
| 216 | SALA | 44 LAFEY | IEBC register `044 LAFEY 0216 SALA`; polygon datasets mislabel slot 216 "Libehia" |
| 375 | NDITHINI | 75 MASINGA | IEBC/mikelmaron code 375 exact; source `Mananja` was the same place |
| 396 | MUTHWANI | 80 MAVOKO | IEBC/mikelmaron code 396 exact; source `Mathatani` was the same place |
| 401 | MACHAKOS CENTRAL | 81 MACHAKOS TOWN | IEBC/mikelmaron code 401 exact; source `Township` = same ward (old name) |
| 961 | KAPSUSER | 192 BELGUT | IEBC/mikelmaron code 961 exact; source `BELGUT` ward = same location |
| 1344 | KITUTU CENTRAL | 269 KITUTU CHACHE SOUTH | mikelmaron code 1344 exact incl. name spacing; source `Kisii Central` = same ward |

### 5.3 Source wards with no DB counterpart (8)

`Mathatani` (Masinga), `Township` (Machakos Town), `BELGUT` (Ainamoi), `Mananja` (Masinga), `Mahiga` (Othaya — DB already has coords), `Kisii Central` (Kitutu Chache South), `BULLA MPYA` (Mandera East), `Kiamaiko` (Mathare — resolved via the DB duplicate, §5.4). All eight were subsequently shown to be aliases/locations of DB wards already covered (or superseded by IEBC naming) — none represent additional missing wards.

### 5.4 Second backfill (2026-10-14) — remaining 8 wards resolved

Each match triangulated across ≥2 independent sources, validated inside the correct county/sub-county (HDX COD-AB polygons) and ward polygon; WGS84 (EPSG:4326); guarded by `gps IS NULL`.

| Code | Ward | Parent | lat, lon | Evidence | Confidence |
|---|---|---|---|---|---|
| 216 | SALA | LAFEY | 3.9361, 41.2803 | IEBC register (name+code); Sala village inside ward-216 polygon (mikelmaron + geoBoundaries, both mislabelled "Libehia"); inside HDX Lafey | High |
| 375 | NDITHINI | MASINGA | -0.8939, 37.3581 | mikelmaron `375 NDITHINI/ MASINGA` exact; geoBoundaries "Ndithini"; source "Mananja" same cluster; inside HDX Masinga | High |
| 396 | MUTHWANI | MAVOKO | -1.3591, 37.1139 | mikelmaron `396 MUTHWANI/ MAVOKO` exact; geoBoundaries "Muthwani"; source "Mathatani" same cluster; inside HDX Mavoko | High |
| 401 | MACHAKOS CENTRAL | MACHAKOS TOWN | -1.5073, 37.2805 | mikelmaron `401` exact; geoBoundaries; source "Township" alias confirmed; inside HDX Machakos Town | High |
| 961 | KAPSUSER | BELGUT | -0.3419, 35.2215 | mikelmaron `961 KAPSUSER/ BELGUT` exact; geoBoundaries "Kapsuser"; inside HDX Belgut | High |
| 1344 | KITUTU CENTRAL | KITUTU CHACHE SOUTH | -0.6545, 34.7549 | mikelmaron `1344 'KITUTU   CENTRAL'` exact (incl. spacing); geoBoundaries; source "Kisii Central" alias confirmed; inside HDX Kitutu Chache South | High |
| 1450 | KIAMAIKO | MATHARE | -1.2573, 36.8754 | mikelmaron `1450 KIAMAIKO/ MATHARE` exact; geoBoundaries; source "Kiamaiko"; 0.6 km from parent centroid | High |
| 1452 | KIAMAIKO | MATHARE | -1.2573, 36.8754 | DB duplicate of IEBC ward 1450 (no IEBC code 1452); same coordinates applied, then row deleted on dedup (2026-10-14) | High |

## 6. Notable findings

1. **Code-based matching is unsafe for sub-counties.** Kajiado East/West codes are swapped in the source relative to the DB; Garissa slot 27 is `Dujis` in the source but `GARISSA TOWNSHIP` in the DB; several DB names are HQ qualifiers rather than constituency names.
2. **Garissa resolved by ward evidence.** DB `GARISSA TOWNSHIP`'s wards (WABERI, GALBET, TOWNSHIP, IFTIN) are exactly the source `Dujis` ward set — the source entry carries Garissa-town wards under the old-boundaries name. Centroid `-0.426, 39.759` therefore describes the Garissa urban area; sub-county 27 was promoted from *flagged* to *matched*.
3. **Source sub-county→ward groupings are scrambled in places** (Ndia↔Mwea East, West↔North Mugirango, Kandara↔Maragwa, Nandi Hills↔Chesumei, Dagoretti/Kilimani). Ward names remain reliable, so the county-wide fallback reunited them; every such match is name-unique within its county.
4. **Split children carry disjoint ward sets.** Kieni East+West wards = source Kieni's 8 wards (4+4, disjoint); same pattern for Mathira, Tharaka, Isiolo — so wards under post-split sub-counties were matched via the sibling parent.
5. **Source data gaps:** `Mwea East` wards (Nyangati, Murinduko, Gathigiriri, Tebere) are absent from the source entirely; source `Kilimani` (KE047275) has a centroid but zero wards; source sub-county count (290) ≠ real Kenya (≈298 after 2013+ splits).

## 7. Validation performed

- Sub-county match set cross-checked against all 298 DB rows and 290 source rows (sibling/county context for each of the 40 missing).
- Every ward match is **unique** (no source ward claimed twice; DB duplicate names demoted).
- All coordinates bounds-checked within Kenya.
- `gps`/`geometry` consistency preserved (both set together; geometry = `Point(lon lat)` SRID 4326, matching existing rows).
- Existing non-null coordinates excluded (`gps IS NULL` guard) — the one pre-filled ward (`MAHIGA`) and 258 sub-counties untouched.
- SQL is a single transaction, idempotent (re-running affects 0 rows).

### 7.1 Post-apply results (2026-10-13, executed)

Applied via Supabase Management API (`POST /v1/projects/erbxiqdfjmqnoeyjupru/database/query`), HTTP 201.

| Check | Expected | Result |
|---|---|---|
| Rows updated (24 sub-counties + 1,442 wards) | 1,466 | **1,466** ✓ |
| Sub-county rows with coords | 298 − 16 | **282** ✓ |
| Ward rows with coords | 1,451 − 8 | **1,443** ✓ |
| County rows with coords | 47 | 47 ✓ |
| `(gps IS NULL) <> (geometry IS NULL)` | 0 | **0** ✓ |
| `ST_SRID(geometry) <> 4326` | 0 | **0** ✓ |
| `gps` not matching `"lat, lon"` format | 0 | **0** ✓ |
| geometry/gps coordinate mismatch (X=lon, Y=lat, 1e-6) | 0 | **0** ✓ |
| Remaining missing = 16 flagged sub-counties + 8 wards (+ country row) | 24 + 1 | **25** ✓ |

### 7.2 Second backfill results (2026-10-14, executed)

Applied via Supabase Management API, HTTP 201 (`/tmp/coords/update_wards_remaining.sql`, guarded, idempotent).

| Check | Expected | Result |
|---|---|---|
| Rows updated (8 wards) | 8 | **8** ✓ |
| Ward rows with coords | 1,451 | **1,451** ✓ |
| Ward rows missing coords | 0 | **0** ✓ |
| Post-dedup ward total (1452 removed) | 1,450 | **1,450** ✓ |
| gps/geometry consistency, SRID 4326, format | all 0 | **0** ✓ |
| Pre-existing `MAHIGA` (483) unchanged | `-0.52, 36.809` | `-0.52, 36.809` ✓ |
| Re-run affected rows (idempotency) | 0 | **0** ✓ |

**Kenya ward coverage is now complete: 0 wards with missing coordinates.** The `KIAMAIKO` duplicate (code 1452) was subsequently deleted (§5.1), leaving 1,450 ward rows = the IEBC ward count. Remaining gaps: 16 split/renamed sub-counties (§4.2) and the Kenya country row — both out of scope.
| Pre-existing ward `MAHIGA` (483) unchanged | `-0.52, 36.809` | `-0.52, 36.809` ✓ |
| Re-run affected rows (idempotency) | 0 | **0** ✓ (24/1442 sets fully non-null) |

State after the first backfill; superseded by §7.2 (all 8 wards since resolved). Remaining gaps: 16 split/renamed sub-counties (§4.2) and the Kenya country row (`code 254`) — out of scope.

## 8. How to apply (audit)

The updates were applied as above; the SQL is retained in `docs/locations_coordinates_updates.sql` as the audit record (section 1 = 24 sub-counties, section 2 = 1,442 wards). It is wrapped in `BEGIN; … COMMIT;` and guarded by `gps IS NULL`, so it is atomic, idempotent, and safe to re-run — a second execution affects 0 rows. To re-apply on a restored database: `psql "$SUPABASE_DB_URL" -f docs/locations_coordinates_updates.sql` or via the Management API / SQL editor.
