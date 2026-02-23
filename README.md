# pandemie

## Niveaux d'infection

1. **Incubation** : non contagieux.
2. **Légèrement malade** : contagieux pour les joueurs proches.
3. **Malade** : contagieux pour les joueurs proches.
4. **Gravement malade** : contagieux pour les joueurs proches, puis mort automatique après 10 minutes sans soins.

La contamination est possible à partir du niveau **2** si un autre joueur sain est dans le rayon configuré (`Config.SpreadRadius`).

## Zones contagieuses dynamiques

- Un admin peut ouvrir le menu via la commande `/infection_zones`.
- Depuis ce menu, il peut ajouter/supprimer des zones contagieuses.
- Les zones affichent une fumée verte.
- Sans masque, entrer dans la zone infecte immédiatement le joueur.
- Rester trop longtemps dans la zone provoque la mort.

> Remarque: les zones créées via menu sont en mémoire (elles disparaissent au redémarrage). Pour des zones persistantes, renseigner `Config.ContagiousZones`.
