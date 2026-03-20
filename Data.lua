local addonName, SC = ...

-- Wowhead base URL
SC.WOWHEAD_BASE = "https://www.wowhead.com/tbc/spell="

-- Communication constants (guild sync)
SC.COMM_PREFIX = "ShareCraft"
SC.COMM_VERSION = 3
SC.MAX_PAYLOAD = 240
SC.SYNC_COOLDOWN = 300       -- 5min between syncs with same player
SC.CHUNK_INTERVAL = 0.5      -- delay between outgoing messages (throttle)
SC.BUFFER_TIMEOUT = 180      -- seconds before incomplete chunk buffers are cleaned
SC.MEMBER_MAX_AGE = 30 * 24 * 3600  -- 30 days before old members are cleaned

-- ============================================================
-- Profession cross-locale mapping
-- ============================================================

-- Profession base spell IDs (same across all locales)
local PROF_SPELL_IDS = {
    2259, 2018, 7411, 4036, 2366, 45357, 25229, 2108, 2575, 8613, 3908, 2550, 3273, 7620, 78670
}

-- Hardcoded profession names for cross-locale matching (EN + FR)
local PROF_NAMES_BY_ID = {
    [2259]  = { "Alchemy", "Alchimie" },
    [2018]  = { "Blacksmithing", "Forge" },
    [7411]  = { "Enchanting", "Enchantement" },
    [4036]  = { "Engineering", "Ingénierie", "Ingenierie" },
    [2366]  = { "Herbalism", "Herboristerie" },
    [45357] = { "Inscription", "Calligraphie" },
    [25229] = { "Jewelcrafting", "Joaillerie" },
    [2108]  = { "Leatherworking", "Travail du cuir" },
    [2575]  = { "Mining", "Minage" },
    [8613]  = { "Skinning", "Dépeçage", "Depeçage" },
    [3908]  = { "Tailoring", "Couture" },
    [2550]  = { "Cooking", "Cuisine" },
    [3273]  = { "First Aid", "Secourisme", "Premiers soins" },
    [7620]  = { "Fishing", "Pêche", "Peche" },
    [78670] = { "Archaeology", "Archéologie", "Archeologie" },
}

-- Runtime lookup: any known profession name (any locale) -> spell ID
SC.profNameToID = {}

-- Build the profession name -> ID mapping (call after PLAYER_ENTERING_WORLD)
function SC:BuildProfessionMap()
    -- Hardcoded names (EN + FR + accent variants)
    for spellID, names in pairs(PROF_NAMES_BY_ID) do
        for _, name in ipairs(names) do
            SC.profNameToID[name] = spellID
        end
    end
    -- Add current client locale names via GetSpellInfo
    for _, spellID in ipairs(PROF_SPELL_IDS) do
        local name = GetSpellInfo(spellID)
        if name then
            SC.profNameToID[name] = spellID
        end
    end
end

-- Check if two profession names refer to the same profession
function SC:SameProfession(name1, name2)
    if name1 == name2 then return true end
    local id1 = SC.profNameToID[name1]
    local id2 = SC.profNameToID[name2]
    return id1 ~= nil and id1 == id2
end

-- Get the localized profession name for the current client
function SC:GetLocalProfName(profName)
    local id = SC.profNameToID[profName]
    if id then
        local localName = GetSpellInfo(id)
        if localName then return localName end
    end
    return profName
end

-- ============================================================
-- Localization
-- ============================================================

local L = {}

if GetLocale() == "frFR" then

    -- Tabs
    L.tab_welcome  = "Bienvenue"
    L.tab_recipes  = "Mes recettes"
    L.tab_guild    = "Guilde"
    L.tab_members  = "Membres"

    -- Welcome
    L.welcome_title      = "Bienvenue sur ShareCraft !"
    L.welcome_commands   = "Commandes"
    L.cmd_sc             = "/sc : Ouvrir/fermer cette fenetre"
    L.cmd_scan           = "/sc scan : Scanner manuellement le metier ouvert"
    L.cmd_sync           = "/sc sync : Forcer la synchronisation avec la guilde"
    L.cmd_privacy        = "/sc privacy : Gerer la vie privee des metiers"
    L.cmd_debug          = "/sc debug : Activer/desactiver le mode debug"

    L.welcome_recipes      = "Mes recettes"
    L.welcome_recipes_text = "Ouvrez la fenetre d'un metier (forge, couture, etc.) pour scanner automatiquement vos recettes. Elles apparaissent dans l'onglet \"Mes recettes\" avec les couleurs de rarete. Cliquez sur \"Exporter en CSV\" pour copier les donnees."

    L.welcome_guild      = "Guilde"
    L.welcome_guild_text = "Les recettes sont synchronisees automatiquement entre les membres de guilde qui ont l'addon. Quand vous ouvrez un metier, vos recettes sont partagees. Quand un membre se connecte, ses recettes sont recuperees. Utilisez les filtres Joueur, Metier et Recette pour chercher. Un joueur connecte peut aussi relayer les recettes d'un joueur deconnecte."

    L.welcome_members      = "Membres"
    L.welcome_members_text = "Liste de tous les joueurs synchronises avec leurs metiers, le nombre de recettes et la date de derniere synchronisation."

    L.welcome_privacy      = "Vie privee"
    L.welcome_privacy_text = "Par defaut, tous vos metiers sont partages. Ouvrez les reglages avec le bouton \"Vie privee\" ou /sc privacy. Decochez un metier pour ne plus le partager avec la guilde."

    L.welcome_csv      = "Export CSV"
    L.welcome_csv_text = "Le format CSV utilise le point-virgule (;) comme separateur, compatible avec Excel. Dans la fenetre d'export : Ctrl+A pour tout selectionner, puis Ctrl+C pour copier. L'export guilde contient les memes colonnes que l'export personnel (stats, reagents, lien Wowhead) quand les donnees sont disponibles localement."

    L.welcome_tooltip      = "Tooltip"
    L.welcome_tooltip_text = "Survolez un objet dans le jeu (sac, hotel de vente, lien dans le chat, etc.) : si un membre de guilde sait le fabriquer, son nom et son metier apparaissent en bas du tooltip."

    -- Tooltip (recipe details)
    L.tooltip_item_level    = "Niveau objet : %d"
    L.tooltip_armor         = "%d Armure"
    L.tooltip_strength      = "+%d Force"
    L.tooltip_agility       = "+%d Agilite"
    L.tooltip_stamina       = "+%d Endurance"
    L.tooltip_intellect     = "+%d Intelligence"
    L.tooltip_spirit        = "+%d Esprit"
    L.tooltip_required_level = "Niveau %d requis"
    L.tooltip_reagents      = "Composants :"
    L.tooltip_no_details    = "Pas de details disponibles"

    -- Labels, dropdowns, buttons
    L.label_profession    = "Metier"
    L.label_category      = "Categorie"
    L.label_player        = "Joueur"
    L.label_recipe        = "Recette"
    L.label_recipes_count = "Recettes : %d"
    L.label_all           = "Tous"
    L.label_select        = "Selectionner..."
    L.label_other         = "Autre"

    L.btn_export_csv       = "Exporter en CSV"
    L.btn_export_csv_short = "Exporter CSV"
    L.btn_privacy          = "Vie privee"
    L.btn_sync             = "Sync"

    -- Messages
    L.msg_no_profession       = "Aucun metier selectionne."
    L.msg_manual_sync         = "Synchronisation manuelle..."
    L.msg_sync_sent           = "Donnees envoyees a la guilde (%d metier(s))."
    L.msg_no_profession_open  = "Aucun metier ouvert."
    L.msg_no_recipes_export   = "Aucune recette a exporter pour ce filtre."
    L.msg_no_guild_export     = "Aucune recette de guilde a exporter."
    L.msg_no_profession_scanned = "Aucun metier scanne"

    -- Guild results
    L.guild_results      = "Resultats : %d recettes de %d joueurs"
    L.guild_results_zero = "Resultats : 0 recettes de 0 joueurs"

    -- Members
    L.members_none        = "Aucun membre synchronise."
    L.members_count_zero  = "0 membres"
    L.members_count       = "%d membre%s"
    L.members_me          = "(moi)"
    L.members_recipes_fmt = "%s - %d recettes (%s)"

    -- Export window
    L.export_instructions    = "Ctrl+A pour tout selectionner, puis Ctrl+C pour copier"
    L.export_title_personal  = "ShareCraft - Export CSV (%d recettes)"
    L.export_title_guild     = "ShareCraft - Export Guilde CSV (%d recettes)"

    -- Privacy
    L.privacy_title        = "Vie privee - Partage"
    L.privacy_instructions = "Cochez les metiers a partager :"
    L.privacy_no_data      = "Aucun metier scanne."
    L.privacy_prof_fmt     = "%s (%d recettes)"

    -- Minimap
    L.minimap_click      = "Clic pour ouvrir"
    L.tooltip_sharecraft  = "ShareCraft"

    -- Core messages
    L.msg_addon_loaded    = "Addon charge. Tapez /sc pour ouvrir."
    L.msg_debug_enabled   = "Debug active"
    L.msg_debug_disabled  = "Debug desactive"
    L.msg_scan_manual     = "Scan manuel..."

    -- Scanner messages
    L.scan_recipes_count  = "%s : %d recettes scannees."
    L.scan_new_recipes    = "nouvelles recettes detectees"
    L.scan_recipes        = "%d recettes"
    L.scan_sync_msg       = "%s : %s, synchronisation guilde..."
    L.scan_no_change      = "%s : aucun changement, pas de sync"

    -- Scanner patterns (green lines)
    L.green_patterns = {
        "^Utiliser",
        "^Équipé",
        "^équipé",
        "^Chance quand",
        "^Complet",
        "^Toucher :",
    }

    -- Scanner patterns (armor)
    L.stat_armor_patterns = {
        "^(%d+) [Aa]rmure",
        "^(%d+) points d'armure",
    }

    -- Scanner stat name mapping (localized name -> internal key)
    L.stat_names = {
        { pattern = "force",        key = "strength" },
        { pattern = "agilit",       key = "agility" },
        { pattern = "endurance",    key = "stamina" },
        { pattern = "intelligence", key = "intellect" },
        { pattern = "intellect",    key = "intellect" },
        { pattern = "esprit",       key = "spirit" },
        { pattern = "spirit",       key = "spirit" },
    }

    -- CSV headers
    L.csv_player         = "Nom du joueur"
    L.csv_profession     = "Metier"
    L.csv_category       = "Categorie"
    L.csv_recipe_name    = "Nom de la recette"
    L.csv_difficulty     = "Difficulte"
    L.csv_item_level     = "Niveau objet"
    L.csv_required_level = "Niveau requis"
    L.csv_armor          = "Armure"
    L.csv_strength       = "Force"
    L.csv_agility        = "Agilite"
    L.csv_stamina        = "Endurance"
    L.csv_intellect      = "Intelligence"
    L.csv_spirit         = "Esprit"
    L.csv_reagent        = "Reagent"
    L.csv_quantity        = "Quantite"
    L.csv_wowhead        = "Lien Wowhead"
    L.csv_last_scan      = "Dernier scan"

else -- English (default)

    -- Tabs
    L.tab_welcome  = "Welcome"
    L.tab_recipes  = "My recipes"
    L.tab_guild    = "Guild"
    L.tab_members  = "Members"

    -- Welcome
    L.welcome_title      = "Welcome to ShareCraft!"
    L.welcome_commands   = "Commands"
    L.cmd_sc             = "/sc : Open/close this window"
    L.cmd_scan           = "/sc scan : Manually scan the open profession"
    L.cmd_sync           = "/sc sync : Force guild synchronization"
    L.cmd_privacy        = "/sc privacy : Manage profession privacy"
    L.cmd_debug          = "/sc debug : Toggle debug mode"

    L.welcome_recipes      = "My recipes"
    L.welcome_recipes_text = "Open a profession window (blacksmithing, tailoring, etc.) to automatically scan your recipes. They appear in the \"My recipes\" tab with rarity colors. Click \"Export to CSV\" to copy the data."

    L.welcome_guild      = "Guild"
    L.welcome_guild_text = "Recipes are automatically synchronized between guild members who have the addon. When you open a profession, your recipes are shared. When a member logs in, their recipes are retrieved. Use the Player, Profession, and Recipe filters to search. A connected player can also relay recipes from an offline player."

    L.welcome_members      = "Members"
    L.welcome_members_text = "List of all synchronized players with their professions, recipe count, and last synchronization date."

    L.welcome_privacy      = "Privacy"
    L.welcome_privacy_text = "By default, all your professions are shared. Open the settings with the \"Privacy\" button or /sc privacy. Uncheck a profession to stop sharing it with the guild."

    L.welcome_csv      = "CSV Export"
    L.welcome_csv_text = "The CSV format uses semicolons (;) as separators, compatible with Excel. In the export window: Ctrl+A to select all, then Ctrl+C to copy. The guild export contains the same columns as the personal export (stats, reagents, Wowhead link) when data is available locally."

    L.welcome_tooltip      = "Tooltip"
    L.welcome_tooltip_text = "Hover over an item in the game (bag, auction house, chat link, etc.): if a guild member can craft it, their name and profession appear at the bottom of the tooltip."

    -- Tooltip (recipe details)
    L.tooltip_item_level    = "Item Level: %d"
    L.tooltip_armor         = "%d Armor"
    L.tooltip_strength      = "+%d Strength"
    L.tooltip_agility       = "+%d Agility"
    L.tooltip_stamina       = "+%d Stamina"
    L.tooltip_intellect     = "+%d Intellect"
    L.tooltip_spirit        = "+%d Spirit"
    L.tooltip_required_level = "Requires Level %d"
    L.tooltip_reagents      = "Reagents:"
    L.tooltip_no_details    = "No details available"

    -- Labels, dropdowns, buttons
    L.label_profession    = "Profession"
    L.label_category      = "Category"
    L.label_player        = "Player"
    L.label_recipe        = "Recipe"
    L.label_recipes_count = "Recipes: %d"
    L.label_all           = "All"
    L.label_select        = "Select..."
    L.label_other         = "Other"

    L.btn_export_csv       = "Export to CSV"
    L.btn_export_csv_short = "Export CSV"
    L.btn_privacy          = "Privacy"
    L.btn_sync             = "Sync"

    -- Messages
    L.msg_no_profession       = "No profession selected."
    L.msg_manual_sync         = "Manual synchronization..."
    L.msg_sync_sent           = "Data sent to guild (%d profession(s))."
    L.msg_no_profession_open  = "No profession open."
    L.msg_no_recipes_export   = "No recipes to export for this filter."
    L.msg_no_guild_export     = "No guild recipes to export."
    L.msg_no_profession_scanned = "No profession scanned"

    -- Guild results
    L.guild_results      = "Results: %d recipes from %d players"
    L.guild_results_zero = "Results: 0 recipes from 0 players"

    -- Members
    L.members_none        = "No synchronized members."
    L.members_count_zero  = "0 members"
    L.members_count       = "%d member%s"
    L.members_me          = "(me)"
    L.members_recipes_fmt = "%s - %d recipes (%s)"

    -- Export window
    L.export_instructions    = "Ctrl+A to select all, then Ctrl+C to copy"
    L.export_title_personal  = "ShareCraft - CSV Export (%d recipes)"
    L.export_title_guild     = "ShareCraft - Guild CSV Export (%d recipes)"

    -- Privacy
    L.privacy_title        = "Privacy - Sharing"
    L.privacy_instructions = "Check the professions to share:"
    L.privacy_no_data      = "No profession scanned."
    L.privacy_prof_fmt     = "%s (%d recipes)"

    -- Minimap
    L.minimap_click      = "Click to open"
    L.tooltip_sharecraft  = "ShareCraft"

    -- Core messages
    L.msg_addon_loaded    = "Addon loaded. Type /sc to open."
    L.msg_debug_enabled   = "Debug enabled"
    L.msg_debug_disabled  = "Debug disabled"
    L.msg_scan_manual     = "Manual scan..."

    -- Scanner messages
    L.scan_recipes_count  = "%s: %d recipes scanned."
    L.scan_new_recipes    = "new recipes detected"
    L.scan_recipes        = "%d recipes"
    L.scan_sync_msg       = "%s: %s, guild sync..."
    L.scan_no_change      = "%s: no change, skipping sync"

    -- Scanner patterns (green lines)
    L.green_patterns = {
        "^Use:",
        "^Equip:",
        "^Chance on",
        "^Set:",
        "^Hit:",
    }

    -- Scanner patterns (armor)
    L.stat_armor_patterns = {
        "^(%d+) [Aa]rmor",
    }

    -- Scanner stat name mapping (localized name -> internal key)
    L.stat_names = {
        { pattern = "strength",  key = "strength" },
        { pattern = "agility",   key = "agility" },
        { pattern = "stamina",   key = "stamina" },
        { pattern = "intellect", key = "intellect" },
        { pattern = "spirit",    key = "spirit" },
    }

    -- CSV headers
    L.csv_player         = "Player"
    L.csv_profession     = "Profession"
    L.csv_category       = "Category"
    L.csv_recipe_name    = "Recipe Name"
    L.csv_difficulty     = "Difficulty"
    L.csv_item_level     = "Item Level"
    L.csv_required_level = "Required Level"
    L.csv_armor          = "Armor"
    L.csv_strength       = "Strength"
    L.csv_agility        = "Agility"
    L.csv_stamina        = "Stamina"
    L.csv_intellect      = "Intellect"
    L.csv_spirit         = "Spirit"
    L.csv_reagent        = "Reagent"
    L.csv_quantity        = "Quantity"
    L.csv_wowhead        = "Wowhead Link"
    L.csv_last_scan      = "Last Scan"

end

SC.L = L
