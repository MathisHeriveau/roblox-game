# Passe de saison — proposition (à valider)

Statut : **proposition**, rien n'est codé. Les points marqués **[À DÉCIDER]** attendent ton choix.

## But

1. Donner une raison de revenir chaque jour et chaque semaine (rétention).
2. Gagner des Robux avec un palier premium, **sans pay-to-win** qui casserait les raids.
3. Rester simple à coder et à faire tourner : une saison = un fichier de config.

## Comment ça marche pour le joueur

- Une **saison dure 28 jours** et a **30 paliers**. [À DÉCIDER : 28 j / 30 paliers]
- On gagne des **⭐ Étoiles de saison** en jouant :

  | Action | Étoiles |
  |---|---|
  | Livrer un éclat | 1 (Commun) → 12 (Cosmique), ×2 si shiny |
  | Attraper le cœur d'une comète | 25 |
  | Cadeau du jour | 30 |
  | Quête du jour (3 par jour, ex. « livre 20 éclats », « bump 3 voleurs ») | 40 chacune |

- Réglage visé : environ **30 min par jour** pour finir la piste gratuite en ~3 semaines.
  Un joueur qui ne vient que le week-end en fait la moitié.
- Deux pistes de récompenses, côte à côte dans un nouveau panneau **🎟️ SAISON** (bouton ajouté
  au rail d'icônes) :
  - **Gratuite** (tout le monde) : pièces, boosts ×2 revenus 15 min, un titre, une traînée.
  - **Premium** (payante) : tout le cosmétique exclusif de la saison (voir plus bas).
- Acheter le premium en cours de saison débloque **rétroactivement** les paliers déjà atteints.

## Récompenses premium : cosmétique d'abord

Recommandation : **100 % cosmétique + confort léger**. Rien qui fasse gagner un raid.

- Une **Starling de saison** exclusive (ex. « Starling Aurore »), avec le revenu d'une Épique :
  elle se remarque, mais ne domine pas.
- Des **skins de Starling** (contour doré, aura) qui s'appliquent à tes Starlings.
- Des **thèmes de base** (sol et clôture de ta parcelle).
- Des **traînées** de personnage et un **titre** au-dessus de la tête.
- Confort : +1 quête par jour. [À DÉCIDER : on garde ce confort ou 100 % cosmétique ?]

## Prix

- **399 R$** pour le premium de la saison. [À DÉCIDER]
- Option plus tard : 899 R$ « premium + 10 paliers ».
- Pour info, tu touches ~70 % des Robux dépensés (Roblox prend 30 %). Les Robux gagnés se
  convertissent en argent via DevEx, sous les conditions de Roblox.

## Côté technique (pour info)

- Achat via un **Developer Product** (un seul produit réutilisé à chaque saison) :
  - le serveur valide l'achat dans `ProcessReceipt` et enregistre chaque reçu, pour ne jamais
    créditer deux fois ni perdre un achat ;
  - c'est le schéma recommandé par Roblox.
- Données joueur, schéma v5 : `pass = { season, stars, claimedFree, claimedPremium,
  premiumSeasons }` + le journal des reçus. Migration, validation et tests comme d'habitude.
- Les saisons sont dans un fichier de config (dates, paliers, récompenses). Changer de saison =
  modifier la config, pas le code.
- Sécurité : le client n'envoie que des intentions (« réclamer le palier 12 »). Le serveur
  vérifie les étoiles, la piste et l'achat.

## Ce qu'il faut de ton côté (le moment venu)

1. Publier le jeu. Il doit être **public** pour vendre.
2. Créer le Developer Product sur le Creator Hub (nom, prix, image) et me donner son ID.
3. Tester dans Studio : les achats y sont simulés, gratuits.

## Ordre de travail proposé

1. Quêtes du jour (utiles même sans passe).
2. Étoiles de saison + piste gratuite + panneau 🎟️.
3. Piste premium + achat sécurisé, après ta validation du prix et des récompenses.
