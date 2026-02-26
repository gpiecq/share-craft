# Changelog

## [2.0.1] - 2026-02-26

### Corrections
- Description des enchantements manquante (fallback via GetCraftDescription)
- Crash/deconnexion lors de la synchronisation guilde (flood de messages addon)
- Messages addon recus en double par le client WoW (deduplication)
- Reponses REQUEST repetees au meme joueur (cooldown 60s)
- Timeout des chunks trop court pour les gros transferts (60s → 180s)
- Metiers desappris toujours partages a la guilde (nettoyage automatique via GetProfessions)

### Technique
- File d'attente globale pour les messages sortants (QueueMessage/ProcessQueue)
- SendHello n'envoie plus que ses propres donnees (suppression du relay)
- Intervalle entre messages : 0.2s → 0.5s
- Message de confirmation apres synchronisation (`/sc sync`)

## [2.0.0] - 2026-02-24

### Ajouts
- Synchronisation des recettes entre membres de guilde via canal addon GUILD
- Protocole hash-based (HELLO/REQUEST/DATA/DATACHUNK/PRIVACY) avec chunking
- Onglet "Guilde" : recherche par joueur, metier et recette
- Onglet "Membres" : liste des joueurs synchronises avec nombre de recettes et date
- Export CSV des recettes de guilde (memes colonnes + "Dernier scan")
- Systeme de vie privee par metier (opt-in par defaut)
- Bouton minimap
- Tooltip enrichi : survoler un objet montre les artisans de guilde
- Localisation complete FR/EN (UI, messages, CSV headers, patterns de parsing)

### Technique
- Nouveaux fichiers : GuildDB.lua, Comm.lua
- Table SC.L partagee dans Data.lua pour la localisation
- SavedVariables : ShareCraftGuildDB (donnees guilde, partagees entre personnages)
- Nouvelles commandes : `/sc sync`, `/sc privacy`

## [1.0.1] - 2026-02-21

### Ajouts
- Support de l'Enchantement (CraftFrame API separee en TBC)
- Bouton Export CSV sur la fenetre d'Enchantement
- Guide Excel et Google Sheets dans le README

### Corrections
- Remplacement du filtre par extension par un filtre par categorie (les headers TBC sont par categorie, pas par extension)
- Correction des liens Wowhead (tbc au lieu de classic)
- Correction des permissions GitHub Action pour la creation de release
- Correction du format zip (fichiers a la racine pour extraction Windows)

## [1.0.0] - 2026-02-21

### Premiere version
- Scan automatique des recettes a l'ouverture d'un metier
- Export CSV avec separateur `;`
- Stats de l'objet (Armure, Force, Agilite, Endurance, Intelligence, Esprit)
- Niveaux (ilvl, niveau requis)
- 1 ligne par composant pour tableaux croises dynamiques
- Liens Wowhead automatiques
- Filtre par categorie
- Bouton Export CSV sur la fenetre de metier
- Interface ElvUI-compatible
- Commandes : /sc, /sc debug, /sc scan
