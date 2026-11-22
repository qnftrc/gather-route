local addonName, HR = ...

HR.FR_REGIONS = {
    ["Alterac Mountains"] = "Montagnes d'Alterac",
    ["Arathi Highlands"] = "Hautes-terres d'Arathi",
    ["Ashenvale"] = "Orneval",
    ["Azshara"] = "Azshara",
    ["Badlands"] = "Terres ingrates",
    ["Blasted Lands"] = "Terres foudroyées",
    ["Burning Steppes"] = "Steppes ardentes",
    ["Darkshore"] = "Sombrivage",
    ["Desolace"] = "Désolace",
    ["Dun Morogh"] = "Dun Morogh",
    ["Durotar"] = "Durotar",
    ["Duskwood"] = "Bois de la Pénombre",
    ["Dustwallow Marsh"] = "Marécage d'Âprefange",
    ["Eastern Plaguelands"] = "Maleterres de l'est",
    ["Elwynn Forest"] = "Forêt d'Elwynn",
    ["Felwood"] = "Gangrebois",
    ["Feralas"] = "Féralas",
    ["Hillsbrad Foothills"] = "Contreforts de Hautebrande",
    ["Ironforge"] = "Forgefer",
    ["Loch Modan"] = "Loch Modan",
    ["Mount Hyjal"] = "Mont Hyjal",
    ["Mulgore"] = "Mulgore",
    ["Orgrimmar"] = "Orgrimmar",
    ["Redridge Mountains"] = "Les Carmines",
    ["Searing Gorge"] = "Gorge des Vents brûlants",
    ["Silithus"] = "Silithus",
    ["Silverpine Forest"] = "Forêt des Pins argentés",
    ["Stonetalon Mountains"] = "Les Serres-Rocheuses",
    ["Stormwind City"] = "Hurlevent",
    ["Stranglethorn Vale"] = "Vallée de Strangleronce",
    ["Swamp of Sorrows"] = "Marais des Chagrins",
    ["Tanaris"] = "Tanaris",
    ["Teldrassil"] = "Teldrassil",
    ["The Barrens"] = "Les Tarides",
    ["The Hinterlands"] = "Les Hinterlands",
    ["Thousand Needles"] = "Mille pointes",
    ["Thunder Bluff"] = "Pitons du Tonnerre",
    ["Tirisfal Glades"] = "Clairières de Tirisfal",
    ["Un'Goro Crater"] = "Cratère d'Un'Goro",
    ["Western Plaguelands"] = "Maleterres de l'ouest",
    ["Westfall"] = "Marche de l'Ouest",
    ["Wetlands"] = "Les Paluns",
    ["Winterspring"] = "Berceau-de-l'Hiver",
}

function HR.IsFrenchClient()
    return GetLocale and GetLocale() == "frFR"
end

-- Name shown for a region: French on a French client when known, else the key.
function HR.RegionLabel(region)
    if HR.IsFrenchClient() and HR.FR_REGIONS[region] then return HR.FR_REGIONS[region] end
    return region
end

-- Every name a region answers to, the key first.
function HR.RegionNames(region)
    local fr = HR.FR_REGIONS[region]
    if fr and fr ~= region then return {region, fr} end
    return {region}
end
