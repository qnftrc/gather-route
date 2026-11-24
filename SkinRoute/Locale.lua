local addonName, SR = ...

SR.FR_REGIONS = {
    ["Alterac Mountains"] = "Montagnes d'Alterac",
    ["Arathi Highlands"] = "Hautes-terres d'Arathi",
    ["Ashenvale"] = "Orneval",
    ["Azshara"] = "Azshara",
    ["Badlands"] = "Terres ingrates",
    ["Blasted Lands"] = "Terres foudroyées",
    ["Burning Steppes"] = "Steppes ardentes",
    ["Darkshore"] = "Sombrivage",
    ["Deadwind Pass"] = "Défilé de Deuillevent",
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
    ["Loch Modan"] = "Loch Modan",
    ["Moonglade"] = "Reflet-de-Lune",
    ["Mount Hyjal"] = "Mont Hyjal",
    ["Mulgore"] = "Mulgore",
    ["Redridge Mountains"] = "Les Carmines",
    ["Searing Gorge"] = "Gorge des Vents brûlants",
    ["Silithus"] = "Silithus",
    ["Silverpine Forest"] = "Forêt des Pins argentés",
    ["Stonetalon Mountains"] = "Les Serres-Rocheuses",
    ["Stranglethorn Vale"] = "Vallée de Strangleronce",
    ["Swamp of Sorrows"] = "Marais des Chagrins",
    ["Tanaris"] = "Tanaris",
    ["Teldrassil"] = "Teldrassil",
    ["The Barrens"] = "Les Tarides",
    ["The Hinterlands"] = "Les Hinterlands",
    ["Thousand Needles"] = "Mille pointes",
    ["Tirisfal Glades"] = "Clairières de Tirisfal",
    ["Un'Goro Crater"] = "Cratère d'Un'Goro",
    ["Western Plaguelands"] = "Maleterres de l'ouest",
    ["Westfall"] = "Marche de l'Ouest",
    ["Wetlands"] = "Les Paluns",
    ["Winterspring"] = "Berceau-de-l'Hiver",
}

function SR.IsFrenchClient()
    return GetLocale and GetLocale() == "frFR"
end

function SR.RegionLabel(region)
    if SR.IsFrenchClient() and SR.FR_REGIONS[region] then return SR.FR_REGIONS[region] end
    return region
end

function SR.RegionNames(region)
    local fr = SR.FR_REGIONS[region]
    if fr and fr ~= region then return {region, fr} end
    return {region}
end

local function localName(id)
    if not SR.IsFrenchClient() then return nil end
    local name = SR.ItemInfo(id)
    if type(name) == "string" and not (issecretvalue and issecretvalue(name)) and name ~= "" then return name end
end

function SR:ItemLabel(id)
    return localName(id) or self.Data.items[id] or tostring(id)
end

function SR:ItemNames(id)
    local names = {self.Data.items[id] or tostring(id)}
    local fr = localName(id)
    if fr and fr ~= names[1] then names[2] = fr end
    return names
end
