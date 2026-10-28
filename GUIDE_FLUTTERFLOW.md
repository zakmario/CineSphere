# Guide pas à pas — CineSphere dans FlutterFlow

Tout le code (widgets, actions, fonctions, base de données) est déjà écrit.
Ce guide contient uniquement les clics à faire, car ils ne peuvent pas être
faits depuis VS Code. Comptez environ 45 minutes. Les noms des menus sont en
anglais, comme dans FlutterFlow.

> Règle générale pour chaque page : **un seul custom widget**, placé dans la
> Column de la page, avec **Expanded** coché.

---

## Étape 0 — Envoyer le code (VS Code, 1 min)

1. Dans VS Code, cliquez sur l'icône **FlutterFlow** dans la barre de gauche.
2. Cliquez sur **Push to FlutterFlow** et attendez le message de succès.
3. Dans FlutterFlow, ouvrez **Custom Code** (icône `</>` dans la barre de
   gauche). Vous devez voir **10 widgets**, **8 actions** et **11 fonctions**.

## Étape 1 — Base de données Supabase (2 min)

1. Ouvrez https://supabase.com/dashboard, puis votre projet CineSphere.
2. Menu de gauche → **SQL Editor** → **New query**.
3. Dans VS Code, ouvrez `supabase/schema.sql`, faites `Ctrl+A` puis `Ctrl+C`,
   et collez le tout dans Supabase.
4. Cliquez sur **Run**. Le résultat attendu est `Success. No rows returned`.
5. Vérification : menu **Table Editor** → la table `media` contient 34 lignes.
6. Dans Supabase, menu **Authentication → Sign In / Providers → Email** :
   pour les tests, **désactivez « Confirm email »**. Sinon, chaque compte
   de test devra confirmer son e-mail avant de pouvoir se connecter.
7. Dans FlutterFlow : **Settings** (roue dentée) → **Supabase** →
   **Get Schema**.

## Étape 2 — Page MediaDetail (à faire en premier, 4 min)

Les autres pages ouvrent celle-ci, elle doit donc exister avant elles.

1. Barre de gauche → **Page Selector** → **+** → **Create Page** → **Blank**,
   nom : `MediaDetail` → **Create Blank Page**.
2. Sélectionnez la page dans l'arbre (*Widget Tree*). Dans le panneau de
   droite, section **Page Parameters** → **+ Add Parameter** :
   nom `mediaId`, type **String** → **Confirm**.
3. Dans le *Widget Tree*, sélectionnez **AppBar** → touche `Suppr`. Le
   widget a son propre bouton retour.
4. Barre de gauche → **Widget Palette** → en bas, section
   **Custom Code Widgets** → glissez **MediaDetailView** dans la Column.
5. Dans le panneau de droite du widget :
   - cochez **Expanded** ;
   - pour le paramètre **mediaId**, cliquez sur l'icône de variable (le petit
     engrenage orange), puis **Page Parameters** → `mediaId` → **Confirm**.

## Étape 3 — Page Onboarding (3 min)

1. **+** → **Blank**, nom : `Onboarding`. Supprimez l'**AppBar**.
2. Glissez **OnboardingWalkthrough** dans la Column, puis cochez
   **Expanded**.
3. Panneau de droite → paramètre **onFinish** → **Open** (éditeur
   d'actions) → **+ Add Action** → **Navigate To** → `HomePage`. Dans
   *Navigate To*, activez **Replace Route**.

## Étape 4 — HomePage (3 min)

1. Ouvrez **HomePage**. Sélectionnez le texte « Page Title » de l'AppBar
   et remplacez-le par `CineSphere`.
2. Glissez **HomeFeed** dans la Column, puis cochez **Expanded**.
3. Paramètre **onItemTap** → **Navigate To** → `MediaDetail` →
   **Pass Parameters** → `mediaId` → valeur : **Action Parameters** →
   `tappedMediaId`.
4. Paramètre **onOnboardingRequired** → **Navigate To** → `Onboarding`,
   avec **Replace Route** activé.

## Étape 5 — Page Login (3 min)

1. **+** → onglet **Templates** → catégorie **Authentication** → choisissez
   **Auth 1** (ou un autre modèle connexion + inscription), nom : `Login`.
2. **Settings** → **App Settings → Authentication** :
   - **Entry Page** : `Login` ;
   - **Logged In Page** : `HomePage`.
3. L'avertissement « Entry Page and Logged In Page should be different »
   doit disparaître.

## Étape 6 — Pages Catalogue, Calendrier, Favoris, Actualites (8 min)

Pour **chacune** de ces pages :

1. **+** → **Blank**, avec le nom indiqué ci-dessous.
2. Renommez le titre de l'AppBar.
3. Glissez le widget indiqué, puis cochez **Expanded**.
4. Reliez **onItemTap** → **Navigate To** → `MediaDetail` → `mediaId` =
   **Action Parameters** → la valeur indiquée.

| Nom de page | Widget | Valeur pour `mediaId` |
|---|---|---|
| `Catalogue` | CatalogBrowser | `mediaId` |
| `Calendrier` | UpcomingReleasesList | `selectedMediaId` |
| `Favoris` | FavoritesGrid | `tappedMediaId` |
| `Actualites` | NewsFeed | `linkedMediaId` |

Pour **CatalogBrowser**, mettez aussi **pageSize** à `10`. Le chargement
de la page suivante sera ainsi bien visible en test.

## Étape 7 — Page Parametres (3 min)

La page `Parametres` est construite par le membre 1 (page native ; l'ancien
widget `SettingsPanel` a été supprimé).

1. Glissez **NotificationSettingsPanel** dans la page (réglages des
   notifications).
2. « Revoir la présentation » → action **resetOnboarding**, puis
   **Navigate To** → `Onboarding`.
3. « Se déconnecter » → **signOutCleanup**, puis **Log Out** (catégorie
   *Authentication*), puis **Navigate To** → `Login`.

## Étape 8 — Barre de navigation (3 min)

1. **Settings** → **App Settings → Nav Bar & App Bar** → activez
   **Show Nav Bar**.
2. Ouvrez chacune de ces pages : **HomePage, Catalogue, Calendrier,
   Favoris, Parametres**. Sélectionnez la page dans le *Widget Tree* →
   panneau de droite → **Nav Bar Item** :
   - cochez **Show on Nav Bar** ;
   - choisissez une icône et un libellé : Accueil 🏠, Catalogue 🔍,
     Calendrier 📅, Favoris ❤️, Paramètres ⚙️.
3. **MediaDetail**, **Onboarding** et **Login** ne doivent **pas** être
   cochées.

## Étape 9 — Walkthrough FlutterFlow (bonus « Custom components + Walkthroughs », 8 min)

1. **Créer le composant** : **+** → **New Component** → nom
   `WalkthroughStep`.
   - Ajoutez 2 paramètres de composant (*Component Parameters*) :
     `title` (String) et `text` (String).
   - Dans le composant : un **Container** (fond `Primary`, coins arrondis
     12, padding 16) contenant une **Column** avec 2 **Text** reliés à
     `title` (gras, blanc) et `text` (blanc).
2. **Créer le walkthrough** : ouvrez **HomePage** → onglet
   **Walkthroughs** (à côté de *Widget Tree*) → **+ Add Walkthrough** → nom
   `homeTour`.
3. Ajoutez 3 étapes (**+ Add Step**). Pour chacune : *Target* = le widget à
   mettre en avant, *Content* = **Component** → `WalkthroughStep`, avec
   les textes suivants :
   - cible **HomeFeed** : « Découvrir » / « Les tendances et les sorties à
     venir, choisies pour vous. » ;
   - cible **AppBar** : « CineSphere » / « Votre plateforme films et
     séries. » ;
   - cible **Nav Bar** (si elle est proposée, sinon le HomeFeed à
     nouveau) : « Navigation » / « Catalogue, calendrier et favoris sont
     ici. ».
4. **Déclencher le tour** : ajoutez à HomePage un paramètre de page
   `showTour` (Boolean). Puis :
   - **Actions** de la page → **On Page Load** → **+ Add Conditional** →
     condition `showTour` est `true` → **Start Walkthrough** → `homeTour` ;
   - revenez sur **Onboarding** → l'action *Navigate To HomePage* de
     `onFinish` → **Pass Parameters** → `showTour` = `true`.

## Étape 10 — Lancer le test

1. En haut à droite, ouvrez l'éclair ⚡ → **Test Mode**. La première
   compilation prend 1 à 3 minutes.
2. Le navigateur demandera la permission pour les **notifications** :
   cliquez sur **Autoriser**. Si la fenêtre n'apparaît pas, cliquez sur
   l'icône 🔒 à gauche de l'adresse → **Notifications : Autoriser**.

---

# Checklist de test (votre partie)

Cochez chaque point et notez ce qui ne marche pas, avec une capture.

**Authentification**
- [ ] Inscription avec un nouvel e-mail → arrivée sur l'Onboarding.
- [ ] Déconnexion (Paramètres → Se déconnecter) → retour au Login.
- [ ] Reconnexion → arrivée directe sur l'Accueil (pas d'Onboarding).

**Walkthrough**
- [ ] Les 4 écrans défilent avec « Suivant », et « Passer » saute à la fin.
- [ ] Le choix des genres fonctionne, et « Commencer » mène à l'Accueil.
- [ ] Le tour guidé `homeTour` démarre sur l'Accueil.
- [ ] La section « Pour vous » de l'Accueil reflète les genres choisis.
- [ ] Paramètres → « Revoir la présentation » relance l'Onboarding.

**Search & Filtres**
- [ ] Taper « dark » dans Catalogue → la série *Dark* apparaît après moins
  d'une seconde.
- [ ] Chercher « rêves » trouve *Inception* (la recherche porte aussi sur
  le synopsis).
- [ ] Les puces Tous / Film / Série filtrent correctement.
- [ ] Filtres → genre *Animation* + note minimale 8 → résultats cohérents,
  et le badge affiche « 2 ».
- [ ] Le tri (note, alphabétique, plus récents) change l'ordre.
- [ ] Une recherche sans résultat affiche un message, et « Effacer les
  filtres » remet tout à zéro.

**Pagination**
- [ ] Catalogue (pageSize 10) : en défilant, un indicateur de chargement
  apparaît, puis les éléments suivants.
- [ ] En fin de liste, le message « N résultats — vous avez tout vu ! »
  s'affiche.
- [ ] Le Calendrier et les Actualités chargent aussi au défilement.

**Supabase / Favoris**
- [ ] Le cœur sur une fiche ajoute le contenu, qui apparaît dans Favoris.
- [ ] Retirer le favori → il disparaît de Favoris après le retour.
- [ ] Un deuxième compte ne voit pas les favoris du premier (RLS).

**Notifications**
- [ ] Paramètres → activer « Rappels de sorties » → le navigateur demande la
  permission.
- [ ] « Tester une notification » → une notification apparaît.
- [ ] Calendrier → cloche sur une sortie → message « Rappel programmé… »,
  et la cloche devient pleine.
- [ ] Paramètres → le nombre de rappels programmés est correct, et « Tout
  supprimer » le remet à 0.
- [ ] Limite connue sur le web : un rappel programmé ne s'affiche que si
  l'onglet est resté ouvert jusqu'à l'heure prévue.
