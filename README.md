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
FlutterFlow (*Settings → Project Setup → Firebase*), conforme à la section 5
du cahier des charges. Le backend est passé de Supabase à Firebase le
26/10/2026 (décision d'équipe) ; le dossier `supabase/` est conservé comme
archive de l'ancien schéma SQL.

L'intégration **Supabase reste reliée** dans FlutterFlow (*Settings →
Integrations → Supabase*, projet `absnwvzofvjrbexeskif`) : l'application
initialise les deux (`initFirebase()` puis `SupaFlow.initialize()` dans
`main.dart`) et le code Supabase généré est disponible dans
`lib/backend/supabase/`. L'authentification et toutes les données de
l'application passent par Firebase ; les tables Supabase contiennent
l'état au 26/10/2026 et ne sont plus synchronisées.

- **Authentication** : e-mail / mot de passe, lien de réinitialisation.
- **Firestore** (`europe-west3`, persistance hors ligne activée) :

```text
users/{uid}                    profil + preferences (map)
  favorites/{movie_550}        titre, affiche, note dénormalisés
  watchlists/{id}              name, isPublic, itemCount
    items/{movie_550}
  watched/{movie_550}
  notifications/{id}
  searchHistory/{id}
  history/{movie_550}          titres consultés (onglet Historique), 50 au plus
usernames/{pseudo}             uid (unicité du pseudo)
movies/{tmdbId}  series/{tmdbId}   cache TMDB, genreIds
genres/{tmdbGenreId}  platforms/{tmdbProviderId}
releaseEvents/{id}             calendrier (titre et affiche dénormalisés)
reviews/{id}                   + likes/{uid}, likesCount
news/{id}                      actualités (page Actualites, membre 2)
```

- **Logique côté client** (pas de Cloud Functions, forfait Spark) dans
  `firebase_service.dart` : inscription en transaction (pseudo libre puis
  `usernames` + `users`), `itemCount` et `likesCount` mis à jour dans le même
  lot que l'élément, pseudo/avatar recopiés dans les avis, suppression
  complète du compte (`requires-recent-login` géré).
- **Règles, index, tests** : dans [firebase/](firebase/).

```bash
cd firebase
npm install
npm run test:rules      # 22 tests des règles sur l'émulateur (Java 21 requis)
npm run seed:emulator   # tool/seed_firestore.dart sur l'émulateur
npm run deploy          # règles + index sur le vrai projet
```

`tool/seed_firestore.dart` remplit les genres TMDB et les plateformes ; avec
`--release-events`, il ajoute au calendrier la sortie des films à venir
(écriture réservée aux admins par les règles). Variables : voir
`.env.example`.

Ne pas utiliser le bouton *Deploy* des règles dans FlutterFlow : il
remplacerait ces règles par des règles ouvertes. Pour la même raison,
FlutterFlow affiche « Firestore rules not deployed » et « indexes not
properly deployed » : c'est attendu.

**Écarts assumés avec le cahier des charges**

| Prévu | Réalisé | Raison |
|---|---|---|
| Avatar dans Firebase Storage | base64 dans `users/{uid}.avatarData` | Storage exige le forfait payant Blaze pour un nouveau projet |
| Tests avec `fake_cloud_firestore` / `firebase_auth_mocks` | émulateur (règles) + `mocktail` (Dart) | ces paquets exigent `equatable` ≥ 2.1.0, FlutterFlow impose 2.0.7 |
| `flutterfire configure` / `firebase_options.dart` | configuration générée par FlutterFlow (`lib/backend/firebase/`) | export FlutterFlow (prévu au 5.1) |
| — | `uid`, `created_time`, `display_name`, `photo_url`, `phone_number` dans `users` | champs exigés par FlutterFlow pour la collection des comptes (les trois derniers restent vides) |
| — | `posterUrl` dans `watched`, `popularity` dans `movies` / `series`, collection `news` | affichage de l'onglet Vus, tri « Tendances », page Actualites |
| — | sous-collection `users/{uid}/history` | onglet Historique (6.7) : la section 5 ne prévoit pas où ranger les titres consultés |
| `reviews/{id}/likes/{uid}` supprimé par son auteur seulement | l'auteur de l'avis peut aussi effacer les likes des autres | sinon la suppression d'un avis liké (ou du compte) échoue |
| SQLite (cache TMDB, `pending_sync`, `SyncService`) | fait : `CineLocalDb` (cache du catalogue Firestore, lui-même rempli depuis TMDB, et `pending_sync`) et `CineSyncService` | l'app lit le catalogue dans Firestore, pas directement dans TMDB ; voir la section Membre 3 |

## 2. Custom code fourni

Liste complète (signatures, paramètres, ajout dans l'éditeur) :
[docs/flutterflow_custom_code.md](docs/flutterflow_custom_code.md).

### Widgets

| Widget | Paramètres | Rôle |
|---|---|---|
| `CatalogBrowser` | `pageSize`, `initialMediaType`, `onItemTap(mediaId)` | Recherche (titre + synopsis, délai 400 ms), filtres (type, genre, note min., statut), tri, pagination avec scroll infini (catalogue Firestore gardé en mémoire : Firestore n'a pas de recherche « contient »), états chargement / vide / erreur, pull-to-refresh |
| `MediaCard` | `title`, `posterUrl`, `mediaType`, `rating`, `releaseDate`, `onTap` | Carte affiche + badges |
| `FavoriteButton` | `mediaId`, `iconSize`, `onChanged(isFavorite)` | Cœur relié à `users/{uid}/favorites` |
| `UpcomingReleasesList` | `mediaId`, `pageSize`, `reminderMinutesBefore`, `onItemTap(selectedMediaId)` | Calendrier groupé par jour, paginé, cloche = notification programmée |
| `OnboardingWalkthrough` | `onFinish()` | 4 étapes de présentation + choix des genres préférés |
| `HomeFeed` | `onItemTap(tappedMediaId)` | Accueil : « Pour vous » (genres préférés), Tendances, Bientôt disponible, Les mieux notés |
| `MediaDetailView` | `mediaId` | Page détail complète : couverture, infos, genres, plateformes, synopsis, favori, bande-annonce, prochaines diffusions |
| `FavoritesGrid` | `pageSize`, `onItemTap(tappedMediaId)` | Favoris de l'utilisateur, paginés |
| `NewsFeed` | `pageSize`, `onItemTap(linkedMediaId)` | Actualités paginées |

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
| **Parametres** | page native (membre 1) + `NotificationSettingsPanel` | voir les sections Membre 1 et Membre 3 |

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
personnalisées, une par fichier. Leurs couleurs sont celles du thème
FlutterFlow (*Primary Background*, *Primary*…) : elles suivent le mode clair
ou sombre choisi dans Paramètres.

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
| `Profil` | — | photo de profil (`AvatarPicker`), pseudo et bio modifiables, nombre de favoris, listes et avis, **statistiques** (`ProfileStats`) | `updateMyProfile` |
| `Parametres` | — | profil, favoris, changer de mot de passe, notifications, **préférences** (`PreferencesPanel`), revoir l'onboarding, **actualiser le catalogue TMDB**, **supprimer mon compte** (avec confirmation), déconnexion | `initLocalNotifications`, `showInstantNotification`, `syncTmdbCatalog`, `deleteMyAccount`, *Log Out* |
| `Favoris` | `onglet` (0 à 3) | 4 onglets : **Favoris**, **Mes listes** (création), **Vus**, **Historique** (50 dernières fiches ouvertes, « Effacer l'historique ») | `createWatchlist`, `clearViewHistory` |
| `DetailListe` | `watchlist` (référence) | titres d'une liste, renommer, retirer un titre, supprimer la liste (avec confirmation) | `renameWatchlist`, `removeWatchlistItem`, `deleteWatchlist` |
| `BandeAnnonce` | `trailerUrl` | widget natif *YouTube Player* de FlutterFlow (lecture automatique, plein écran) ; sa présence fait gérer le paquet du lecteur par FlutterFlow | — |

Sur la fiche d'un titre (`MediaDetailView`, membre 2), avec son accord, le
membre 1 a ajouté ces widgets :

| Widget | Paramètres | Rôle |
|---|---|---|
| `AddToWatchlistButton` | `mediaId` | feuille avec les listes du membre ; ajout à une liste existante ou création d'une liste avec le titre |
| `MarkWatchedButton` | `mediaId`, `onChanged(isWatched)` | « Marquer comme vu » relié à `users/{uid}/watched` (onglet Vus) |
| `TrailerPlayer` | `trailerUrl`, `autoPlay` | lecteur YouTube intégré, basé sur le lecteur natif de FlutterFlow (`FlutterFlowYoutubePlayer`) : le bouton « Bande-annonce » ouvre la vidéo dans une fenêtre de l'application (`showTrailerDialog`) au lieu de YouTube |
| `AvatarPicker` | `avatarUrl`, `onChanged(avatarUrl)` | photo choisie dans la galerie, réduite à 256 px, enregistrée en base64 dans `users/{uid}.avatarData` (Storage demande le forfait payant Blaze) ; accepte aussi une URL http |
| `PreferencesPanel` | — | page Paramètres : thème **Sombre / Clair / Système** (appliqué tout de suite par FlutterFlow), types de contenus, genres et plateformes préférés (`users/{uid}.preferences`, genres recopiés pour « Pour vous »), **Vider le cache** (affiches, catalogue en mémoire et cache SQLite du membre 3 via `clearLocalCache`) |
| `ProfileStats` | — | page Profil : films vus, séries suivies (en favoris), heures de visionnage (durée des films + épisodes des séries vues × 45 min, TMDB ne donnant pas la durée d'un épisode), genre préféré (le plus fréquent parmi les titres vus et favoris) ; recalculé quand un favori ou un « vu » change |
| `ReviewsSection` | `mediaId` | section **Avis** en bas de la fiche : note moyenne des avis publics, son avis (donner, modifier, supprimer, option privé), avis des autres membres paginés par 20, likes |

La fiche note aussi chaque ouverture dans l'historique (`recordView`, onglet
Historique de Favoris).

**Mises à jour optimistes** (6.7) : le cœur (`FavoriteButton`), « Marquer comme
vu » et les likes changent dès le toucher, puis reviennent en arrière avec un
message si Firestore refuse. Hors connexion, Firestore garde l'écriture en file
et l'envoie au retour du réseau. Le flux `CineFirebaseService.mediaChanges`
(événements d'application, section 8) met à jour tous les boutons d'un même
titre (fiche, cartes).

Les actions qui modifient des données retournent `""` en cas de succès, sinon
le message d'erreur en français à afficher (*SnackBar*). `toggleFavorite` et
`toggleWatched` retournent le nouvel état.

**Déconnexion** (section 8) : avant *Log Out*, le bouton « Se déconnecter »
et la suppression de compte appellent `signOutCleanup` : rappels programmés
annulés (téléphone et web), genres et rappels du membre effacés de
l'appareil. L'onboarding, propre à l'appareil, est gardé. `signOutCleanup`
appelle aussi `clearPrivateLocalData` (membre 3) : modifications faites hors
connexion envoyées, puis données privées SQLite effacées.

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
création ou mise à jour de `movies/{tmdbId}` et `series/{tmdbId}` : les widgets du catalogue affichent
les vrais titres TMDB et favoris, listes et vus continuent de fonctionner.
Les sorties au cinéma des films à venir sont ajoutées au calendrier
(`releaseEvents`) par `tool/seed_firestore.dart --release-events`, les règles
réservant cette collection aux admins.

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

`lib/custom_code/actions/firebase_service.dart` (`CineFirebaseService`, nom
choisi pour ne pas entrer en conflit avec `FirebaseService` de
`firebase_core`) regroupe l'accès aux données : profil, pseudo, avatar,
préférences, favoris, vus, listes, avis et likes, historique de recherche,
genres, plateformes et catalogue. Un titre est désigné partout par sa clé
`movie_550` / `series_1399` (`mediaKey`, `parseMediaKey`). `catalogRow`
convertit un film ou une série en ligne commune lue par les widgets.

### Tests

| Fichier | Contenu |
|---|---|
| `firebase/tests/rules.test.js` | règles Firestore sur l'émulateur : un membre ne lit ni ne modifie les données d'un autre, listes publiques, pseudos, avis et likes, cache TMDB, écritures admin |
| `test/auth_service_test.dart` | validation, traduction des erreurs Firebase, `AuthService` avec une passerelle simulée |
| `test/auth_actions_test.dart` | actions `auth*` et `deleteMyAccount` |
| `test/firebase_service_test.dart` | validateurs, clés `movie_550`, conversion des documents (`cineRow`, `catalogRow`), erreurs Firestore |
| `test/cine_models_test.dart` | modèles (`fromJson`, `toJson`, SQLite, égalité) |
| `test/avatar_picker_test.dart` | `AvatarPicker` (galerie simulée, service en mémoire) |
| `test/mark_watched_button_test.dart` | `MarkWatchedButton` et `FavoriteButton` : mise à jour optimiste, hors connexion, écriture refusée, boutons synchronisés |
| `test/sign_out_cleanup_test.dart` | `signOutCleanup` : rappels et genres du membre effacés, onboarding gardé |
| `test/preferences_panel_test.dart` | `PreferencesPanel` : genres et plateformes enregistrés en une écriture, thème, au moins un type de contenu, déconnecté |
| `test/profile_stats_test.dart` | `computeUserStats` (films, séries, durée, genre préféré), `watchTimeLabel`, `ProfileStats` recalculé après un « vu » |
| `test/reviews_section_test.dart` | `ReviewsSection` : état vide, publier, modifier, supprimer, like annulé si refusé, pagination |
| `test/trailer_player_test.dart` | adresses YouTube, `TrailerPlayer` sans vidéo valide |
| `test/sync_tmdb_catalog_test.dart` | conversion des résultats TMDB, fusion sans doublon, envoi par lots, TMDB injoignable, détails (bande-annonce, plateformes, séries terminées) |

## Membre 3 — UX, stockage local SQLite et notifications

Cahier des charges, sections 6.1 (walkthrough), 6.8 (calendrier), 6.9
(notifications) et 6.10 (SQLite et hors connexion). Pages dans le dossier
FlutterFlow `membre3_ux_sqlite_notifications` ; tout le reste est du code
personnalisé (`lib/custom_code/`), une action ou un widget par fichier.
Signatures complètes : [docs/flutterflow_custom_code.md](docs/flutterflow_custom_code.md)
(lignes « membre 3 »).

Ces paragraphes remplacent, pour le membre 3, les sections 4 (visite guidée)
et 5 (manifeste Android) ci-dessus, écrites avant ce travail.

### Pages et branchements FlutterFlow

| Page | Widget (en *Expanded*) | Réglages |
|---|---|---|
| **Onboarding** | `OnboardingWalkthrough` | sans App Bar ; `onFinish` → *Navigate To* HomePage (*Replace Route*, transition *Fade* 300 ms) |
| **Calendrier** | `ReleaseCalendar` | `initialView` = `month` (ou `week`) ; `onItemTap` → MediaDetail (`mediaId` = `selectedMediaId`) |
| **Notifications** | `NotificationsCenter` | `onOpenMedia` → MediaDetail (`mediaId`) ; transition *Right to Left* 250 ms |
| **HorsConnexion** | `OfflineScreen` | `onBackOnline` → *Navigate Back* ; `onItemTap` → MediaDetail (`mediaId`) |

Éléments à placer dans les pages des autres membres (avec leur accord) :

| Où | Quoi |
|---|---|
| HomePage, *On Page Load* | fait : action `cineNotificationService` (prépare les notifications, ouvre la fiche si une notification a lancé l'app, reprogramme les rappels) |
| HomePage, *On Page Load* | `shouldStartHomeTour` → si vrai, *Start Walkthrough* ; *On Walkthrough Complete / Skip* → `markHomeTourDone` |
| HomePage, Walkthrough | chaque étape affiche un component qui contient `WalkthroughStep` (`title`, `text`, `stepNumber`, `stepCount`) |
| App Bar de la HomePage | fait : `NotificationBell` ; `onTap` → *Navigate To* Notifications (*Right to Left* 250 ms) |
| Haut des pages principales | `OfflineBanner` (bandeau « Hors connexion », puis « Synchronisation en cours… », puis « À jour ») ; `onTap` → *Navigate To* HorsConnexion. Fait sur HomePage et Calendrier |
| Parametres | fait : `NotificationSettingsPanel` dans la section Notifications (remplace « Activer les rappels » et « Tester une notification ») ; « Revoir la présentation » : `resetOnboarding` puis *Navigate To* Onboarding |
| Parametres, déconnexion | rien à ajouter : `signOutCleanup` (déjà appelé avant *Log Out* et après la suppression du compte) appelle `clearPrivateLocalData`. En option, `getPendingChangesCount` avant, avec une confirmation si > 0 |
| Écrans de chargement | `CineSkeleton` (`variant` : `list`, `grid`, `row`, `detail`) à la place d'un spinner |

SQLite et les notifications programmées ne fonctionnent pas en *Test Mode*
web : tester sur un émulateur Android ou en *Run Mode*. Sur le web, le code
lit Firestore directement et un rappel ne s'affiche que si l'onglet est
ouvert.

### Stockage local SQLite (6.10)

`lib/custom_code/actions/cine_local_db.dart` (`CineLocalDb`) gère la base
`cinesphere.db` (paquet `sqflite`).

- **Versionnée** : la version est dans `PRAGMA user_version` ; chaque
  évolution du schéma est une migration **ajoutée à la fin** de
  `kLocalDbMigrations`, exécutée par `onUpgrade`. Une version plus récente
  que le code (retour en arrière) recrée la base.
- **Tables**

  | Table | Contenu | Effacée à la déconnexion |
  |---|---|---|
  | `cached_movies`, `cached_series` | catalogue (une ligne JSON par titre) | non |
  | `cached_home_sections` | sections de l'accueil (`trending`, « Pour vous »…) | oui (dépend des genres du membre) |
  | `calendar_events` | sorties du calendrier | non |
  | `local_favorites` | favoris du membre (`user_id`) | oui |
  | `recent_searches` | 20 dernières recherches du membre | oui |
  | `pending_sync` | écritures faites hors connexion : opération, collection, document, payload JSON, `created_at`, `retry_count`, dernière erreur | oui (après un dernier essai d'envoi) |

- **Cache puis réseau** (`cacheThenNetwork`, `watchCatalog`, `watchMedia`,
  `watchCalendar`, `watchHomeSection`) : le cache s'affiche tout de suite ;
  s'il a plus de **24 h** (`cached_at`), Firestore est interrogé et le cache
  mis à jour. Hors connexion, le cache est affiché même périmé avec la date
  « enregistré le … » (`CacheResult.isStale`, `error`).
- `saveToSqlite`, `getLocalCacheSize` (« 1,2 Mo ») et `clearLocalCache`
  (vide le cache public, puis `VACUUM`) sont les actions FlutterFlow
  correspondantes.

### Hors connexion et synchronisation

`CineSyncService` (`cine_sync_service.dart`) :

- **réseau** : `connectivity_plus` et une requête vers les serveurs Firestore
  (4 s). Un Wi-Fi sans Internet compte comme hors connexion ;
- **`write`** : l'écriture part tout de suite ; en cas d'échec réseau elle
  attend dans `pending_sync`. Plusieurs écritures sur le même document
  n'en font qu'une (la dernière gagne) ;
- **au retour du réseau** : la file est rejouée dans l'ordre. Une erreur
  réseau arrête la reprise sans compter d'essai ; une autre erreur (règles
  Firestore…) compte un essai, et l'écriture est abandonnée après
  5 essais. Les favoris sont ensuite recopiés dans `local_favorites` ;
- utilisé par les notifications (lu, supprimé) ; les autres membres peuvent
  passer leurs écritures par `CineSyncService.instance.write`.

`OfflineScreen` montre ce qui reste consultable (favoris et catalogue
enregistrés), le nombre de modifications en attente et un bouton
« Réessayer ».

### Calendrier des sorties (6.8)

- `ReleaseCalendar` : vue mois ou semaine (`table_calendar`, en français).
  Chaque jour porte un point **doré** pour un film et **violet** pour un
  épisode. Les filtres sont « Mes favoris » et les plateformes. Sous le
  calendrier, la liste du jour propose « Me prévenir ». Le mois affiché est
  chargé avec 7 jours de marge, par le cache puis le réseau.
- `UpcomingReleasesList` : les mêmes sorties en liste groupée par jour,
  paginée au scroll, utilisée dans la fiche d'un titre (`mediaId`).

### Notifications (6.9)

`CineNotificationService` (`cine_notification_service.dart`) :

- **3 canaux Android**, que l'utilisateur peut couper séparément :
  `cinesphere_releases` (sorties de films), `cinesphere_episodes` (nouveaux
  épisodes), `cinesphere_reminders` (rappels demandés). Le fuseau horaire est
  celui du téléphone (`flutter_timezone`). Le mode inexact évite la
  permission « alarmes exactes ».
- **« Me prévenir »** : le rappel tombe à l'heure choisie (18 h par défaut),
  la veille ou le jour J, jamais après la sortie. S'il est trop tard, il tombe
  une heure avant ; une sortie imminente n'a pas de rappel.
- **Automatiques**, sur les 30 prochains jours (20 au plus) : épisodes des
  séries favorites, films favoris ou des plateformes suivies, sans doublon
  avec un rappel demandé.
- **Reprogrammation** au démarrage (au plus toutes les 6 h) et à chaque
  changement de réglage.
- **Réglages** : `users/{uid}.preferences` (`notificationsEnabled`,
  `notifyReleases`, `notifyFavoriteSeries`, `reminderTime`,
  `favoritePlatforms`), copiés sur le téléphone pour fonctionner hors
  connexion. « La veille / le jour J » est gardé sur le téléphone seulement.
- **Page Notifications** : chaque notification programmée est enregistrée
  dans `users/{uid}/notifications`. La page montre celles déjà remises
  (`scheduledAt` passé), les plus récentes d'abord, 20 par page. La requête
  ne porte que sur `scheduledAt` : pas d'index composite. Le badge compte
  les `isRead == false`.
- **Tap** : la notification porte `{"type", "tmdbId", "id"}`. Toucher la
  notification la marque comme lue et ouvre `MediaDetail` en glissant du bas,
  même quand elle lance l'application.

**AndroidManifest.xml** : ces lignes sont dans
`android/app/src/main/AndroidManifest.xml`. Il faut aussi les ajouter dans
FlutterFlow (*Custom Code → Configuration Files*), sinon un export FlutterFlow
les efface. Sans elles, rien ne s'affiche sur Android 13+ et les rappels
disparaissent au redémarrage du téléphone :

```xml
<!-- sous <manifest> -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>

<!-- dans <application> -->
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
    </intent-filter>
</receiver>
```

### Walkthrough (6.1)

- `OnboardingWalkthrough` : 4 étapes, puis l'écran **Préférences** : genres,
  plateformes et types de contenus en chips (au moins un type reste coché),
  et « Me prévenir des sorties ». L'autorisation des notifications est
  demandée à « Commencer », juste après l'étape qui explique à quoi elles
  servent ; un refus désactive les notifications dans le profil.
- **Flag « terminé »** : `cs_onboarding_done` sur le téléphone et
  `preferences.onboardingCompleted` dans Firestore. Après une réinstallation,
  le profil suffit. Hors connexion, les choix attendent sur le téléphone et
  sont écrits au retour du réseau, sans écraser des préférences modifiées
  entre-temps.
- Revu depuis Parametres, l'écran Préférences reprend les choix du profil.
- **Visite guidée de la HomePage** (bonus) : Walkthrough FlutterFlow dont
  chaque étape affiche `WalkthroughStep` (« Étape 2 sur 5 », Passer /
  Suivant / Terminer). `shouldStartHomeTour` et `markHomeTourDone` la
  proposent une seule fois.

### Expérience utilisateur

- Thème clair / sombre : travail du membre 1 (`PreferencesPanel`). Les
  widgets du membre 3 n'utilisent que les couleurs du thème.
- **Chargement** : `CineSkeleton` (shimmer) à la place des spinners.
- **Animations** : `FadeSlideIn` (apparition en cascade au premier
  chargement), `cineStateSwitcher` (fondu entre chargement, contenu, erreur),
  badge de la cloche animé, fiche ouverte depuis une notification en
  glissant du bas. Tout est coupé si le téléphone demande de réduire les
  animations.

### Déconnexion

`clearPrivateLocalData` est appelée par `signOutCleanup` (membre 1, avec son
accord), que la page Parametres lance avant *Log Out* et après la
suppression du compte. Elle tourne donc pendant que le membre est encore
connecté :

1. envoie les modifications faites hors connexion, si le réseau répond
   (6 s au plus) et si le compte existe encore ;
2. annule toutes les notifications programmées et efface les rappels et
   réglages gardés sur le téléphone ;
3. efface les données privées SQLite (voir le tableau plus haut).

Elle renvoie le nombre de modifications perdues faute de réseau.
`getPendingChangesCount` permet de prévenir le membre avant.

Clés `shared_preferences` du membre 3 :

| Clé | Contenu | À la déconnexion |
|---|---|---|
| `cs_onboarding_done`, `cs_home_tour_done` | walkthrough et visite guidée vus sur ce téléphone | gardées |
| `cs_onboarding_pending` | choix du walkthrough pas encore écrits dans Firestore | effacée |
| `cs_favorite_genres` | genres choisis, par nom (lus par HomeFeed) | effacée |
| `cs_reminders`, `cs_reminder_details` | rappels « Me prévenir » | effacées |
| `cs_auto_reminders`, `cs_last_reschedule` | notifications automatiques, dernière reprogrammation | effacées |
| `cs_notification_settings` | copie locale des réglages + veille / jour J | effacée |

### Tests

```bash
flutter test                 # toute la suite
flutter test --coverage      # couverture dans coverage/lcov.info
```

155 tests pour le domaine du membre 3. SQLite est testé sur une vraie base
en mémoire (`sqflite_common_ffi`). Dans les tests de widgets, sqflite se
bloque : on y utilise `MemoryLocalDb` (`test/offline_test_utils.dart`).
Firestore, le réseau et le plugin de notifications sont remplacés par des
faux (`FakeCineFirebaseService`, `FakeNetwork`, `FakeRemoteWriter`,
`FakeNotifier`, `Fake` de mocktail).

| Fichier | Tests | Contenu |
|---|---|---|
| `test/cine_local_db_test.dart` | 27 | migrations, cache et durée de 24 h, cache puis réseau, file `pending_sync` (fusion, ordre), favoris, recherches, calendrier, taille et vidage du cache |
| `test/cine_sync_service_test.dart` | 17 | envoi direct ou en file, réseau perdu pendant l'envoi, reprise dans l'ordre, abandon après 5 essais, actions FlutterFlow |
| `test/offline_widgets_test.dart` | 7 | `OfflineBanner` (hors connexion → synchronisation → à jour, toucher le bandeau), `OfflineScreen` |
| `test/release_calendar_test.dart` | 13 | filtres, points colorés, liste du jour, rappel, affichage hors connexion |
| `test/upcoming_releases_list_test.dart` | 6 | liste groupée par jour, pagination, rappel, erreur (faux Firestore) |
| `test/cine_notification_service_test.dart` | 21 | heure du rappel, réglages, notifications automatiques, reprogrammation, tap, écritures par la file |
| `test/notification_actions_test.dart` | 7 | actions de notification FlutterFlow |
| `test/flutter_local_notifier_test.dart` | 6 | ce que reçoit le canal Android du plugin : canaux, mode inexact, fuseau, tap, lancement |
| `test/notification_navigation_test.dart` | 2 | tap → `MediaDetail`, y compris au lancement de l'app |
| `test/notification_widgets_test.dart` | 14 | `NotificationBell`, `NotificationsCenter`, `NotificationSettingsPanel` |
| `test/onboarding_test.dart` | 16 | flag sur le téléphone et dans Firestore, hors connexion, écran Préférences, autorisation, visite guidée, `WalkthroughStep` |
| `test/ux_test.dart` | 14 | `CineSkeleton`, `FadeSlideIn`, `cineStateSwitcher`, réduction des animations |
| `test/clear_private_local_data_test.dart` | 5 | déconnexion en ligne, hors connexion, envoi refusé, compte supprimé, web |

Non couverts volontairement : le vrai réseau et les écritures réelles dans
Firestore (remplacés par des faux), et les pages générées par FlutterFlow
(leurs widgets sont testés).

**Test d'intégration** (sur un émulateur ou un téléphone Android, pas sur
le web). Le paquet `integration_test` n'est pas dans `pubspec.yaml` :
FlutterFlow ne lit pas les dépendances `sdk: flutter` (erreur « Unrecognized
dependency format »). L'ajouter le temps du test, sans le pousser vers
FlutterFlow ni le commiter :

```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
```

```bash
flutter devices                                          # id de l'appareil
flutter test integration_test/membre3_test.dart -d <id>
git checkout pubspec.yaml pubspec.lock                   # après le test
```

`integration_test/membre3_test.dart` (5 tests) utilise la vraie base sqflite
de l'appareil (un fichier séparé, supprimé après chaque test) et le vrai
plugin de notifications. Firestore reste simulé : pas besoin de compte, et
rien n'est écrit dans Firebase. Il couvre :

- le walkthrough complet, jusqu'au profil et au flag ;
- un rappel « Me prévenir » visible dans les notifications programmées
  d'Android, puis annulé ;
- le schéma SQLite et le cache du calendrier ;
- une écriture hors connexion envoyée au retour du réseau ;
- la déconnexion.

Le test de déconnexion annule toutes les notifications programmées de
l'application sur l'appareil.

### Note technique : version de `sqlite3`

`sqflite_common_ffi` 2.3.5 (tests) ne fonctionne pas avec `sqlite3` 3.x.
`pubspec.lock` fixe donc `sqlite3` à **2.7.6**, sans changer `pubspec.yaml`
(versions fixées par FlutterFlow). Si un `flutter pub upgrade` la fait
monter :

1. ajouter temporairement `dependency_overrides: sqlite3: 2.7.6` dans
   `pubspec.yaml` ;
2. `flutter pub get` ;
3. retirer l'override, puis `flutter pub get` à nouveau.

`flutter pub get` modifie aussi `ios/Flutter/ephemeral/…` : ne pas le
committer.
