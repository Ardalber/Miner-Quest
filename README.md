# Miner Quest

Petit jeu d'aventure en 2D fait avec **Godot 4.7** : un mineur explore une grotte et descend d'étage en étage.

## But du jeu

- Explore chaque étage : la lampe du casque n'éclaire qu'autour de toi.
- Mine les minerais à la pioche : **cuivre**, **fer** et **or**. Tu peux aussi creuser la roche.
- Fouille les **coffres** cachés dans les recoins : minerais, et parfois une mèche pour agrandir la lumière de ta lampe.
- Améliore ta pioche à la **forge** : bois → cuivre → fer → or → maître.
  - Le fer demande au moins une pioche en cuivre, l'or une pioche en fer.
- Trouve l'**escalier** pour descendre : plus tu descends, plus le fer et l'or sont fréquents.

La partie est sauvegardée automatiquement.

## Commandes

| Action | Ordinateur | Téléphone |
| --- | --- | --- |
| Avancer / miner / ouvrir un coffre | Flèches ou ZQSD | Croix directionnelle |
| Descendre l'escalier | Entrée, Espace ou E | Bouton « Descendre » |
| Forge | F | Bouton « Forge » |
| Menu | Échap | Bouton « Menu » |

## Lancer le jeu

Ouvre `project.godot` avec Godot 4.7, puis appuie sur F5.

Pour jouer sur téléphone, il faut exporter le projet depuis Godot (Projet → Exporter) :
- **Android** : un fichier `.apk` à installer ;
- **Web** : une version jouable dans le navigateur, qui peut être mise en ligne avec GitHub Pages.

## Organisation

- `scenes/main.tscn` : scène principale.
- `scripts/game_data.gd` : minerais, pioches, probabilités.
- `scripts/cave_generator.gd` : génération des étages.
- `scripts/main.gd` : règles du jeu et sauvegarde.
- `scripts/world.gd` : dessin de la grotte et du mineur.
- `scripts/hud.gd` : interface, forge, menu, croix tactile.

## Version Web (téléphone)

Le jeu exporté pour le navigateur est dans `docs/` et publié avec GitHub Pages :
https://ardalber.github.io/Miner-Quest/

Pour la mettre à jour après une modification : dans Godot, Projet → Exporter → « Web » → Exporter le projet (vers `docs/index.html`), puis pousse sur GitHub.
