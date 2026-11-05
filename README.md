# Thème HE-Arc Ingénierie pour examens — extension Quarto

Ce format Quarto produit, à partir d'un seul fichier `.qmd`, l'**énoncé** d'un examen HE-Arc (avec des boîtes de réponse) et son **corrigé** (avec les solutions), tous deux en PDF.

## Installation

Dans un nouveau dossier, pour récupérer le gabarit complet (extension, `_quarto.yml` et `CP_exemple.qmd`) :

```bash
quarto use template fabrizioalbertetti/quarto_theme_hearc_exams
```

Pour ajouter seulement l'extension à un projet existant :

```bash
quarto add fabrizioalbertetti/quarto_theme_hearc_exams
```

## Utilisation

```bash
quarto render CP_exemple.qmd                                   # énoncé + corrigé
quarto render CP_exemple.qmd --to theme-hearc-exams-pdf           # énoncé seul
quarto render CP_exemple.qmd --to theme-hearc-exams-pdf+solution  # corrigé seul
```

Les variables de l'examen se trouvent dans l'en-tête YAML du `.qmd` :

```yaml
---
title: "Contrôle Principal (ISC3-id)"

exam:
  classe: ISC3
  annee: 2026-2027
  date: 08.01.2027        # pied de page à droite
  type: CP                # pied de page du corrigé : "Corrigé CP"
  materiel: aucun
  duree: 90 minutes
  points: 38
  nom: true               # cadre NOM / Prénom dans l'énoncé
  # logo: mon-logo.png    # par défaut : logo HE-Arc fourni par l'extension

format:
  theme-hearc-exams-pdf:                # énoncé
    output-file: CP_exemple.pdf
  theme-hearc-exams-pdf+solution:       # corrigé
    output-file: CP_exemple_solution.pdf
    metadata:
      solution: true                    # indispensable pour obtenir le corrigé
---
```

Les variables communes à plusieurs examens (par exemple `exam.classe` ou `exam.annee`) peuvent être déplacées dans `_quarto.yml`. Les valeurs du `.qmd` ont la priorité.

Le bloc « Matériel autorisé / Durée / Total de points » et le cadre NOM / Prénom sont générés automatiquement en début de document à partir de ces variables. Une variable absente fait disparaître sa ligne.

## Syntaxe dans le `.qmd`

| Syntaxe | Énoncé | Corrigé |
|---|---|---|
| `::: {.sol reponse="3cm"}` … `:::` | boîte de réponse vide (3 cm par défaut) | contenu sur fond rouge pâle, filet rouge à gauche |
| `::: {.exam}` … `:::` | contenu encadré | masqué |
| `\sautpage` | saut de page | rien |
| `[texte]{.rouge}` (`.bleu`, `.vert`, `.orange`, `.gris`) | texte en couleur | texte en couleur |

Les styles TikZ `aut`, `op` et `couture` (bibliothèques `automata`, `positioning`, `arrows.meta`) sont chargés automatiquement.

## Fichiers de l'extension

```
_extensions/theme-hearc-exams/
├── _extension.yml        format theme-hearc-exams-pdf (KOMA scrartcl, A4, marges, filtres)
├── hearc-exam.tex        en-tête/pied, boîtes, couleurs, TikZ
├── solution.lua          énoncé/corrigé, variables exam.*, bloc d'informations
├── couleurs.lua          [texte]{.couleur}
└── logo-he-arc-ing.jpg
```
