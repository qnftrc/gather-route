# Comparaison des bases HerbRoute et GatherMate (Forever)

Généré par `tools/compare_sources.py`. Deux points se correspondent à moins de 0.50 % de la carte, même région, même type. Lecture seule. « Wowhead » = base d'origine des herbes (`HerbData.lua`, inchangée) et export Wowhead des minerais ; « GatherMate » = `GatherMate2_Data/Forever`.

## Herbes

Types présents d'un seul côté : Wowhead seul : Demonsage ; GatherMate seul : aucun.

### Par type

| Nom | Points Wowhead | couverts par GatherMate | Points GatherMate | couverts par Wowhead | seuls Wowhead | seuls GatherMate |
|---|---|---|---|---|---|---|
| Arthas' Tears | 109 | 109 (100.0 %) | 138 | 108 (78.3 %) | 0 | 30 |
| Black Lotus | 162 | 162 (100.0 %) | 162 | 162 (100.0 %) | 0 | 0 |
| Blindweed | 195 | 195 (100.0 %) | 195 | 195 (100.0 %) | 0 | 0 |
| Briarthorn | 829 | 801 (96.6 %) | 948 | 787 (83.0 %) | 28 | 161 |
| Bruiseweed | 786 | 742 (94.4 %) | 807 | 734 (91.0 %) | 44 | 73 |
| Demonsage | 61 | 0 (0.0 %) | 0 | 0 (n/a) | 61 | 0 |
| Dreamfoil | 340 | 337 (99.1 %) | 377 | 335 (88.9 %) | 3 | 42 |
| Earthroot | 846 | 814 (96.2 %) | 843 | 813 (96.4 %) | 32 | 30 |
| Fadeleaf | 251 | 248 (98.8 %) | 245 | 245 (100.0 %) | 3 | 0 |
| Firebloom | 283 | 281 (99.3 %) | 280 | 280 (100.0 %) | 2 | 0 |
| Ghost Mushroom | 52 | 52 (100.0 %) | 52 | 52 (100.0 %) | 0 | 0 |
| Golden Sansam | 258 | 258 (100.0 %) | 287 | 258 (89.9 %) | 0 | 29 |
| Goldthorn | 602 | 597 (99.2 %) | 596 | 591 (99.2 %) | 5 | 5 |
| Grave Moss | 103 | 101 (98.1 %) | 108 | 98 (90.7 %) | 2 | 10 |
| Gromsblood | 76 | 76 (100.0 %) | 136 | 76 (55.9 %) | 0 | 60 |
| Icecap | 170 | 170 (100.0 %) | 170 | 170 (100.0 %) | 0 | 0 |
| Khadgar's Whisker | 512 | 501 (97.9 %) | 503 | 494 (98.2 %) | 11 | 9 |
| Kingsblood | 914 | 912 (99.8 %) | 928 | 894 (96.3 %) | 2 | 34 |
| Liferoot | 527 | 520 (98.7 %) | 522 | 507 (97.1 %) | 7 | 15 |
| Mageroyal | 735 | 715 (97.3 %) | 872 | 702 (80.5 %) | 20 | 170 |
| Mountain Silversage | 359 | 358 (99.7 %) | 392 | 358 (91.3 %) | 1 | 34 |
| Peacebloom | 1237 | 1193 (96.4 %) | 1704 | 1174 (68.9 %) | 44 | 530 |
| Plaguebloom | 254 | 254 (100.0 %) | 317 | 254 (80.1 %) | 0 | 63 |
| Purple Lotus | 342 | 342 (100.0 %) | 338 | 338 (100.0 %) | 0 | 0 |
| Silverleaf | 1425 | 1402 (98.4 %) | 1877 | 1372 (73.1 %) | 23 | 505 |
| Stranglekelp | 793 | 763 (96.2 %) | 756 | 748 (98.9 %) | 30 | 8 |
| Sungrass | 467 | 467 (100.0 %) | 488 | 467 (95.7 %) | 0 | 21 |
| Wild Steelbloom | 525 | 518 (98.7 %) | 524 | 509 (97.1 %) | 7 | 15 |
| Wintersbite | 43 | 42 (97.7 %) | 40 | 40 (100.0 %) | 1 | 0 |
| **Total** | 13256 | 12930 (97.5 %) | 14605 | 12761 (87.4 %) | 326 | 1844 |

### Par région

| Nom | Points Wowhead | couverts par GatherMate | Points GatherMate | couverts par Wowhead | seuls Wowhead | seuls GatherMate |
|---|---|---|---|---|---|---|
| Alterac Mountains | 334 | 327 (97.9 %) | 314 | 313 (99.7 %) | 7 | 1 |
| Arathi Highlands | 358 | 358 (100.0 %) | 350 | 350 (100.0 %) | 0 | 0 |
| Ashenvale | 447 | 447 (100.0 %) | 441 | 441 (100.0 %) | 0 | 0 |
| Azshara | 474 | 474 (100.0 %) | 473 | 473 (100.0 %) | 0 | 0 |
| Badlands | 187 | 187 (100.0 %) | 187 | 187 (100.0 %) | 0 | 0 |
| Blasted Lands | 96 | 96 (100.0 %) | 96 | 96 (100.0 %) | 0 | 0 |
| Burning Steppes | 168 | 168 (100.0 %) | 167 | 167 (100.0 %) | 0 | 0 |
| Darkshore | 319 | 313 (98.1 %) | 303 | 303 (100.0 %) | 6 | 0 |
| Desolace | 265 | 264 (99.6 %) | 264 | 263 (99.6 %) | 1 | 1 |
| Dun Morogh | 289 | 289 (100.0 %) | 374 | 274 (73.3 %) | 0 | 100 |
| Durotar | 298 | 298 (100.0 %) | 416 | 288 (69.2 %) | 0 | 128 |
| Duskwood | 325 | 325 (100.0 %) | 318 | 318 (100.0 %) | 0 | 0 |
| Dustwallow Marsh | 339 | 339 (100.0 %) | 336 | 336 (100.0 %) | 0 | 0 |
| Eastern Plaguelands | 465 | 465 (100.0 %) | 465 | 465 (100.0 %) | 0 | 0 |
| Elwynn Forest | 289 | 289 (100.0 %) | 409 | 279 (68.2 %) | 0 | 130 |
| Felwood | 0 | 0 (n/a) | 279 | 0 (0.0 %) | 0 | 279 |
| Feralas | 446 | 446 (100.0 %) | 443 | 443 (100.0 %) | 0 | 0 |
| Hillsbrad Foothills | 355 | 352 (99.2 %) | 340 | 340 (100.0 %) | 3 | 0 |
| Ironforge | 15 | 15 (100.0 %) | 15 | 15 (100.0 %) | 0 | 0 |
| Loch Modan | 305 | 305 (100.0 %) | 301 | 301 (100.0 %) | 0 | 0 |
| Mount Hyjal | 65 | 0 (0.0 %) | 0 | 0 (n/a) | 65 | 0 |
| Mulgore | 525 | 521 (99.2 %) | 775 | 497 (64.1 %) | 4 | 278 |
| Orgrimmar | 18 | 18 (100.0 %) | 18 | 18 (100.0 %) | 0 | 0 |
| Redridge Mountains | 425 | 340 (80.0 %) | 323 | 323 (100.0 %) | 85 | 0 |
| Riverglades | 88 | 55 (62.5 %) | 137 | 54 (39.4 %) | 33 | 83 |
| Searing Gorge | 114 | 112 (98.2 %) | 111 | 111 (100.0 %) | 2 | 0 |
| Shen'dralas | 35 | 7 (20.0 %) | 17 | 7 (41.2 %) | 28 | 10 |
| Silithus | 150 | 150 (100.0 %) | 150 | 150 (100.0 %) | 0 | 0 |
| Silverpine Forest | 429 | 427 (99.5 %) | 412 | 412 (100.0 %) | 2 | 0 |
| Stonetalon Mountains | 351 | 351 (100.0 %) | 340 | 340 (100.0 %) | 0 | 0 |
| Stormwind City | 26 | 25 (96.2 %) | 26 | 25 (96.2 %) | 1 | 1 |
| Stranglethorn Vale | 702 | 698 (99.4 %) | 690 | 690 (100.0 %) | 4 | 0 |
| Swamp of Sorrows | 475 | 474 (99.8 %) | 472 | 471 (99.8 %) | 1 | 1 |
| Tanaris | 187 | 187 (100.0 %) | 187 | 187 (100.0 %) | 0 | 0 |
| Teldrassil | 355 | 355 (100.0 %) | 504 | 348 (69.0 %) | 0 | 156 |
| The Barrens | 216 | 216 (100.0 %) | 857 | 311 (36.3 %) | 0 | 546 |
| The Hinterlands | 342 | 342 (100.0 %) | 342 | 342 (100.0 %) | 0 | 0 |
| Thousand Needles | 143 | 143 (100.0 %) | 140 | 140 (100.0 %) | 0 | 0 |
| Thunder Bluff | 13 | 10 (76.9 %) | 10 | 10 (100.0 %) | 3 | 0 |
| Tirisfal Glades | 345 | 345 (100.0 %) | 462 | 333 (72.1 %) | 0 | 129 |
| Un'Goro Crater | 253 | 253 (100.0 %) | 253 | 253 (100.0 %) | 0 | 0 |
| Western Plaguelands | 236 | 236 (100.0 %) | 235 | 235 (100.0 %) | 0 | 0 |
| Westfall | 421 | 413 (98.1 %) | 405 | 405 (100.0 %) | 8 | 0 |
| Wetlands | 528 | 527 (99.8 %) | 513 | 513 (100.0 %) | 1 | 0 |
| Winterspring | 298 | 298 (100.0 %) | 298 | 298 (100.0 %) | 0 | 0 |
| Zephras Isle | 742 | 670 (90.3 %) | 637 | 636 (99.8 %) | 72 | 1 |
| **Total** | 13256 | 12930 (97.5 %) | 14605 | 12761 (87.4 %) | 326 | 1844 |

## Minerais

Types présents d'un seul côté : Wowhead seul : aucun ; GatherMate seul : Ooze Covered Gold Vein, Ooze Covered Mithril Deposit, Ooze Covered Rich Thorium Vein, Ooze Covered Silver Vein, Ooze Covered Thorium Vein, Ooze Covered Truesilver Deposit.

### Par type

| Nom | Points Wowhead | couverts par GatherMate | Points GatherMate | couverts par Wowhead | seuls Wowhead | seuls GatherMate |
|---|---|---|---|---|---|---|
| Copper Vein | 2526 | 2454 (97.1 %) | 2761 | 2430 (88.0 %) | 72 | 331 |
| Dark Iron Deposit | 195 | 195 (100.0 %) | 194 | 194 (100.0 %) | 0 | 0 |
| Gold Vein | 1158 | 1088 (94.0 %) | 1156 | 1077 (93.2 %) | 70 | 79 |
| Incendicite Mineral Vein | 15 | 13 (86.7 %) | 24 | 14 (58.3 %) | 2 | 10 |
| Iron Deposit | 1275 | 1112 (87.2 %) | 1093 | 1086 (99.4 %) | 163 | 7 |
| Lesser Bloodstone Deposit | 13 | 13 (100.0 %) | 12 | 12 (100.0 %) | 0 | 0 |
| Mithril Deposit | 1058 | 1030 (97.4 %) | 1085 | 1017 (93.7 %) | 28 | 68 |
| Ooze Covered Gold Vein | 0 | 0 (n/a) | 19 | 0 (0.0 %) | 0 | 19 |
| Ooze Covered Mithril Deposit | 0 | 0 (n/a) | 23 | 0 (0.0 %) | 0 | 23 |
| Ooze Covered Rich Thorium Vein | 0 | 0 (n/a) | 97 | 0 (0.0 %) | 0 | 97 |
| Ooze Covered Silver Vein | 0 | 0 (n/a) | 9 | 0 (0.0 %) | 0 | 9 |
| Ooze Covered Thorium Vein | 0 | 0 (n/a) | 17 | 0 (0.0 %) | 0 | 17 |
| Ooze Covered Truesilver Deposit | 0 | 0 (n/a) | 111 | 0 (0.0 %) | 0 | 111 |
| Rich Thorium Vein | 311 | 255 (82.0 %) | 255 | 255 (100.0 %) | 56 | 0 |
| Silver Vein | 1368 | 1260 (92.1 %) | 1288 | 1237 (96.0 %) | 108 | 51 |
| Small Thorium Vein | 396 | 396 (100.0 %) | 457 | 396 (86.7 %) | 0 | 61 |
| Tin Vein | 1250 | 1203 (96.2 %) | 1267 | 1180 (93.1 %) | 47 | 87 |
| Truesilver Deposit | 1086 | 1054 (97.1 %) | 1143 | 1045 (91.4 %) | 32 | 98 |
| **Total** | 10651 | 10073 (94.6 %) | 11011 | 9943 (90.3 %) | 578 | 1068 |

### Par région

| Nom | Points Wowhead | couverts par GatherMate | Points GatherMate | couverts par Wowhead | seuls Wowhead | seuls GatherMate |
|---|---|---|---|---|---|---|
| Alterac Mountains | 315 | 308 (97.8 %) | 294 | 294 (100.0 %) | 7 | 0 |
| Arathi Highlands | 557 | 556 (99.8 %) | 550 | 550 (100.0 %) | 1 | 0 |
| Ashenvale | 298 | 286 (96.0 %) | 279 | 279 (100.0 %) | 12 | 0 |
| Azshara | 260 | 260 (100.0 %) | 260 | 260 (100.0 %) | 0 | 0 |
| Badlands | 390 | 387 (99.2 %) | 383 | 383 (100.0 %) | 3 | 0 |
| Blasted Lands | 105 | 105 (100.0 %) | 174 | 105 (60.3 %) | 0 | 69 |
| Burning Steppes | 360 | 360 (100.0 %) | 359 | 359 (100.0 %) | 0 | 0 |
| Darkshore | 232 | 226 (97.4 %) | 223 | 223 (100.0 %) | 6 | 0 |
| Desolace | 429 | 402 (93.7 %) | 396 | 396 (100.0 %) | 27 | 0 |
| Dun Morogh | 193 | 193 (100.0 %) | 226 | 184 (81.4 %) | 0 | 42 |
| Durotar | 173 | 173 (100.0 %) | 236 | 168 (71.2 %) | 0 | 68 |
| Duskwood | 270 | 261 (96.7 %) | 254 | 253 (99.6 %) | 9 | 1 |
| Dustwallow Marsh | 159 | 158 (99.4 %) | 164 | 157 (95.7 %) | 1 | 7 |
| Eastern Plaguelands | 213 | 212 (99.5 %) | 212 | 212 (100.0 %) | 1 | 0 |
| Elwynn Forest | 188 | 185 (98.4 %) | 224 | 174 (77.7 %) | 3 | 50 |
| Felwood | 0 | 0 (n/a) | 204 | 0 (0.0 %) | 0 | 204 |
| Feralas | 170 | 166 (97.6 %) | 203 | 164 (80.8 %) | 4 | 39 |
| Hillsbrad Foothills | 316 | 306 (96.8 %) | 329 | 289 (87.8 %) | 10 | 40 |
| Loch Modan | 309 | 306 (99.0 %) | 292 | 292 (100.0 %) | 3 | 0 |
| Mount Hyjal | 55 | 0 (0.0 %) | 0 | 0 (n/a) | 55 | 0 |
| Mulgore | 267 | 259 (97.0 %) | 324 | 255 (78.7 %) | 8 | 69 |
| Redridge Mountains | 408 | 351 (86.0 %) | 391 | 332 (84.9 %) | 57 | 59 |
| Riverglades | 233 | 34 (14.6 %) | 69 | 30 (43.5 %) | 199 | 39 |
| Searing Gorge | 269 | 268 (99.6 %) | 266 | 266 (100.0 %) | 1 | 0 |
| Shen'dralas | 49 | 5 (10.2 %) | 12 | 6 (50.0 %) | 44 | 6 |
| Silithus | 145 | 145 (100.0 %) | 329 | 145 (44.1 %) | 0 | 184 |
| Silverpine Forest | 213 | 200 (93.9 %) | 189 | 189 (100.0 %) | 13 | 0 |
| Stonetalon Mountains | 269 | 261 (97.0 %) | 260 | 257 (98.8 %) | 8 | 3 |
| Stranglethorn Vale | 425 | 403 (94.8 %) | 392 | 392 (100.0 %) | 22 | 0 |
| Swamp of Sorrows | 140 | 138 (98.6 %) | 144 | 139 (96.5 %) | 2 | 5 |
| Tanaris | 335 | 333 (99.4 %) | 334 | 332 (99.4 %) | 2 | 2 |
| The Barrens | 433 | 433 (100.0 %) | 555 | 493 (88.8 %) | 0 | 62 |
| The Hinterlands | 345 | 343 (99.4 %) | 340 | 340 (100.0 %) | 2 | 0 |
| Thousand Needles | 486 | 459 (94.4 %) | 471 | 443 (94.1 %) | 27 | 28 |
| Thunder Bluff | 3 | 3 (100.0 %) | 3 | 3 (100.0 %) | 0 | 0 |
| Tirisfal Glades | 176 | 176 (100.0 %) | 220 | 172 (78.2 %) | 0 | 48 |
| Un'Goro Crater | 202 | 202 (100.0 %) | 227 | 201 (88.5 %) | 0 | 26 |
| Western Plaguelands | 185 | 185 (100.0 %) | 185 | 185 (100.0 %) | 0 | 0 |
| Westfall | 224 | 222 (99.1 %) | 214 | 213 (99.5 %) | 2 | 1 |
| Wetlands | 244 | 230 (94.3 %) | 232 | 222 (95.7 %) | 14 | 10 |
| Winterspring | 278 | 278 (100.0 %) | 278 | 278 (100.0 %) | 0 | 0 |
| Zephras Isle | 330 | 295 (89.4 %) | 314 | 308 (98.1 %) | 35 | 6 |
| **Total** | 10651 | 10073 (94.6 %) | 11011 | 9943 (90.3 %) | 578 | 1068 |
