# Guide de démo — Jeu de données de test + script de présentation

Ce document te donne :
1. **Les données à saisir** (fournisseurs, articles, clients, personnel, commerciaux) pour peupler l'app avant ta démo.
2. **Un scénario de test pas à pas** qui active tous les modules (Articles, Chargements, Dépenses, Personnel, Paie, Commissions) avec des résultats attendus précis, pour que tu puisses vérifier que tout fonctionne — y compris le **coût de revient réel par article** (la fonctionnalité phare de cette version).
3. **Un script de pitch** — les phrases et l'ordre de démonstration qui mettent en valeur ce que tu viens de faire construire, pensé pour convaincre un patron de commerce de pneus.

Tout est en FCFA, avec des noms et données réalistes pour le Mali. Suis l'ordre des sections : certaines données dépendent des précédentes (ex : un achat a besoin d'un article et d'un fournisseur déjà créés).

**Base de données remise à zéro** — la prochaine ouverture de l'app repart d'une base neuve (schéma le plus récent, catégories/postes déjà pré-remplis). Refais toute la saisie ci-dessous depuis le début.

### Ce qui est nouveau dans cette version
- **Coût de revient RÉEL par article**, plus une moyenne unique par chargement : deux pneus achetés à des prix différents dans le même chargement gardent chacun leur propre coût.
- **Répartition des dépenses partagées** au choix : par quantité, par valeur d'achat, par poids, ou manuellement article par article.
- **Nom de chargement** éditable ("Chargement Bamako Août"...), plus seulement un numéro automatique.
- **Tableau détail par article** sur la fiche chargement (Qté / Achat·U / Part dépenses·U / Revient·U / Vente·U / Marge·U / Marge totale), en plus de la synthèse globale.
- **Clôturer / Réouvrir un chargement** : une fois clôturé, son coût de revient reste figé même si une dépense arrive en retard.
- Le menu **"Pneus"** s'appelle désormais **"Articles"** dans toute l'interface (le vocabulaire pneu — dimension, marque, poids... — reste bien sûr disponible sur la fiche article).

---

## 1. Données à saisir

### 1.1 Fournisseurs (module Fournisseurs — existant)

| Nom | Téléphone | Adresse |
|---|---|---|
| Sino Tires Import | +223 76 00 11 22 | Zone industrielle, Bamako |
| CFAO Mali Pneus | +223 66 33 44 55 | Route de Sotuba, Bamako |

### 1.2 Articles — 10 types de pneus (module Articles)

Le code (`ART-XXXX`) se génère automatiquement, tu n'as qu'à remplir le nom et les prix.

| Nom | Prix d'achat | Prix de vente | Stock minimum |
|---|---:|---:|---:|
| Pneu Tourisme 175/70R13 | 16 000 | 24 000 | 5 |
| Pneu Tourisme 185/65R14 | 18 000 | 26 000 | 5 |
| Pneu Tourisme 195/65R15 | 21 000 | 30 000 | 5 |
| Pneu Tourisme 205/55R16 | 24 000 | 34 000 | 5 |
| Pneu SUV 215/65R16 | 32 000 | 45 000 | 5 |
| Pneu 4x4 235/75R15 | 38 000 | 52 000 | 3 |
| Pneu 4x4 265/65R17 | 45 000 | 62 000 | 3 |
| Pneu Camionnette 750R16 | 48 000 | 65 000 | 3 |
| Pneu Poids Lourd 900R20 | 125 000 | 160 000 | 2 |
| Pneu Moto 110/90-17 | 9 000 | 14 000 | 10 |

**Astuce démo :** ne mets pas de stock tout de suite pour "Pneu Tourisme 205/55R16", "Pneu SUV 215/65R16" et "Pneu 4x4 235/75R15" — ces trois-là vont entrer en stock via le **Chargement** de l'étape 1, à des prix d'achat différents, ce qui est justement ce qu'on veut démontrer.

*(Bonus, pas obligatoire pour la démo : le champ "Poids (kg)" sur la fiche article sert uniquement si tu choisis un jour la méthode de répartition "par poids" pour une dépense partagée — inutile de le remplir maintenant.)*

### 1.3 Clients (module Clients — existant)

| Nom | Type | Téléphone | Adresse |
|---|---|---|---|
| Garage Moderne Bamako | Entreprise | +223 76 12 34 56 | Hamdallaye ACI 2000, Bamako |
| Ibrahim Coulibaly | Particulier | +223 65 22 33 44 | Badalabougou, Bamako |
| Transport Diarra & Frères | Entreprise (flotte camions) | +223 76 55 66 77 | Zone Industrielle, Bamako |
| Aminata Traoré | Particulière | +223 90 11 22 33 | Sabalibougou, Bamako |
| Sogoba Auto Pièces | Revendeur | +223 79 88 77 66 | Médina Coura, Bamako |

### 1.4 Personnel — 2 employés non-commerciaux (module Personnel)

| Nom Prénom | Poste | Date d'embauche | Contrat | Salaire de base |
|---|---|---:|---:|---:|
| Keita Moussa | Magasinier | 01/03/2024 | CDI | 100 000 F |
| Sidibé Fatoumata | Comptable | 15/01/2023 | CDI | 150 000 F |

### 1.5 Personnel — 3 commerciaux (module Personnel + Commissions)

Crée-les d'abord comme employés (poste **Commercial**), puis ouvre chaque fiche pour lui définir sa commission dans la section "Configuration commerciale".

| Nom Prénom | Date d'embauche | Contrat | Salaire de base | Type de commission | Valeur |
|---|---|---:|---:|---|---:|
| Diallo Sékou | 01/06/2025 | CDI | 75 000 F | Fixe | 1 000 F / article |
| Doumbia Awa | 10/02/2025 | CDI | 75 000 F | Pourcentage | 10 % |
| Traoré Boubacar | 20/09/2025 | Journalier | 60 000 F | Fixe | 800 F / article |

> On a volontairement mis **un commercial en pourcentage** et **deux en montant fixe** : ça te permet de montrer les deux modes de commission au client dans la même démo.

---

## 2. Scénario de test pas à pas

Suis ces étapes dans l'ordre. Chaque étape indique où cliquer et **ce que tu dois voir** pour confirmer que ça marche.

### Étape 1 — Chargement nommé, 3 articles à 3 prix différents, dépenses partagées (le cœur de la démo)

1. **Chargements → Nouveau chargement.**
   - **Nom du chargement : "Chargement Bamako Août"** (tape-le vraiment dans le champ, ce n'est plus juste dans ta tête).
   - Fournisseur : *Sino Tires Import*. Date : aujourd'hui.
2. **Achats → Nouvel achat fournisseur.** Fournisseur : *Sino Tires Import*. Rattache-le au chargement "Chargement Bamako Août" (menu déroulant "Chargement"). Ajoute **3 lignes dans le même achat** :

   | Article | Quantité | Prix d'achat unitaire | Total |
   |---|---:|---:|---:|
   | Pneu Tourisme 205/55R16 | 60 | 24 000 F | 1 440 000 F |
   | Pneu SUV 215/65R16 | 40 | 32 000 F | 1 280 000 F |
   | Pneu 4x4 235/75R15 | 20 | 38 000 F | 760 000 F |

   Total achat : **3 480 000 F**. Valide (réception immédiate).
   → Vérifie que les 3 stocks montent bien à 60 / 40 / 20.
3. Retourne sur la fiche du chargement, section **Dépenses liées → Ajouter une dépense**. Pour chacune, laisse la méthode de répartition sur **"Par quantité"** (elle est déjà partagée entre les 3 articles, pas liée à un seul) :
   - Transport — 150 000 F
   - Douane — 300 000 F
   - Transitaire — 80 000 F
   - Manutention — 40 000 F

   Total dépenses partagées : **570 000 F**, réparties sur 120 pneus reçus = **4 750 F/pneu**, quelle que soit la ligne.
4. Regarde le nouveau tableau **"Détail par article"** sur la fiche chargement — c'est le morceau de bravoure de la démo :

   | Article | Qté | Achat/U | Part dépenses/U | Revient/U | Vente/U | Marge/U | Marge totale |
   |---|---:|---:|---:|---:|---:|---:|---:|
   | 205/55R16 | 60 | 24 000 | 4 750 | **28 750** | 34 000 | 5 250 | 315 000 |
   | SUV 215/65R16 | 40 | 32 000 | 4 750 | **36 750** | 45 000 | 8 250 | 330 000 |
   | 4x4 235/75R15 | 20 | 38 000 | 4 750 | **42 750** | 52 000 | 9 250 | 185 000 |

   Juste en dessous, la **synthèse globale** (indicateur secondaire) affiche coût total 4 050 000 F et une moyenne 33 750 F/pneu — **volontairement affichée en second**, jamais en premier.
5. Une fois toutes les dépenses saisies, clique **Clôturer** en haut de la fiche : le coût de revient de ce chargement est maintenant figé, même si une facture de douane arrive en retard le mois prochain.

**C'est ton argument choc n°1 pour le client** : *"Avec l'ancienne méthode — une seule moyenne pour tout le chargement — vous auriez cru que le 205/55R16 ne vous rapportait que 250 F par pneu (34 000 − 33 750). En réalité, il vous rapporte 5 250 F, vingt fois plus. Et à l'inverse, vous auriez cru que le 4x4 vous rapportait 18 250 F par pneu, alors qu'en réalité c'est deux fois moins, 9 250 F. La moyenne ne ment pas sur le total — mais elle ment complètement sur CHAQUE article."*

### Étape 2 — Vente avec un commercial (commission fixe)

1. **Ventes → Nouvelle vente.** Client : *Garage Moderne Bamako*. Ajoute *Pneu Tourisme 205/55R16* × **5** au prix de 34 000 F → total **170 000 F**.
2. Dans le champ **Commercial**, choisis **Diallo Sékou**.
3. Encaisse le paiement complet, valide.
4. Ouvre le PDF de la facture générée → **vérifie qu'elle affiche uniquement "170 000 F", aucune trace de commission ni de prix d'achat.**
5. Va dans **Commissions**, choisis Sékou Diallo, période = aujourd'hui → tu dois voir **5 000 F dus** (5 pneus × 1 000 F).

### Étape 3 — Vente avec un commercial (commission pourcentage)

1. **Ventes → Nouvelle vente.** Client : *Transport Diarra & Frères*. Ajoute *Pneu SUV 215/65R16* × **8** au prix de 45 000 F → total **360 000 F**.
2. Commercial : **Doumbia Awa**.
3. Valide, paiement complet.
4. **Commissions → Doumbia Awa**, période aujourd'hui → tu dois voir **36 000 F dus** (10 % de 360 000 F).

### Étape 4 — Règlement des commissions (et preuve anti-double-paiement)

1. Toujours dans **Commissions**, sélectionne Sékou Diallo, la période, clique **Régler**, confirme (espèces).
   → La ligne disparaît de "à régler", et apparaît dans l'**Historique des règlements**.
2. Refais la même période pour Sékou Diallo : le montant dû doit être **0 F** — preuve que la vente déjà réglée ne peut pas être payée deux fois.
3. Fais pareil pour Awa Doumbia.

### Étape 5 — Absence et avance sur salaire

1. **Personnel → Keita Moussa.** Section Absences → *Nouvelle absence* : 1 jour, aujourd'hui, motif "Maladie", avec retenue.
2. **Personnel → Sidibé Fatoumata.** Section Avances → *Nouvelle avance* : **20 000 F**, motif "Avance demandée".

### Étape 6 — Génération de la paie

1. **Paie → Nouvelle période de paie.** Libellé "Août 2026", du 01/08/2026 au 31/08/2026.
2. Clique **Générer les bulletins** : un bulletin est créé pour chaque employé actif (Moussa, Fatoumata, Sékou, Awa, Boubacar).
3. Ouvre le bulletin de **Moussa Keita** :
   - Salaire de base 100 000 F
   - Retenue absence : 100 000 ÷ 30 × 1 jour = **3 333 F**
   - Salaire net : **96 667 F**
4. Ouvre le bulletin de **Fatoumata Sidibé** :
   - Salaire de base 150 000 F
   - Avance déduite : **20 000 F**
   - Salaire net : **130 000 F**
5. Règle le bulletin de Moussa (espèces, montant complet) → statut passe à "Payé".

**Deuxième argument choc :** *"Avant, qui calculait la retenue si un employé manquait une journée ? Là c'est automatique, et configurable — tu choisis toi-même la règle (26 ou 30 jours par mois) dans les paramètres de paie."*

### Étape 7 — Perte de stock : le coût réel de chaque article ne bouge pas, seule la moyenne globale se réajuste

1. **Stock → Mouvements → Nouveau mouvement.** Article *Pneu Tourisme 205/55R16*, type **Perte**, quantité **5**, motif "Casse manutention".
2. Retourne sur la fiche du chargement "Chargement Bamako Août" :
   - Le **tableau détail par article reste identique** — 28 750 F, 36 750 F, 42 750 F ne changent pas : le coût réel d'un article ne dépend jamais de ce qui lui arrive après, seulement de ce qu'il a coûté à l'achat et en dépenses.
   - Seule la **synthèse globale** (l'indicateur secondaire) se réajuste : quantité disponible 120 − 5 pertes = 115, donc moyenne globale = 4 050 000 ÷ 115 ≈ **35 217 F** (légèrement plus élevée qu'à l'étape 1).
3. Vérifie dans **Stock → Mouvements** que la perte reste visible dans l'historique (jamais supprimée).

**Troisième argument choc :** *"Vous voyez ? Même après une casse, le coût réel de chaque pneu ne bouge pas d'un centime — seule la moyenne globale, qui n'est là que pour donner une vision d'ensemble, se réajuste. Vos décisions de prix, elles, s'appuient toujours sur le vrai chiffre, jamais sur une moyenne qui bouge sous vos pieds."*

### Étape 8 — Tableau de bord

1. Va sur **Tableau de bord**, sélectionne la période "Aujourd'hui" ou "Ce mois".
2. Dans la section **Personnel & Chargements**, vérifie que les cartes affichent :
   - Dépenses (570 000 F de l'étape 1)
   - Salaires payés (96 667 F si tu as réglé Moussa)
   - Commissions réglées (5 000 + 36 000 = 41 000 F)
   - Pertes (5 unités)

---

## 3. Script de pitch pour ton client

Voici comment enchaîner la démo pour raconter une histoire, pas juste cliquer sur des écrans. Garde ce fil rouge : **"Avant, vous ne saviez pas. Maintenant, vous savez — et vous ne pouvez plus vous faire avoir."**

### Accroche d'ouverture
> *"Je vais vous montrer quatre choses que la plupart des logiciels de gestion ne font pas : connaître le vrai prix de revient de CHAQUE pneu — pas une moyenne qui mélange tout —, payer vos commerciaux au centime près sans jamais les payer deux fois, gérer la paie de votre personnel avec les absences et les avances, et tout ça sans jamais perdre le fil même si un pneu se casse en cours de route. Tout ça dans le même outil que vous utilisez déjà pour vos ventes."*

### Bloc 1 — Le vrai coût de chaque pneu, pas une moyenne (Étape 1)
- Crée le chargement en direct, donne-lui un nom ("Chargement Bamako Août" — *"vous l'appelez comme vous voulez, comme un dossier"*).
- Ajoute les 3 pneus à 3 prix différents dans le même achat, puis les 4 dépenses partagées.
- Montre le tableau détail par article : *"Regardez, ces trois pneus ne vous coûtent PAS la même chose, même si les frais de transport et de douane sont partagés entre eux. Le logiciel fait le calcul pneu par pneu, automatiquement."*
- Sors le chiffre choc : *"Avec l'ancienne méthode — un seul chiffre moyen pour tout le chargement — vous auriez cru gagner 20 fois moins sur ce pneu-là, et deux fois plus sur celui-ci. Les deux étaient faux."*
- Montre le bouton **Clôturer** : *"Et une fois que vous avez tout saisi, vous verrouillez le chargement — plus aucune facture en retard ne viendra fausser vos calculs déjà faits."*

### Bloc 2 — Ventes avec commerciaux (Étapes 2-3)
- Fais une vente en direct devant le client, avec un commercial fixe puis un commercial en pourcentage.
- Ouvre le PDF de la facture : *"Voilà ce que voit votre client final — juste le prix de vente. La commission, le prix d'achat, la marge : ça, c'est réservé à vous, dans l'administration."*
- Montre l'écran Commissions : *"Là vous voyez en direct combien vous devez à chaque commercial, sur n'importe quelle période que vous choisissez — pas obligatoirement le mois calendaire, vous pouvez payer toutes les deux semaines si c'est votre habitude."*

### Bloc 3 — Règlement et anti-fraude (Étape 4)
- Règle une commission devant le client, puis retente de la régler une deuxième fois pour montrer que le montant est à zéro.
- Phrase forte : *"Une fois qu'une commission est payée, il est physiquement impossible de la payer une deuxième fois, même par erreur. Ça, ça protège votre trésorerie."*

### Bloc 4 — Personnel et paie (Étapes 5-6)
- Montre la fiche d'un employé, l'ajout d'une absence, puis d'une avance.
- Génère la paie devant lui : *"Un clic, et le logiciel calcule automatiquement la retenue pour l'absence et déduit l'avance déjà versée. Votre comptable n'a plus à faire ce calcul à la main chaque fin de mois."*

### Bloc 5 — Pertes, traçabilité, et coûts qui ne bougent pas (Étape 7)
- Enregistre une perte de stock en direct, retourne sur la fiche chargement.
- Phrase clé : *"Le coût réel de chaque pneu ne bouge jamais après-coup — vous pouvez toujours faire confiance au chiffre que vous avez sous les yeux au moment de fixer votre prix. Et rien ne disparaît jamais silencieusement : une perte, une casse, un ajustement, tout reste dans l'historique avec la date et le nom de la personne qui l'a enregistré."*

### Bloc 6 — Tableau de bord (Étape 8)
- Termine sur le dashboard : *"Et là, en un coup d'œil, vous avez la vision complète : ce que vous avez vendu, ce que vous avez dépensé, ce que vous avez payé en salaires et en commissions, et vos pertes. Cette vue, avant, il fallait la reconstituer à la main, ou vous ne l'aviez tout simplement pas."*

### Clôture
> *"Tout ce que vous avez vu tourne sur votre propre ordinateur, avec vos propres données, sans dépendre d'Internet. Et rien de ce que je vous ai montré aujourd'hui n'a cassé les fonctionnalités que vous utilisiez déjà — vos ventes, vos achats, votre stock fonctionnent exactement comme avant, en mieux."*

---

## 4. Pense-bête rapide (ordre de saisie)

1. Fournisseurs (1.1)
2. Articles (1.2)
3. Clients (1.3)
4. Personnel — employés (1.4) puis commerciaux (1.5) + leur commission
5. Chargement nommé → Achat à 3 lignes/3 prix → Dépenses (par quantité) → tableau détail par article → Clôturer (Étape 1)
6. Ventes avec commercial (Étapes 2-3)
7. Règlement commissions (Étape 4)
8. Absence + avance (Étape 5)
9. Période de paie + génération + règlement (Étape 6)
10. Perte de stock — vérifie que le détail par article ne bouge pas (Étape 7)
11. Dashboard (Étape 8)
