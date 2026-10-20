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

1. Supabase → *SQL Editor* → exécuter [supabase/schema.sql](supabase/schema.sql)
   (tables, RLS, données de démo ; le script peut être relancé).
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
| 1 — Supabase & compte | `schema.sql`, RLS, auth, profil, favoris (`toggleFavorite`, `FavoriteButton`, page Favoris) |
| 2 — Catalogue | `CatalogBrowser`, `MediaCard`, HomePage, MediaDetail, pagination |
| 3 — UX & notifications | Onboarding + Walkthrough FlutterFlow, calendrier, notifications locales, tests |

## Authentification (membre 1)

Écrans dans le dossier FlutterFlow `membre1_auth_profil_supabase`, chacun avec
**un seul custom widget** en *Expanded* :

| Page | Widget | Callbacks |
|---|---|---|
| `login` (Entry Page) | `LoginForm` | `onSignedIn` → HomePage (*Replace Route*) · `onCreateAccount` → Inscription · `onForgotPassword` → MotDePasseOublie |
| `Inscription` | `SignUpForm` | `onSignedUp` → HomePage (*Replace Route*) · `onGoToLogin` → retour |
| `MotDePasseOublie` | `ForgotPasswordForm` | `onCodeSent(email)` → NouveauMotDePasse (`email`) · `onBackToLogin` → retour |
| `NouveauMotDePasse` (paramètre `email`, String) | `NewPasswordForm` | `onPasswordUpdated` → HomePage (*Replace Route*) · `onBack` → retour |

La logique est dans `lib/custom_code/actions/auth_service.dart` (action
`authService` = « un membre est-il connecté ? ») :

- validation : e-mail, mot de passe ≥ 8 caractères, confirmation, pseudo
  (3 à 24 caractères) dont l'**unicité est vérifiée pendant la saisie**
  (fonction SQL `username_available`, appelable avant l'inscription) ;
- le pseudo est envoyé dans les métadonnées d'inscription et le trigger
  `on_auth_user_created` crée `profiles` + `user_preferences` ;
- erreurs Supabase Auth traduites en français (`CineFailure`), état de
  chargement sur les boutons, bouton afficher / masquer le mot de passe ;
- **codes par e-mail plutôt que liens** : la confirmation d'inscription et le
  mot de passe oublié utilisent le code à usage unique (`{{ .Token }}`) saisi
  dans l'application. Les liens Supabase pointent vers le *Site URL*
  (`localhost:3000`), inutilisable en Test Mode FlutterFlow ou sur téléphone ;
- un e-mail non confirmé à la connexion renvoie un code et l'écran propose de
  le saisir ;
- session persistante gérée par `supabase_flutter`.

Réglages Supabase (*Authentication*) :

- *Email Templates* → **Confirm signup** et **Reset Password** : le corps doit
  contenir `{{ .Token }}` ;
- *Providers → Email* : longueur minimale du mot de passe **8** ;
- le SMTP intégré de Supabase n'envoie que **2 e-mails par heure**. Pour les
  tests, désactiver **Confirm email** ou configurer un SMTP (*Settings → SMTP*).

Tests : `test/auth_service_test.dart` (validation, traduction des erreurs,
service, appels HTTP Supabase simulés) et `test/auth_forms_test.dart` (les 4
écrans).
