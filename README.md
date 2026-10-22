# CineSphere

Plateforme pour les amateurs de films et de séries TV : catalogue, recherche,
favoris, calendrier des sorties et rappels.

Bonus réalisés : **Supabase · Search & Filtres · Pagination · Local
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

## 1. Supabase

1. Supabase → *SQL Editor* → exécuter les scripts dans l'ordre indiqué dans
   [supabase/README.md](supabase/README.md) (`schema.sql`, les migrations,
   `seed.sql` ; chaque script peut être relancé).
2. FlutterFlow → *Settings → Integrations → Supabase* → **Get Schema**.

Tables : `profiles`, `genres`, `media` (films **et** séries, colonne
`media_type`), `release_events` (dates de diffusion), `news`, `favorites`.
Une seule table `media` permet une seule recherche, un seul filtre et une seule
pagination pour les films et les séries.

## 2. Custom code fourni

### Widgets

| Widget | Paramètres | Rôle |
|---|---|---|
| `CatalogBrowser` | `pageSize`, `initialMediaType`, `onItemTap(mediaId)` | Recherche (titre + synopsis, délai 400 ms), filtres (type, genre, note min., statut), tri, pagination Supabase avec scroll infini, états chargement / vide / erreur, pull-to-refresh |
| `MediaCard` | `title`, `posterUrl`, `mediaType`, `rating`, `releaseDate`, `onTap` | Carte affiche + badges |
| `FavoriteButton` | `mediaId`, `iconSize`, `onChanged(isFavorite)` | Cœur relié à la table `favorites` |
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
| 1 — Supabase & compte | schéma, migrations, RLS, Storage, auth, profil et avatar, favoris, listes, vus (voir ci-dessous) |
| 2 — Catalogue | `CatalogBrowser`, `MediaCard`, HomePage, MediaDetail, pagination |
| 3 — UX & notifications | Onboarding + Walkthrough FlutterFlow, calendrier, notifications locales, tests |

## Membre 1 — Authentification, profil et Supabase

Pages dans le dossier FlutterFlow `membre1_auth_profil_supabase`. Ce sont des
pages FlutterFlow **natives** (widgets FlutterFlow, requêtes Supabase,
thème CinéSphère) qui appellent des actions personnalisées, une par fichier.

### Base Supabase

Schéma, RLS, triggers, Storage et audits : voir
[supabase/README.md](supabase/README.md) (7 migrations dans
`supabase/migrations/`).

### Pages

| Page | Paramètre | Contenu | Actions |
|---|---|---|---|
| `login` (Entry Page) | — | connexion, liens vers Inscription et MotDePasseOublie | `authSignIn` |
| `Inscription` | — | e-mail, pseudo (unicité vérifiée pendant la saisie), mot de passe + confirmation | `authSignUp` |
| `ConfirmationEmail` | `email` | saisie du code reçu par e-mail, renvoi du code | `authConfirmSignUp`, `authResendCode` |
| `MotDePasseOublie` | — | envoi d'un code de réinitialisation | `authSendResetCode` |
| `NouveauMotDePasse` | `email` | code + nouveau mot de passe (seulement le mot de passe si déjà connecté) | `authResetPassword`, `authSendResetCode` |
| `Profil` | — | photo de profil (`AvatarPicker`), pseudo et bio modifiables, nombre d'avis publiés | `updateMyProfile` |
| `Parametres` | — | profil, favoris, changer de mot de passe, notifications, revoir l'onboarding, déconnexion | `initLocalNotifications`, `showInstantNotification`, *Log Out* |
| `Favoris` | — | 3 onglets : **Favoris**, **Mes listes** (création), **Vus** | `createWatchlist` |
| `DetailListe` | `watchlistId` | titres d'une liste, renommer, retirer un titre, supprimer la liste (avec confirmation) | `renameWatchlist`, `removeWatchlistItem`, `deleteWatchlist` |

Sur la fiche d'un titre (`MediaDetailView`, membre 2), avec son accord, le
membre 1 a ajouté deux widgets :

| Widget | Paramètres | Rôle |
|---|---|---|
| `AddToWatchlistButton` | `mediaId` | feuille avec les listes du membre ; ajout à une liste existante ou création d'une liste avec le titre |
| `MarkWatchedButton` | `mediaId`, `onChanged(isWatched)` | « Marquer comme vu » relié à la table `watched` (onglet Vus) |
| `AvatarPicker` | `avatarUrl`, `onChanged(avatarUrl)` | photo choisie dans la galerie, réduite à 512 px, 2 Mo max, envoyée dans le bucket `avatars/{user_id}/` puis enregistrée dans `profiles.avatar_url` |

Les actions qui modifient des données retournent `""` en cas de succès, sinon
le message d'erreur en français à afficher (*SnackBar*). `toggleFavorite` et
`toggleWatched` retournent le nouvel état.

### Authentification

La logique est dans `lib/custom_code/actions/auth_service.dart` ; les actions
`auth*` ne font que l'appeler :

- validation : e-mail, mot de passe ≥ 8 caractères, confirmation, pseudo
  (3 à 24 caractères) dont l'unicité est vérifiée avant l'inscription
  (fonction SQL `username_available`) ;
- le pseudo est envoyé dans les métadonnées d'inscription et le trigger
  `on_auth_user_created` crée `profiles` + `user_preferences` ;
- erreurs Supabase Auth traduites en français (`CineFailure`) ;
- **codes par e-mail plutôt que liens** : la confirmation d'inscription et le
  mot de passe oublié utilisent le code à usage unique (`{{ .Token }}`) saisi
  dans l'application. Les liens Supabase pointent vers le *Site URL*
  (`localhost:3000`), inutilisable en Test Mode FlutterFlow ou sur téléphone ;
- un e-mail non confirmé à la connexion renvoie un code et ouvre
  ConfirmationEmail ;
- session persistante gérée par `supabase_flutter`.

Réglages Supabase (*Authentication*) :

- *Email Templates* → **Confirm signup** et **Reset Password** : le corps doit
  contenir `{{ .Token }}` ;
- *Providers → Email* : longueur minimale du mot de passe **8** ;
- SMTP : le SMTP intégré de Supabase n'envoie que 2 e-mails par heure et ne
  permet pas de modifier les modèles ; le projet utilise un **SMTP Gmail**
  (*Settings → SMTP*).

### Données

`lib/custom_code/actions/supabase_service.dart` (`SupabaseService`) regroupe
l'accès aux données du membre 1 : profil, pseudo, avatar, préférences, listes
(créer, renommer, supprimer, ajouter / retirer un titre), genres,
plateformes, cache TMDB. Les modèles sont dans `cine_models.dart`.

Pendant la transition « expand / contract » (voir
[supabase/README.md](supabase/README.md)), favoris, listes et vus visent les
titres du catalogue de démonstration par `media_id`.

### Tests

| Fichier | Contenu |
|---|---|
| `test/auth_service_test.dart` | validation, traduction des erreurs, appels Supabase Auth simulés |
| `test/auth_actions_test.dart` | actions `auth*` |
| `test/auth_forms_test.dart` | écrans connexion, inscription, mot de passe oublié, nouveau mot de passe |
| `test/supabase_service_test.dart` | `SupabaseService` (réponses HTTP Supabase simulées) |
| `test/cine_models_test.dart` | modèles (`fromJson`, `toJson`, SQLite, égalité) |
| `test/avatar_picker_test.dart` | `AvatarPicker` (galerie et Supabase simulés) |
| `test/mark_watched_button_test.dart` | `MarkWatchedButton` |

Vérifié aussi sur la vraie base avec deux comptes de test : accès anonyme
refusé, RLS des favoris, listes et vus (un membre ne voit ni ne modifie les
données de l'autre), envoi d'avatar dans son seul dossier.
