# ShareCraft

Addon World of Warcraft pour **WoW Anniversary Edition (TBC)** qui permet d'exporter les recettes de metiers au format CSV, directement depuis le jeu.

Ideal pour suivre sa progression, partager ses recettes ou analyser ses donnees dans Excel / Google Sheets.

## Fonctionnalites

- **Scan automatique** des recettes a l'ouverture d'un metier
- **Export CSV** avec separateur `;` (compatible Excel FR / Google Sheets)
- **Statistiques de l'objet** : Armure, Force, Agilite, Endurance, Intelligence, Esprit
- **Niveaux** : niveau d'objet (ilvl) et niveau requis
- **1 ligne par composant** dans le CSV, ideal pour les tableaux croises dynamiques
- **Liens Wowhead** automatiques pour chaque recette
- **Filtre par categorie** (Cuir, Mailles, Tissu, etc.)
- **Bouton Export CSV** integre a la fenetre de metier
- **Interface ElvUI-compatible** (theme sombre, bordures fines, boutons plats)
- **Donnees persistantes** entre sessions (SavedVariablesPerCharacter)

## Installation

1. Telecharger ou cloner ce depot
2. Copier le dossier `ShareCraft/` dans :
   ```
   World of Warcraft/_anniversary_/Interface/AddOns/ShareCraft/
   ```
3. Verifier que la structure est :
   ```
   Interface/AddOns/ShareCraft/
     ShareCraft.toc
     Data.lua
     Core.lua
     Scanner.lua
     Export.lua
     UI.lua
   ```
4. Relancer le jeu ou taper `/reload`

## Utilisation

### Scan des recettes
Ouvrir un metier chez un PNJ ou via le livre de sorts. Le scan est automatique, un message confirme dans le chat :
```
[ShareCraft] Travail du cuir : 148 recettes scannees.
```

### Interface principale
Taper `/sc` pour ouvrir la fenetre ShareCraft :
- Selectionner un metier dans le dropdown
- Filtrer par categorie (optionnel)
- Cliquer **Exporter en CSV**

### Export rapide
Cliquer le bouton **Export CSV** directement sur la fenetre de metier (scan + export en un clic).

### Copier les donnees
Dans la fenetre d'export :
1. `Ctrl+A` pour tout selectionner
2. `Ctrl+C` pour copier
3. Coller dans un fichier `.csv` ou directement dans Excel / Google Sheets

### Commandes slash

| Commande | Description |
|---|---|
| `/sc` | Ouvre/ferme la fenetre principale |
| `/sc debug` | Active/desactive le mode debug |
| `/sc scan` | Force un scan manuel (fenetre de metier ouverte) |

## Format CSV

Separateur : `;` (point-virgule, compatible Excel FR)

| Colonne | Description |
|---|---|
| Nom du joueur | Nom du personnage |
| Metier | Nom du metier |
| Categorie | Categorie dans le metier (Cuir, Mailles, etc.) |
| Nom de la recette | Nom de la recette |
| Difficulte | Difficulte actuelle (optimal, medium, easy, trivial) |
| Niveau objet | Item level de l'objet craft |
| Niveau requis | Niveau de personnage requis |
| Armure | Points d'armure |
| Force | Stat Force |
| Agilite | Stat Agilite |
| Endurance | Stat Endurance |
| Intelligence | Stat Intelligence |
| Esprit | Stat Esprit |
| Reagent | Nom du composant |
| Quantite | Quantite requise |
| Lien Wowhead | URL vers la recette sur Wowhead |

Chaque recette genere **une ligne par composant**, ce qui permet de creer des tableaux croises dynamiques pour analyser les couts de materiaux.

## Importer dans Excel

1. Copier les donnees depuis la fenetre d'export (`Ctrl+A`, `Ctrl+C`)
2. Ouvrir **Excel** > nouvelle feuille
3. Coller dans la cellule **A1** (`Ctrl+V`)
4. Si les donnees arrivent dans une seule colonne :
   - Selectionner la colonne A
   - Onglet **Donnees** > **Convertir**
   - Choisir **Delimite** > Suivant
   - Cocher **Point-virgule** comme separateur > Terminer

### Mettre en forme

1. Selectionner toutes les donnees (`Ctrl+A`)
2. Onglet **Insertion** > **Tableau** (ou `Ctrl+T`) > cocher "Mon tableau comporte des en-tetes" > OK
3. Chaque colonne a maintenant une **fleche de filtre** dans l'en-tete

### Filtrer les donnees

- Cliquer la fleche d'une colonne pour filtrer (ex: **Categorie** > cocher uniquement "Cuir")
- **Difficulte** : filtrer par `optimal`, `medium`, `easy`, `trivial`
- **Stats** : Filtre numerique > *Superieur a* pour trouver les objets avec beaucoup d'Endurance, etc.
- **Reagent** : filtrer pour voir toutes les recettes utilisant un composant precis

### Tableau croise dynamique

1. Selectionner le tableau > **Insertion** > **Tableau croise dynamique**
2. Exemples d'analyses :
   - **Lignes** : Reagent, **Valeurs** : Somme de Quantite → total de chaque composant necessaire
   - **Lignes** : Nom de la recette, **Colonnes** : Difficulte → repartition par difficulte
   - **Filtre** : Categorie → analyser une seule categorie

## Importer dans Google Sheets

1. Copier les donnees depuis la fenetre d'export (`Ctrl+A`, `Ctrl+C`)
2. Ouvrir **Google Sheets** > nouvelle feuille
3. Coller dans la cellule **A1** (`Ctrl+V`)
4. Si les donnees arrivent dans une seule colonne :
   - Menu **Donnees** > **Scinder le texte en colonnes**
   - Selecteur de separateur > **Point-virgule**

### Mettre en forme

1. Selectionner la ligne 1 (en-tetes) > **Mettre en gras** (`Ctrl+B`)
2. Menu **Affichage** > **Figer** > **1 ligne** (garde les en-tetes visibles au scroll)
3. Selectionner toutes les donnees > Menu **Format** > **Alternance de couleurs** pour un rendu zebré

### Filtrer les donnees

1. Selectionner toutes les donnees > Menu **Donnees** > **Creer un filtre**
2. Cliquer l'icone de filtre sur chaque colonne pour filtrer
3. Utiliser **Filtrer par condition** > *Superieur a* pour les colonnes numeriques (stats, niveaux)

### Tableau croise dynamique

1. Selectionner les donnees > **Insertion** > **Tableau croise dynamique**
2. Memes analyses que pour Excel (voir ci-dessus)

## Structure du projet

```
ShareCraft/
  ShareCraft.toc   -- Metadata addon, version, load order
  Data.lua         -- Constantes (URL Wowhead)
  Core.lua         -- Events, slash commands, debug
  Scanner.lua      -- Scan des recettes, tooltip, stats
  Export.lua       -- Generation CSV, echappement
  UI.lua           -- Fenetres (principale, export, bouton metier)
```

## Compatibilite

- **Client** : WoW Anniversary Edition (TBC)
- **Interface** : 40400
- **UI** : Compatible ElvUI (theme sombre natif)

## Licence

MIT License - Libre d'utilisation, modification et distribution.
