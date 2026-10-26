# CineSphere

Plateforme pour les amateurs de films et de séries TV : catalogue, recherche,
favoris, calendrier des sorties et rappels.

Bonus réalisés : **Firebase (Auth + Firestore) · Search & Filtres · Pagination · Local
Notifications · Walkthroughs** (+ Custom code et tests automatisés).

## Workflow VS Code ↔ FlutterFlow

Le projet est relié à FlutterFlow via l'extension **FlutterFlow: Custom Code
Editor** de VS Code. Seuls ces fichiers remontent vers FlutterFlow (les autres
sont en lecture seule et régénérés par FlutterFlow) :

| Fichier | Contenu |
|---|---|
| `lib/custom_code/widgets/` | widgets personnalisés |
| `lib/custom_code/actions/` | actions personnalisées |
| `lib/flutter_flow/custom_functions.dart` | fonctions personnalisées |
| `pubspec.yaml` | dépendances (`flutter_local_notifications`, `timezone`) |

1. Modifier le code dans VS Code (extension Dart/Flutter installée).
2. Vérifier : `flutter analyze` puis `flutter test`.
3. Panneau FlutterFlow de VS Code → **Push to FlutterFlow**.
4. Dans FlutterFlow web : *Custom Code* → vérifier qu'il n'y a pas d'erreur
   → construire les pages → tester avec **Test Mode / Run Mode**.
5. Avant de recoder dans VS Code : **Pull latest changes**.

## 1. Firebase

Projet Firebase `cinesphere-app-3f710` (forfait gratuit Spark), relié à
FlutterFlow (*Settings → Project Setup → Firebase*). Le backend est passé de
Supabase à Firebase le 26/10/2026 (décision d'équipe) ; le dossier
`supabase/` est conservé comme archive de l'ancien schéma SQL.

- **Authentication** : e-mail / mot de passe.
- **Firestore** (`europe-west3`) : `users` (profil + préférences),
  `usernames` (unicité des pseudos), `media` (films **et** séries, champ
  `mediaType`), `genres`, `platforms`, `news`, `release_events`,
  `favorites`, `watched`, `watchlists`, `watchlist_items`, `reviews`,
  `notifications`, `search_history`. Champs en camelCase ; les documents
  personnels portent `userId`.
- **Règles et index** : dans [firebase/](firebase/) (`firestore.rules`,
  `firestore.indexes.json`), déployés avec la CLI :

```bash
cd firebase
firebase deploy --only firestore
```

Ne pas utiliser le bouton *Deploy* des règles dans FlutterFlow : il
remplacerait ces règles par des règles ouvertes. Pour la même raison,
FlutterFlow affiche « Firestore rules not deployed » et « indexes not
properly deployed » : c'est attendu.

## 2. Custom code fourni

### Widgets

| Widget | Paramètres | Rôle |
|---|---|---|
| `CatalogBrowser` | `pageSize`, `initialMediaType`, `onItemTap(mediaId)` | Recherche (titre + synopsis, délai 400 ms), filtres (type, genre, note min., statut), tri, pagination avec scroll infini (catalogue Firestore gardé en mémoire : Firestore n'a pas de recherche « contient »), états chargement / vide / erreur, pull-to-refresh |
| `MediaCard` | `title`, `posterUrl`, `mediaType`, `rating`, `releaseDate`, `onTap` | Carte affiche + badges |
| `FavoriteButton` | `mediaId`, `iconSize`, `onChanged(isFavorite)` | Cœur relié à la collection `favorites` |
| `UpcomingReleasesList` | `mediaId`, `pageSize`, `reminderMinutesBefore`, `onItemTap(selectedMediaId)` | Calendrier groupé par jour, paginé, cloche = notification programmée |
| `OnboardingWalkthrough` | `onFinish()` | 4 étapes de présentation + choix des genres préférés |
| `HomeFeed` | `onItemTap(tappedMediaId)` | Accueil : « Pour vous » (genres préférés), Tendances, Bientôt disponible, Les mieux notés |
| `MediaDetailView` | `mediaId` | Page détail complète : couverture, infos, genres, plateformes, synopsis, favori, bande-annonce, prochaines diffusions |
| `FavoritesGrid` | `pageSize`, `onItemTap(tappedMediaId)` | Favoris de l'utilisateur, paginés |
| `NewsFeed` | `pageSize`, `onItemTap(linkedMediaId)` | Actualités paginées |
| `SettingsPanel` | `onReplayOnboarding()`, `onSignOut()` | Notifications (activer, tester, rappels), genres, revoir le walkthrough, déconnexion |

### Actions

`initLocalNotifications`, `scheduleReleaseNotification`,
`cancelReleaseNotification`, `getScheduledReminders`,
`showInstantNotification`, `toggleFavorite`, `hasCompletedOnboarding`,
`completeOnboarding`.

### Fonctions

`formatRuntime`, `formatReleaseDate`, `daysUntil`, `isReleaseSoon`,
`releaseCountdownLabel`, `mediaTypeLabel`, `statusLabel`, `seasonsLabel`,
`ratingLabel`, `ratingColor`, `notificationIdFromString`.

## 3. Pages à construire dans FlutterFlow

Chaque page contient **un seul custom widget** réglé en *Expanded* dans la
Column de la page.

| Page | Widget | Réglages |
|---|---|---|
| **Login** | modèle *Auth 1* | App Settings → Authentication : Entry Page = Login, Logged In Page = HomePage |
| **Onboarding** | `OnboardingWalkthrough` | sans App Bar ; `onFinish` → *Navigate To* HomePage (*Replace Route*) |
| **HomePage** | `HomeFeed` | `onItemTap` → *Navigate To* MediaDetail (`mediaId` = `tappedMediaId`). *On Page Load* : `hasCompletedOnboarding` → si `false` → *Navigate To* Onboarding |
| **Catalogue** | `CatalogBrowser` | `onItemTap` → *Navigate To* MediaDetail (`mediaId`) |
| **MediaDetail** (paramètre `mediaId`, String) | `MediaDetailView` | sans App Bar, sans Nav Bar ; `mediaId` = paramètre de page |
| **Calendrier** | `UpcomingReleasesList` | `onItemTap` → MediaDetail (`selectedMediaId`) |
| **Favoris** | `FavoritesGrid` | `onItemTap` → MediaDetail (`tappedMediaId`) |
| **Actualites** | `NewsFeed` | `onItemTap` → MediaDetail (`linkedMediaId`) |
| **Parametres** | `SettingsPanel` | `onReplayOnboarding` → Onboarding ; `onSignOut` → *Log Out* puis Login |

Navigation principale : **Nav Bar** FlutterFlow (*App Settings → Nav Bar &
App Bar*) avec HomePage, Catalogue, Calendrier, Favoris, Parametres. Dans
chacune de ces pages : *Page Properties* → **Show on Nav Bar**.

## 4. Walkthrough FlutterFlow (Custom components + Walkthroughs)

Le bonus utilise les deux mécanismes :

1. **Premier lancement** : la page Onboarding (`OnboardingWalkthrough`).
2. **Visite guidée de la HomePage** :
   - créer des *Components* FlutterFlow (ex. `WalkthroughStep` avec les
     paramètres `title`, `text`) ;
   - HomePage → onglet **Walkthroughs** → *Add Walkthrough* → une étape par
     zone à présenter (barre de recherche, section tendances, onglet calendrier,
     onglet favoris), chacune utilisant le component `WalkthroughStep` ;
   - dans `onFinish` de `OnboardingWalkthrough`, naviguer vers la HomePage en
     passant un paramètre `showTour = true`, et sur *On Page Load* de la
     HomePage : si `showTour` → action **Start Walkthrough**.

## 5. Notifications locales

- **Android / iOS** : notifications programmées (`zonedSchedule`, mode
  inexact → pas besoin de la permission « alarmes exactes »).
- **Web (Test Mode FlutterFlow)** : le navigateur ne sait pas programmer de
  notification. `showInstantNotification` fonctionne. Un rappel programmé
  s'affiche à l'heure prévue tant que l'onglet reste ouvert. Le navigateur
  demande la permission au premier appel.
- Android : FlutterFlow → *Settings → Permissions* → activer **Notifications**.
  Pour que les rappels programmés survivent à un redémarrage du téléphone,
  ajouter dans *Custom Code → Configuration Files → AndroidManifest.xml*,
  dans `<application>` :

```xml
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
    </intent-filter>
</receiver>
```

## 6. Tests automatisés

```bash
flutter test
```

- `test/custom_functions_test.dart` : formatage, compte à rebours, notes, ids
  de notification.
- `test/widgets_test.dart` : `MediaCard` (affichage, compte à rebours, tap),
  `OnboardingWalkthrough` (navigation entre étapes, « Passer », sélection de
  genres).

## Répartition proposée

| Membre | Responsabilités |
|---|---|
| 1 — Firebase & compte | Firestore, règles de sécurité, auth, profil et avatar, favoris, listes, vus (voir ci-dessous) |
| 2 — Catalogue | `CatalogBrowser`, `MediaCard`, HomePage, MediaDetail, pagination |
| 3 — UX & notifications | Onboarding + Walkthrough FlutterFlow, calendrier, notifications locales, tests |

## Membre 1 — Authentification, profil et Firebase

Pages dans le dossier FlutterFlow `membre1_auth_profil_supabase` (nom
d'origine conservé). Ce sont des pages FlutterFlow **natives** (widgets
FlutterFlow, requêtes Firestore, thème CinéSphère) qui appellent des actions
personnalisées, une par fichier.

### Base Firebase

Collections, règles de sécurité et index : voir la section 1 et
[firebase/](firebase/). Les règles reprennent les anciennes politiques RLS :
catalogue en lecture publique, chaque membre ne lit et ne modifie que ses
favoris, vus, listes et notifications, le rôle d'un profil ne se change pas
depuis l'application.

### Pages

| Page | Paramètre | Contenu | Actions |
|---|---|---|---|
| `login` (Entry Page) | — | connexion, liens vers Inscription et MotDePasseOublie | `authSignIn`, `syncTmdbCatalog` |
| `Inscription` | — | e-mail, pseudo (unicité vérifiée pendant la saisie), mot de passe + confirmation | `authSignUp`, `syncTmdbCatalog` |
| `ConfirmationEmail` | `email` | « J'ai confirmé mon adresse » après le clic sur le lien reçu par e-mail, renvoi du lien | `authConfirmSignUp`, `authResendCode`, `syncTmdbCatalog` |
| `MotDePasseOublie` | — | envoi du lien Firebase de réinitialisation | `authSendResetCode` |
| `NouveauMotDePasse` | `email` | changement du mot de passe du membre connecté (depuis Paramètres) | `authResetPassword` |
| `Profil` | — | photo de profil (`AvatarPicker`), pseudo et bio modifiables, nombre d'avis publiés | `updateMyProfile` |
| `Parametres` | — | profil, favoris, changer de mot de passe, notifications, revoir l'onboarding, **actualiser le catalogue TMDB**, **supprimer mon compte** (avec confirmation), déconnexion | `initLocalNotifications`, `showInstantNotification`, `syncTmdbCatalog`, `deleteMyAccount`, *Log Out* |
| `Favoris` | — | 3 onglets : **Favoris**, **Mes listes** (création), **Vus** | `createWatchlist` |
| `DetailListe` | `watchlistId` | titres d'une liste, renommer, retirer un titre, supprimer la liste (avec confirmation) | `renameWatchlist`, `removeWatchlistItem`, `deleteWatchlist` |
| `BandeAnnonce` | `trailerUrl` | widget natif *YouTube Player* de FlutterFlow (lecture automatique, plein écran) ; sa présence fait gérer le paquet du lecteur par FlutterFlow | — |

Sur la fiche d'un titre (`MediaDetailView`, membre 2), avec son accord, le
membre 1 a ajouté ces widgets :

| Widget | Paramètres | Rôle |
|---|---|---|
| `AddToWatchlistButton` | `mediaId` | feuille avec les listes du membre ; ajout à une liste existante ou création d'une liste avec le titre |
| `MarkWatchedButton` | `mediaId`, `onChanged(isWatched)` | « Marquer comme vu » relié à la collection `watched` (onglet Vus) |
| `TrailerPlayer` | `trailerUrl`, `autoPlay` | lecteur YouTube intégré, basé sur le lecteur natif de FlutterFlow (`FlutterFlowYoutubePlayer`) : le bouton « Bande-annonce » ouvre la vidéo dans une fenêtre de l'application (`showTrailerDialog`) au lieu de YouTube |
| `AvatarPicker` | `avatarUrl`, `onChanged(avatarUrl)` | photo choisie dans la galerie, réduite à 256 px, enregistrée en base64 dans `users/{uid}.avatarData` (Storage demande le forfait payant Blaze) ; accepte aussi une URL http |

Les actions qui modifient des données retournent `""` en cas de succès, sinon
le message d'erreur en français à afficher (*SnackBar*). `toggleFavorite` et
`toggleWatched` retournent le nouvel état.

**Suppression de compte** : `deleteMyAccount` vérifie que la connexion date
de moins de 5 minutes (exigence de Firebase), efface les documents du membre
(profil, pseudo, favoris, vus, listes, notifications, historique) puis le
compte Firebase Auth. La page enchaîne avec *Log Out*.

### API TMDB

**API Manager FlutterFlow** → groupe **TMDB** (base
`https://api.themoviedb.org/3`). La clé vient de la valeur d'environnement
`tmdbApiKey` (*Settings → Dev Environments*), la langue est `fr-FR` par défaut.

| Appel | Point d'accès | Chemins JSON |
|---|---|---|
| `Tendances` | `/trending/all/week` | `resultats`, `ids`, `titres`, `affiches`, `notes`, `totalPages` |
| `Recherche` (`query`) | `/search/multi` | idem |
| `FilmsPopulaires` | `/movie/popular` (région FR) | idem |
| `SeriesPopulaires` | `/tv/popular` | idem |
| `ProchainesSorties` | `/movie/upcoming` (région FR) | idem |
| `SeriesEnCours` | `/tv/on_the_air` | idem |
| `DetailFilm` (`movieId`) | `/movie/{id}` + vidéos (fr, en) et plateformes | `titre`, `synopsis`, `affiche`, `fond`, `dateSortie`, `duree`, `note`, `genres`, `videos` |
| `DetailSerie` (`seriesId`) | `/tv/{id}` + vidéos (fr, en) et plateformes | `titre`, `synopsis`, `affiche`, `fond`, `premiereDiffusion`, `saisons`, `episodes`, `statut`, `note`, `genres`, `prochainEpisode`, `videos` |
| `GenresFilms` | `/genre/movie/list` | `genres`, `noms` |

Chaque appel peut être utilisé dans une page (*Backend Query → API Call*) ou une
action (*API Call*). Code généré : `lib/backend/api_requests/api_calls.dart`.

**Import dans le catalogue** : l'action `syncTmdbCatalog(force)` appelle
`Tendances` (2 pages), `FilmsPopulaires`, `SeriesPopulaires`,
`ProchainesSorties` et `SeriesEnCours`, puis enregistre les titres (sans doublon)
dans Firestore, ce que faisait l'ancienne fonction SQL `import_tmdb_media` :
création ou mise à jour des documents de `media` (clé `mediaType` + `tmdbId`) : les widgets du catalogue affichent
les vrais titres TMDB et favoris, listes et vus continuent de fonctionner.
Un film à venir reçoit aussi un événement « Sortie au cinéma » dans
`release_events` (calendrier).

Les listes TMDB ne donnent ni durée, ni saisons, ni bande-annonce, ni
plateformes : à chaque passage, l'action appelle ensuite `DetailFilm` ou
`DetailSerie` pour les 60 titres à reprendre les plus populaires (8 appels en
parallèle) et complète les documents (ancienne fonction SQL `enrich_tmdb_media`) : durée, saisons,
épisodes, série terminée, bande-annonce YouTube (française d'abord) et
plateformes d'abonnement en France. La fiche d'un titre (`MediaDetailView`)
les affiche. Un titre est repris s'il n'a jamais été complété
(`media.detailsSyncedAt` vide) ou s'il n'a toujours pas de bande-annonce
7 jours après le dernier passage.

- après connexion, inscription ou confirmation : `force = false`, en
  arrière-plan, au plus une fois toutes les 12 h ;
- Paramètres → **Actualiser le catalogue** : `force = true`, message de
  réussite ou d'erreur.

### Authentification

La logique est dans `lib/custom_code/actions/auth_service.dart` ; les actions
`auth*` ne font que l'appeler :

- validation : e-mail, mot de passe ≥ 8 caractères, confirmation, pseudo
  (3 à 24 caractères) dont l'unicité est vérifiée avant l'inscription
  (collection `usernames`, lisible sans compte) ;
- l'inscription crée le compte Firebase, puis `users/{uid}` et
  `usernames/{pseudo}` dans un même lot (le compte est supprimé si le pseudo
  vient d'être pris) ;
- erreurs Firebase Auth traduites en français (`CineFailure`) ;
- **liens par e-mail** : Firebase envoie un lien de confirmation à
  l'inscription et un lien de réinitialisation du mot de passe (page
  hébergée par Firebase) ;
- un e-mail non confirmé à la connexion ouvre ConfirmationEmail (le membre
  reste connecté pour pouvoir renvoyer le lien) ;
- session persistante gérée par `firebase_auth`.

Les comptes et données de Supabase ont été importés dans Firebase (mêmes
identifiants, mots de passe repris grâce à l'import bcrypt de Firebase Auth).

### Données

`lib/custom_code/actions/firestore_service.dart` (`FirestoreService`)
regroupe l'accès aux données : profil, pseudo, avatar, préférences,
favoris, vus, listes (créer, renommer, supprimer, ajouter / retirer un
titre), genres, plateformes et catalogue. `cineRow` convertit un document
Firestore en ligne `snake_case` lue par les modèles de `cine_models.dart` et
par les widgets.

### Tests

| Fichier | Contenu |
|---|---|
| `test/auth_service_test.dart` | validation, traduction des erreurs Firebase, `AuthService` avec une passerelle simulée |
| `test/auth_actions_test.dart` | actions `auth*` et `deleteMyAccount` |
| `test/firestore_service_test.dart` | validateurs, conversion des documents (`cineRow`, `toFirestoreFields`), erreurs Firestore |
| `test/cine_models_test.dart` | modèles (`fromJson`, `toJson`, SQLite, égalité) |
| `test/avatar_picker_test.dart` | `AvatarPicker` (galerie simulée, `FirestoreService` en mémoire) |
| `test/mark_watched_button_test.dart` | `MarkWatchedButton` |
| `test/trailer_player_test.dart` | adresses YouTube, `TrailerPlayer` sans vidéo valide |
| `test/sync_tmdb_catalog_test.dart` | conversion des résultats TMDB, fusion sans doublon, envoi par lots, TMDB injoignable, détails (bande-annonce, plateformes, séries terminées) |
