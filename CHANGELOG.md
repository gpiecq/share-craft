# Changelog

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
