# Doublons des bases de points

Généré par `tools/report_duplicates.py` (lecture seule) sur la base chargée par l'add-on (herbes : `HerbData.lua` puis `HerbDataGatherMate.lua` ; minerais : `OreDataGatherMate.lua` puis `OreDataWowhead.lua`). Une unité = 1 % de la carte. Deux points du même type et de la même région à moins de N unités forment un groupe ; **en trop** = points au-delà d'un par groupe. Les doublons à 0,1 et 0,5 des herbes viennent surtout de la base d'origine Wowhead, conservée telle quelle (décision D8).

## Herbes : total

Points 14642 ; en trop : 2047 à 0,1, 3689 à 0,5, 4334 à 1,0 (29.6 %).

### Herbes par type

| Type | Points | En trop 0,1 | En trop 0,5 | En trop 1,0 |
|---|---|---|---|---|
| Silverleaf | 1776 | 210 | 411 | 562 |
| Peacebloom | 1607 | 218 | 342 | 536 |
| Kingsblood | 948 | 160 | 313 | 327 |
| Briarthorn | 964 | 104 | 269 | 291 |
| Mageroyal | 876 | 129 | 249 | 272 |
| Bruiseweed | 852 | 98 | 205 | 243 |
| Earthroot | 874 | 117 | 201 | 230 |
| Goldthorn | 607 | 101 | 164 | 179 |
| Stranglekelp | 801 | 100 | 134 | 173 |
| Liferoot | 542 | 85 | 154 | 170 |
| Sungrass | 481 | 80 | 130 | 137 |
| Khadgar's Whisker | 521 | 67 | 129 | 135 |
| Wild Steelbloom | 540 | 64 | 103 | 114 |
| Dreamfoil | 375 | 68 | 113 | 113 |
| Purple Lotus | 342 | 52 | 76 | 112 |
| Fadeleaf | 251 | 45 | 93 | 96 |
| Mountain Silversage | 384 | 63 | 89 | 90 |
| Blindweed | 195 | 23 | 86 | 86 |
| Firebloom | 283 | 54 | 82 | 82 |
| Plaguebloom | 301 | 38 | 67 | 71 |
| Golden Sansam | 277 | 43 | 66 | 67 |
| Grave Moss | 113 | 17 | 36 | 49 |
| Black Lotus | 162 | 29 | 42 | 42 |
| Icecap | 170 | 31 | 36 | 42 |
| Arthas' Tears | 130 | 24 | 37 | 37 |
| Ghost Mushroom | 52 | 11 | 17 | 28 |
| Gromsblood | 114 | 9 | 21 | 21 |
| Wintersbite | 43 | 7 | 14 | 15 |
| Demonsage | 61 | 0 | 10 | 14 |

### Herbes par région

| Région | Points | En trop 0,1 | En trop 0,5 | En trop 1,0 |
|---|---|---|---|---|
| Zephras Isle | 743 | 62 | 138 | 319 |
| Swamp of Sorrows | 476 | 70 | 205 | 208 |
| Stranglethorn Vale | 702 | 116 | 142 | 186 |
| Mulgore | 666 | 98 | 136 | 180 |
| Silverpine Forest | 429 | 79 | 142 | 167 |
| Redridge Mountains | 425 | 48 | 164 | 167 |
| Wetlands | 528 | 72 | 140 | 154 |
| Westfall | 421 | 59 | 138 | 141 |
| Eastern Plaguelands | 465 | 82 | 134 | 135 |
| Alterac Mountains | 335 | 54 | 131 | 134 |
| Teldrassil | 478 | 60 | 91 | 134 |
| Hillsbrad Foothills | 355 | 57 | 130 | 134 |
| Duskwood | 325 | 40 | 129 | 133 |
| Dun Morogh | 373 | 53 | 83 | 129 |
| Tirisfal Glades | 439 | 67 | 106 | 123 |
| Loch Modan | 305 | 50 | 119 | 120 |
| Arathi Highlands | 358 | 57 | 114 | 117 |
| Azshara | 474 | 87 | 115 | 115 |
| Elwynn Forest | 386 | 54 | 104 | 113 |
| Durotar | 388 | 57 | 93 | 112 |
| The Hinterlands | 342 | 48 | 93 | 105 |
| Stonetalon Mountains | 351 | 61 | 95 | 97 |
| Feralas | 446 | 61 | 70 | 93 |
| Ashenvale | 447 | 56 | 74 | 82 |
| Western Plaguelands | 236 | 52 | 76 | 81 |
| Un'Goro Crater | 253 | 41 | 76 | 78 |
| The Barrens | 676 | 21 | 21 | 78 |
| Badlands | 187 | 35 | 78 | 78 |
| Dustwallow Marsh | 339 | 54 | 73 | 77 |
| Desolace | 266 | 44 | 71 | 72 |
| Darkshore | 319 | 51 | 64 | 71 |
| Winterspring | 298 | 57 | 64 | 71 |
| Burning Steppes | 168 | 24 | 58 | 58 |
| Tanaris | 187 | 29 | 31 | 49 |
| Silithus | 150 | 27 | 48 | 48 |
| Searing Gorge | 114 | 26 | 45 | 45 |
| Thousand Needles | 143 | 21 | 40 | 40 |
| Blasted Lands | 96 | 15 | 28 | 28 |
| Shen'dralas | 45 | 0 | 7 | 22 |
| Mount Hyjal | 65 | 0 | 10 | 14 |
| Riverglades | 171 | 2 | 5 | 9 |
| Stormwind City | 27 | 0 | 4 | 8 |
| Thunder Bluff | 13 | 0 | 2 | 6 |
| Orgrimmar | 18 | 0 | 2 | 3 |
| Ironforge | 15 | 0 | 0 | 0 |
| Felwood | 199 | 0 | 0 | 0 |

### Herbes : détail région et type (au moins un doublon à 1,0)

| Région | Type | Points | En trop 0,1 | En trop 0,5 | En trop 1,0 |
|---|---|---|---|---|---|
| Zephras Isle | Peacebloom | 298 | 21 | 50 | 161 |
| Zephras Isle | Silverleaf | 258 | 23 | 56 | 101 |
| Mulgore | Silverleaf | 299 | 46 | 65 | 87 |
| Swamp of Sorrows | Blindweed | 176 | 19 | 78 | 78 |
| Mulgore | Peacebloom | 254 | 37 | 47 | 67 |
| Redridge Mountains | Briarthorn | 135 | 20 | 58 | 61 |
| Elwynn Forest | Silverleaf | 188 | 22 | 53 | 56 |
| Tirisfal Glades | Silverleaf | 195 | 22 | 46 | 56 |
| Dun Morogh | Silverleaf | 157 | 16 | 29 | 54 |
| Teldrassil | Silverleaf | 190 | 20 | 33 | 53 |
| Durotar | Peacebloom | 161 | 25 | 40 | 49 |
| Silverpine Forest | Briarthorn | 100 | 19 | 37 | 48 |
| Teldrassil | Peacebloom | 173 | 18 | 25 | 48 |
| Dun Morogh | Peacebloom | 145 | 19 | 31 | 47 |
| Searing Gorge | Firebloom | 114 | 26 | 45 | 45 |
| Tirisfal Glades | Peacebloom | 164 | 31 | 38 | 45 |
| Eastern Plaguelands | Plaguebloom | 166 | 21 | 44 | 44 |
| Winterspring | Icecap | 170 | 31 | 36 | 42 |
| Durotar | Silverleaf | 144 | 20 | 31 | 41 |
| Redridge Mountains | Mageroyal | 91 | 11 | 41 | 41 |
| Elwynn Forest | Peacebloom | 133 | 23 | 36 | 40 |
| Hillsbrad Foothills | Kingsblood | 85 | 15 | 37 | 38 |
| Redridge Mountains | Earthroot | 103 | 9 | 38 | 38 |
| Duskwood | Briarthorn | 95 | 14 | 37 | 37 |
| Zephras Isle | Earthroot | 138 | 11 | 18 | 37 |
| Silverpine Forest | Silverleaf | 89 | 13 | 32 | 36 |
| Stranglethorn Vale | Goldthorn | 126 | 22 | 27 | 36 |
| Stranglethorn Vale | Kingsblood | 117 | 23 | 31 | 36 |
| Loch Modan | Mageroyal | 81 | 10 | 34 | 35 |
| Silverpine Forest | Mageroyal | 90 | 23 | 30 | 35 |
| Hillsbrad Foothills | Briarthorn | 82 | 9 | 34 | 34 |
| Swamp of Sorrows | Liferoot | 75 | 11 | 34 | 34 |
| Wetlands | Kingsblood | 96 | 15 | 33 | 34 |
| Duskwood | Bruiseweed | 72 | 5 | 30 | 32 |
| Alterac Mountains | Kingsblood | 64 | 9 | 29 | 29 |
| Stonetalon Mountains | Kingsblood | 81 | 15 | 28 | 29 |
| Dun Morogh | Earthroot | 71 | 18 | 23 | 28 |
| Loch Modan | Briarthorn | 67 | 15 | 28 | 28 |
| Arathi Highlands | Goldthorn | 76 | 19 | 27 | 27 |
| Arathi Highlands | Kingsblood | 62 | 13 | 27 | 27 |
| Azshara | Dreamfoil | 90 | 20 | 27 | 27 |
| Loch Modan | Silverleaf | 64 | 9 | 27 | 27 |
| Redridge Mountains | Bruiseweed | 96 | 8 | 27 | 27 |
| The Barrens | Stranglekelp | 51 | 6 | 6 | 27 |
| Western Plaguelands | Plaguebloom | 88 | 17 | 23 | 27 |
| Westfall | Mageroyal | 75 | 17 | 27 | 27 |
| Feralas | Sungrass | 106 | 18 | 21 | 26 |
| Mulgore | Earthroot | 113 | 15 | 24 | 26 |
| Stonetalon Mountains | Bruiseweed | 100 | 18 | 26 | 26 |
| The Hinterlands | Sungrass | 84 | 16 | 26 | 26 |
| Westfall | Briarthorn | 86 | 3 | 26 | 26 |
| Azshara | Purple Lotus | 86 | 19 | 25 | 25 |
| Stranglethorn Vale | Khadgar's Whisker | 108 | 18 | 23 | 25 |
| Stranglethorn Vale | Liferoot | 82 | 10 | 14 | 25 |
| Swamp of Sorrows | Kingsblood | 49 | 13 | 25 | 25 |
| Tanaris | Purple Lotus | 48 | 6 | 7 | 25 |
| The Hinterlands | Ghost Mushroom | 44 | 9 | 15 | 25 |
| Wetlands | Liferoot | 70 | 13 | 25 | 25 |
| Wetlands | Stranglekelp | 107 | 15 | 20 | 25 |
| Eastern Plaguelands | Arthas' Tears | 60 | 16 | 24 | 24 |
| Feralas | Purple Lotus | 74 | 9 | 11 | 24 |
| Swamp of Sorrows | Goldthorn | 62 | 12 | 23 | 24 |
| Swamp of Sorrows | Khadgar's Whisker | 56 | 5 | 23 | 24 |
| Eastern Plaguelands | Dreamfoil | 71 | 17 | 23 | 23 |
| Hillsbrad Foothills | Bruiseweed | 70 | 12 | 21 | 23 |
| Silverpine Forest | Peacebloom | 59 | 13 | 23 | 23 |
| Stranglethorn Vale | Stranglekelp | 105 | 15 | 16 | 23 |
| Ashenvale | Kingsblood | 86 | 16 | 20 | 22 |
| Duskwood | Kingsblood | 54 | 5 | 21 | 22 |
| Dustwallow Marsh | Liferoot | 85 | 16 | 19 | 22 |
| Feralas | Goldthorn | 105 | 15 | 17 | 22 |
| The Hinterlands | Purple Lotus | 78 | 11 | 20 | 22 |
| Tirisfal Glades | Earthroot | 80 | 14 | 22 | 22 |
| Un'Goro Crater | Golden Sansam | 65 | 9 | 21 | 22 |
| Westfall | Bruiseweed | 61 | 5 | 20 | 22 |
| Westfall | Silverleaf | 58 | 10 | 22 | 22 |
| Wetlands | Briarthorn | 77 | 8 | 21 | 22 |
| Alterac Mountains | Liferoot | 45 | 6 | 20 | 21 |
| Badlands | Goldthorn | 37 | 11 | 21 | 21 |
| Stonetalon Mountains | Wild Steelbloom | 85 | 18 | 20 | 21 |
| Alterac Mountains | Fadeleaf | 43 | 7 | 19 | 20 |
| Arathi Highlands | Khadgar's Whisker | 60 | 8 | 18 | 20 |
| Azshara | Golden Sansam | 80 | 17 | 20 | 20 |
| Desolace | Stranglekelp | 68 | 13 | 20 | 20 |
| Western Plaguelands | Sungrass | 42 | 14 | 19 | 20 |
| Zephras Isle | Mageroyal | 49 | 7 | 14 | 20 |
| Loch Modan | Peacebloom | 44 | 9 | 19 | 19 |
| Stranglethorn Vale | Wild Steelbloom | 89 | 12 | 13 | 19 |
| Swamp of Sorrows | Fadeleaf | 37 | 7 | 18 | 19 |
| Tanaris | Firebloom | 114 | 18 | 19 | 19 |
| Alterac Mountains | Khadgar's Whisker | 46 | 8 | 18 | 18 |
| Azshara | Sungrass | 87 | 12 | 18 | 18 |
| Duskwood | Grave Moss | 35 | 6 | 17 | 18 |
| Teldrassil | Mageroyal | 44 | 10 | 18 | 18 |
| Thousand Needles | Kingsblood | 52 | 8 | 18 | 18 |
| Un'Goro Crater | Dreamfoil | 64 | 11 | 18 | 18 |
| Un'Goro Crater | Sungrass | 52 | 10 | 17 | 18 |
| Westfall | Peacebloom | 42 | 11 | 18 | 18 |
| Winterspring | Mountain Silversage | 87 | 15 | 17 | 18 |
| Alterac Mountains | Goldthorn | 56 | 9 | 17 | 17 |
| Duskwood | Mageroyal | 41 | 6 | 17 | 17 |
| Eastern Plaguelands | Mountain Silversage | 64 | 12 | 17 | 17 |
| Elwynn Forest | Earthroot | 65 | 9 | 15 | 17 |
| Silithus | Dreamfoil | 37 | 9 | 17 | 17 |
| Westfall | Stranglekelp | 72 | 7 | 16 | 17 |
| Wetlands | Bruiseweed | 66 | 8 | 14 | 17 |
| Arathi Highlands | Fadeleaf | 40 | 3 | 16 | 16 |
| Badlands | Khadgar's Whisker | 32 | 6 | 16 | 16 |
| Darkshore | Mageroyal | 67 | 11 | 13 | 16 |
| Alterac Mountains | Wintersbite | 43 | 7 | 14 | 15 |
| Burning Steppes | Black Lotus | 45 | 9 | 15 | 15 |
| Burning Steppes | Dreamfoil | 38 | 4 | 15 | 15 |
| Burning Steppes | Mountain Silversage | 44 | 6 | 15 | 15 |
| Durotar | Earthroot | 60 | 9 | 15 | 15 |
| Dustwallow Marsh | Goldthorn | 73 | 9 | 15 | 15 |
| Hillsbrad Foothills | Mageroyal | 27 | 9 | 15 | 15 |
| Teldrassil | Earthroot | 71 | 12 | 15 | 15 |
| Ashenvale | Bruiseweed | 77 | 10 | 13 | 14 |
| Ashenvale | Stranglekelp | 76 | 8 | 9 | 14 |
| Blasted Lands | Gromsblood | 42 | 8 | 14 | 14 |
| Dustwallow Marsh | Fadeleaf | 53 | 10 | 14 | 14 |
| Mount Hyjal | Demonsage | 61 | 0 | 10 | 14 |
| Stranglethorn Vale | Fadeleaf | 43 | 11 | 13 | 14 |
| The Barrens | Kingsblood | 45 | 12 | 12 | 14 |
| The Hinterlands | Goldthorn | 44 | 4 | 14 | 14 |
| Wetlands | Mageroyal | 55 | 7 | 13 | 14 |
| Arathi Highlands | Wild Steelbloom | 69 | 8 | 13 | 13 |
| Azshara | Mountain Silversage | 59 | 11 | 13 | 13 |
| Badlands | Kingsblood | 41 | 4 | 13 | 13 |
| Desolace | Liferoot | 37 | 12 | 13 | 13 |
| Feralas | Khadgar's Whisker | 88 | 12 | 13 | 13 |
| Hillsbrad Foothills | Wild Steelbloom | 42 | 7 | 12 | 13 |
| Silithus | Black Lotus | 43 | 7 | 13 | 13 |
| Silverpine Forest | Bruiseweed | 31 | 5 | 8 | 13 |
| Western Plaguelands | Arthas' Tears | 49 | 8 | 13 | 13 |
| Western Plaguelands | Dreamfoil | 37 | 7 | 13 | 13 |
| Wetlands | Wild Steelbloom | 49 | 5 | 12 | 13 |
| Darkshore | Silverleaf | 46 | 8 | 12 | 12 |
| Desolace | Grave Moss | 37 | 8 | 12 | 12 |
| Dustwallow Marsh | Kingsblood | 43 | 10 | 12 | 12 |
| Eastern Plaguelands | Sungrass | 35 | 5 | 12 | 12 |
| Shen'dralas | Bruiseweed | 26 | 0 | 4 | 12 |
| The Barrens | Bruiseweed | 76 | 0 | 0 | 12 |
| Un'Goro Crater | Mountain Silversage | 53 | 7 | 12 | 12 |
| Alterac Mountains | Bruiseweed | 23 | 7 | 11 | 11 |
| Darkshore | Briarthorn | 56 | 6 | 10 | 11 |
| Stonetalon Mountains | Mageroyal | 32 | 7 | 11 | 11 |
| Thousand Needles | Bruiseweed | 47 | 8 | 11 | 11 |
| Thousand Needles | Wild Steelbloom | 44 | 5 | 11 | 11 |
| Winterspring | Black Lotus | 41 | 11 | 11 | 11 |
| Blasted Lands | Firebloom | 30 | 6 | 10 | 10 |
| Darkshore | Peacebloom | 32 | 10 | 10 | 10 |
| Dustwallow Marsh | Khadgar's Whisker | 58 | 5 | 9 | 10 |
| Eastern Plaguelands | Golden Sansam | 32 | 8 | 10 | 10 |
| Shen'dralas | Grave Moss | 19 | 0 | 3 | 10 |
| Stonetalon Mountains | Briarthorn | 53 | 3 | 10 | 10 |
| Ashenvale | Mageroyal | 49 | 8 | 9 | 9 |
| Badlands | Fadeleaf | 21 | 6 | 9 | 9 |
| Badlands | Wild Steelbloom | 25 | 3 | 9 | 9 |
| Silverpine Forest | Earthroot | 33 | 5 | 9 | 9 |
| Westfall | Earthroot | 27 | 6 | 9 | 9 |
| Arathi Highlands | Liferoot | 30 | 4 | 8 | 8 |
| Ashenvale | Briarthorn | 72 | 7 | 8 | 8 |
| Badlands | Firebloom | 25 | 4 | 8 | 8 |
| Burning Steppes | Golden Sansam | 24 | 4 | 8 | 8 |
| Darkshore | Stranglekelp | 58 | 7 | 8 | 8 |
| Silithus | Sungrass | 20 | 3 | 8 | 8 |
| Stranglethorn Vale | Purple Lotus | 32 | 5 | 5 | 8 |
| Un'Goro Crater | Blindweed | 19 | 4 | 8 | 8 |
| Western Plaguelands | Mountain Silversage | 20 | 6 | 8 | 8 |
| Ashenvale | Liferoot | 34 | 6 | 7 | 7 |
| Darkshore | Bruiseweed | 25 | 3 | 4 | 7 |
| Darkshore | Earthroot | 35 | 6 | 7 | 7 |
| Desolace | Bruiseweed | 35 | 4 | 7 | 7 |
| Desolace | Kingsblood | 37 | 2 | 7 | 7 |
| Durotar | Mageroyal | 23 | 3 | 7 | 7 |
| Duskwood | Wild Steelbloom | 28 | 4 | 7 | 7 |
| Hillsbrad Foothills | Liferoot | 17 | 2 | 7 | 7 |
| Silithus | Mountain Silversage | 31 | 6 | 7 | 7 |
| The Barrens | Mageroyal | 145 | 0 | 0 | 7 |
| Ashenvale | Purple Lotus | 18 | 1 | 6 | 6 |
| Desolace | Gromsblood | 21 | 1 | 6 | 6 |
| Loch Modan | Bruiseweed | 32 | 5 | 6 | 6 |
| The Barrens | Briarthorn | 141 | 0 | 0 | 6 |
| The Barrens | Silverleaf | 57 | 1 | 1 | 6 |
| Azshara | Stranglekelp | 34 | 5 | 5 | 5 |
| Burning Steppes | Sungrass | 17 | 1 | 5 | 5 |
| Feralas | Stranglekelp | 34 | 4 | 5 | 5 |
| Loch Modan | Earthroot | 17 | 2 | 5 | 5 |
| Tanaris | Stranglekelp | 25 | 5 | 5 | 5 |
| Thunder Bluff | Silverleaf | 6 | 0 | 1 | 5 |
| Azshara | Khadgar's Whisker | 24 | 3 | 4 | 4 |
| Blasted Lands | Sungrass | 24 | 1 | 4 | 4 |
| Desolace | Wild Steelbloom | 23 | 2 | 4 | 4 |
| Dustwallow Marsh | Stranglekelp | 27 | 4 | 4 | 4 |
| Hillsbrad Foothills | Stranglekelp | 31 | 3 | 4 | 4 |
| Stormwind City | Peacebloom | 11 | 0 | 2 | 4 |
| Stormwind City | Silverleaf | 9 | 0 | 2 | 4 |
| Swamp of Sorrows | Stranglekelp | 21 | 3 | 4 | 4 |
| The Hinterlands | Fadeleaf | 14 | 1 | 4 | 4 |
| The Hinterlands | Golden Sansam | 22 | 3 | 4 | 4 |
| The Hinterlands | Liferoot | 14 | 2 | 4 | 4 |
| Wetlands | Grave Moss | 8 | 1 | 2 | 4 |
| Arathi Highlands | Bruiseweed | 15 | 0 | 3 | 3 |
| Azshara | Goldthorn | 14 | 0 | 3 | 3 |
| Desolace | Ghost Mushroom | 8 | 2 | 2 | 3 |
| Eastern Plaguelands | Black Lotus | 33 | 2 | 3 | 3 |
| Feralas | Liferoot | 23 | 3 | 3 | 3 |
| Riverglades | Stranglekelp | 26 | 1 | 3 | 3 |
| Silithus | Golden Sansam | 19 | 2 | 3 | 3 |
| Silverpine Forest | Stranglekelp | 26 | 1 | 3 | 3 |
| The Barrens | Peacebloom | 72 | 1 | 1 | 3 |
| The Hinterlands | Khadgar's Whisker | 14 | 1 | 3 | 3 |
| The Hinterlands | Stranglekelp | 28 | 1 | 3 | 3 |
| Alterac Mountains | Stranglekelp | 10 | 1 | 2 | 2 |
| Arathi Highlands | Grave Moss | 4 | 1 | 1 | 2 |
| Badlands | Purple Lotus | 6 | 1 | 2 | 2 |
| Eastern Plaguelands | Grave Moss | 4 | 1 | 1 | 2 |
| Orgrimmar | Silverleaf | 9 | 0 | 1 | 2 |
| Riverglades | Khadgar's Whisker | 34 | 1 | 2 | 2 |
| Riverglades | Wild Steelbloom | 32 | 0 | 0 | 2 |
| The Barrens | Earthroot | 56 | 1 | 1 | 2 |
| Alterac Mountains | Wild Steelbloom | 3 | 0 | 1 | 1 |
| Arathi Highlands | Stranglekelp | 2 | 1 | 1 | 1 |
| Ashenvale | Gromsblood | 13 | 0 | 1 | 1 |
| Ashenvale | Wild Steelbloom | 22 | 0 | 1 | 1 |
| Orgrimmar | Peacebloom | 9 | 0 | 1 | 1 |
| Riverglades | Kingsblood | 36 | 0 | 0 | 1 |
| Riverglades | Liferoot | 29 | 0 | 0 | 1 |
| The Barrens | Grave Moss | 4 | 0 | 0 | 1 |
| Thunder Bluff | Peacebloom | 2 | 0 | 1 | 1 |

## Minerais : total

Points 9440 ; en trop : 0 à 0,1, 0 à 0,5, 756 à 1,0 (8.0 %).

### Minerais par type

| Type | Points | En trop 0,1 | En trop 0,5 | En trop 1,0 |
|---|---|---|---|---|
| Copper Vein | 2193 | 0 | 0 | 346 |
| Tin Vein | 1002 | 0 | 0 | 85 |
| Gold Vein | 1152 | 0 | 0 | 78 |
| Silver Vein | 1277 | 0 | 0 | 77 |
| Iron Deposit | 960 | 0 | 0 | 60 |
| Truesilver Deposit | 1060 | 0 | 0 | 39 |
| Mithril Deposit | 833 | 0 | 0 | 39 |
| Small Thorium Vein | 334 | 0 | 0 | 8 |
| Incendicite Mineral Vein | 19 | 0 | 0 | 6 |
| Ooze Covered Mithril Deposit | 20 | 0 | 0 | 5 |
| Ooze Covered Truesilver Deposit | 88 | 0 | 0 | 4 |
| Rich Thorium Vein | 245 | 0 | 0 | 3 |
| Dark Iron Deposit | 141 | 0 | 0 | 3 |
| Ooze Covered Silver Vein | 8 | 0 | 0 | 1 |
| Ooze Covered Gold Vein | 18 | 0 | 0 | 1 |
| Ooze Covered Rich Thorium Vein | 68 | 0 | 0 | 1 |
| Lesser Bloodstone Deposit | 9 | 0 | 0 | 0 |
| Ooze Covered Thorium Vein | 13 | 0 | 0 | 0 |

### Minerais par région

| Région | Points | En trop 0,1 | En trop 0,5 | En trop 1,0 |
|---|---|---|---|---|
| Zephras Isle | 290 | 0 | 0 | 94 |
| The Barrens | 431 | 0 | 0 | 73 |
| Mulgore | 284 | 0 | 0 | 62 |
| Feralas | 194 | 0 | 0 | 50 |
| Stranglethorn Vale | 376 | 0 | 0 | 47 |
| Durotar | 190 | 0 | 0 | 35 |
| Dun Morogh | 181 | 0 | 0 | 33 |
| Arathi Highlands | 441 | 0 | 0 | 31 |
| Alterac Mountains | 254 | 0 | 0 | 30 |
| Elwynn Forest | 159 | 0 | 0 | 29 |
| Dustwallow Marsh | 143 | 0 | 0 | 26 |
| Silverpine Forest | 163 | 0 | 0 | 25 |
| Thousand Needles | 429 | 0 | 0 | 24 |
| Wetlands | 213 | 0 | 0 | 23 |
| Stonetalon Mountains | 240 | 0 | 0 | 17 |
| Westfall | 146 | 0 | 0 | 15 |
| Darkshore | 196 | 0 | 0 | 15 |
| Tirisfal Glades | 171 | 0 | 0 | 15 |
| Loch Modan | 215 | 0 | 0 | 14 |
| Redridge Mountains | 342 | 0 | 0 | 13 |
| Hillsbrad Foothills | 261 | 0 | 0 | 12 |
| The Hinterlands | 287 | 0 | 0 | 11 |
| Tanaris | 301 | 0 | 0 | 10 |
| Duskwood | 208 | 0 | 0 | 9 |
| Winterspring | 240 | 0 | 0 | 8 |
| Felwood | 176 | 0 | 0 | 7 |
| Shen'dralas | 52 | 0 | 0 | 5 |
| Burning Steppes | 278 | 0 | 0 | 5 |
| Western Plaguelands | 154 | 0 | 0 | 4 |
| Riverglades | 219 | 0 | 0 | 3 |
| Desolace | 348 | 0 | 0 | 3 |
| Badlands | 295 | 0 | 0 | 2 |
| Ashenvale | 259 | 0 | 0 | 2 |
| Mount Hyjal | 55 | 0 | 0 | 1 |
| Thunder Bluff | 2 | 0 | 0 | 1 |
| Un'Goro Crater | 172 | 0 | 0 | 1 |
| Silithus | 253 | 0 | 0 | 1 |
| Searing Gorge | 193 | 0 | 0 | 0 |
| Eastern Plaguelands | 167 | 0 | 0 | 0 |
| Swamp of Sorrows | 114 | 0 | 0 | 0 |
| Azshara | 208 | 0 | 0 | 0 |
| Blasted Lands | 140 | 0 | 0 | 0 |

### Minerais : détail région et type (au moins un doublon à 1,0)

| Région | Type | Points | En trop 0,1 | En trop 0,5 | En trop 1,0 |
|---|---|---|---|---|---|
| Zephras Isle | Copper Vein | 290 | 0 | 0 | 94 |
| Mulgore | Copper Vein | 284 | 0 | 0 | 62 |
| Durotar | Copper Vein | 190 | 0 | 0 | 35 |
| Dun Morogh | Copper Vein | 181 | 0 | 0 | 33 |
| The Barrens | Copper Vein | 200 | 0 | 0 | 30 |
| Elwynn Forest | Copper Vein | 159 | 0 | 0 | 29 |
| The Barrens | Tin Vein | 116 | 0 | 0 | 23 |
| The Barrens | Silver Vein | 115 | 0 | 0 | 20 |
| Stranglethorn Vale | Iron Deposit | 100 | 0 | 0 | 16 |
| Darkshore | Copper Vein | 108 | 0 | 0 | 15 |
| Feralas | Gold Vein | 38 | 0 | 0 | 15 |
| Stranglethorn Vale | Gold Vein | 106 | 0 | 0 | 15 |
| Tirisfal Glades | Copper Vein | 171 | 0 | 0 | 15 |
| Feralas | Mithril Deposit | 48 | 0 | 0 | 14 |
| Alterac Mountains | Gold Vein | 58 | 0 | 0 | 11 |
| Arathi Highlands | Gold Vein | 114 | 0 | 0 | 11 |
| Silverpine Forest | Tin Vein | 56 | 0 | 0 | 11 |
| Loch Modan | Copper Vein | 111 | 0 | 0 | 10 |
| Stonetalon Mountains | Tin Vein | 63 | 0 | 0 | 10 |
| Westfall | Copper Vein | 80 | 0 | 0 | 10 |
| Alterac Mountains | Iron Deposit | 76 | 0 | 0 | 9 |
| Arathi Highlands | Silver Vein | 126 | 0 | 0 | 9 |
| Feralas | Truesilver Deposit | 28 | 0 | 0 | 9 |
| Redridge Mountains | Tin Vein | 143 | 0 | 0 | 9 |
| Alterac Mountains | Silver Vein | 57 | 0 | 0 | 8 |
| Arathi Highlands | Iron Deposit | 105 | 0 | 0 | 8 |
| Silverpine Forest | Copper Vein | 72 | 0 | 0 | 8 |
| Dustwallow Marsh | Iron Deposit | 43 | 0 | 0 | 7 |
| Stranglethorn Vale | Silver Vein | 80 | 0 | 0 | 7 |
| Wetlands | Tin Vein | 69 | 0 | 0 | 7 |
| Dustwallow Marsh | Mithril Deposit | 24 | 0 | 0 | 6 |
| Dustwallow Marsh | Truesilver Deposit | 21 | 0 | 0 | 6 |
| Silverpine Forest | Silver Vein | 35 | 0 | 0 | 6 |
| Stonetalon Mountains | Silver Vein | 66 | 0 | 0 | 6 |
| Stranglethorn Vale | Mithril Deposit | 48 | 0 | 0 | 6 |
| Thousand Needles | Gold Vein | 77 | 0 | 0 | 6 |
| Thousand Needles | Silver Vein | 128 | 0 | 0 | 6 |
| Wetlands | Incendicite Mineral Vein | 19 | 0 | 0 | 6 |
| Duskwood | Tin Vein | 59 | 0 | 0 | 5 |
| Dustwallow Marsh | Gold Vein | 20 | 0 | 0 | 5 |
| Felwood | Truesilver Deposit | 69 | 0 | 0 | 5 |
| Hillsbrad Foothills | Tin Vein | 72 | 0 | 0 | 5 |
| Thousand Needles | Iron Deposit | 87 | 0 | 0 | 5 |
| Thousand Needles | Tin Vein | 60 | 0 | 0 | 5 |
| Wetlands | Silver Vein | 57 | 0 | 0 | 5 |
| Winterspring | Truesilver Deposit | 107 | 0 | 0 | 5 |
| Feralas | Ooze Covered Mithril Deposit | 12 | 0 | 0 | 4 |
| Feralas | Ooze Covered Truesilver Deposit | 11 | 0 | 0 | 4 |
| Redridge Mountains | Copper Vein | 132 | 0 | 0 | 4 |
| Tanaris | Mithril Deposit | 76 | 0 | 0 | 4 |
| The Hinterlands | Truesilver Deposit | 85 | 0 | 0 | 4 |
| Burning Steppes | Dark Iron Deposit | 86 | 0 | 0 | 3 |
| Hillsbrad Foothills | Iron Deposit | 35 | 0 | 0 | 3 |
| Hillsbrad Foothills | Silver Vein | 91 | 0 | 0 | 3 |
| Loch Modan | Tin Vein | 59 | 0 | 0 | 3 |
| Shen'dralas | Iron Deposit | 19 | 0 | 0 | 3 |
| Tanaris | Truesilver Deposit | 74 | 0 | 0 | 3 |
| The Hinterlands | Gold Vein | 79 | 0 | 0 | 3 |
| The Hinterlands | Mithril Deposit | 90 | 0 | 0 | 3 |
| Westfall | Tin Vein | 34 | 0 | 0 | 3 |
| Wetlands | Iron Deposit | 22 | 0 | 0 | 3 |
| Winterspring | Small Thorium Vein | 40 | 0 | 0 | 3 |
| Arathi Highlands | Mithril Deposit | 33 | 0 | 0 | 2 |
| Ashenvale | Tin Vein | 90 | 0 | 0 | 2 |
| Desolace | Gold Vein | 57 | 0 | 0 | 2 |
| Duskwood | Gold Vein | 27 | 0 | 0 | 2 |
| Duskwood | Iron Deposit | 35 | 0 | 0 | 2 |
| Dustwallow Marsh | Silver Vein | 24 | 0 | 0 | 2 |
| Stranglethorn Vale | Truesilver Deposit | 30 | 0 | 0 | 2 |
| Tanaris | Gold Vein | 83 | 0 | 0 | 2 |
| Western Plaguelands | Rich Thorium Vein | 12 | 0 | 0 | 2 |
| Western Plaguelands | Truesilver Deposit | 61 | 0 | 0 | 2 |
| Westfall | Silver Vein | 32 | 0 | 0 | 2 |
| Wetlands | Gold Vein | 19 | 0 | 0 | 2 |
| Alterac Mountains | Mithril Deposit | 24 | 0 | 0 | 1 |
| Alterac Mountains | Truesilver Deposit | 22 | 0 | 0 | 1 |
| Arathi Highlands | Truesilver Deposit | 24 | 0 | 0 | 1 |
| Badlands | Gold Vein | 96 | 0 | 0 | 1 |
| Badlands | Iron Deposit | 51 | 0 | 0 | 1 |
| Burning Steppes | Small Thorium Vein | 34 | 0 | 0 | 1 |
| Burning Steppes | Truesilver Deposit | 79 | 0 | 0 | 1 |
| Desolace | Iron Deposit | 93 | 0 | 0 | 1 |
| Felwood | Gold Vein | 35 | 0 | 0 | 1 |
| Felwood | Mithril Deposit | 36 | 0 | 0 | 1 |
| Feralas | Iron Deposit | 19 | 0 | 0 | 1 |
| Feralas | Ooze Covered Gold Vein | 10 | 0 | 0 | 1 |
| Feralas | Silver Vein | 16 | 0 | 0 | 1 |
| Feralas | Small Thorium Vein | 9 | 0 | 0 | 1 |
| Hillsbrad Foothills | Gold Vein | 23 | 0 | 0 | 1 |
| Loch Modan | Silver Vein | 45 | 0 | 0 | 1 |
| Mount Hyjal | Rich Thorium Vein | 55 | 0 | 0 | 1 |
| Riverglades | Iron Deposit | 130 | 0 | 0 | 1 |
| Riverglades | Mithril Deposit | 12 | 0 | 0 | 1 |
| Riverglades | Tin Vein | 20 | 0 | 0 | 1 |
| Shen'dralas | Mithril Deposit | 23 | 0 | 0 | 1 |
| Shen'dralas | Silver Vein | 6 | 0 | 0 | 1 |
| Silithus | Ooze Covered Rich Thorium Vein | 68 | 0 | 0 | 1 |
| Stonetalon Mountains | Gold Vein | 26 | 0 | 0 | 1 |
| Stranglethorn Vale | Tin Vein | 12 | 0 | 0 | 1 |
| Tanaris | Small Thorium Vein | 17 | 0 | 0 | 1 |
| The Hinterlands | Small Thorium Vein | 13 | 0 | 0 | 1 |
| Thousand Needles | Ooze Covered Mithril Deposit | 8 | 0 | 0 | 1 |
| Thousand Needles | Ooze Covered Silver Vein | 8 | 0 | 0 | 1 |
| Thunder Bluff | Copper Vein | 2 | 0 | 0 | 1 |
| Un'Goro Crater | Small Thorium Vein | 39 | 0 | 0 | 1 |
