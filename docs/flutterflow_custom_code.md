# Code personnalisé FlutterFlow — CinéSphère

Cahier des charges, section 7 : chaque widget, action et fonction
personnalisés, sa signature et la façon de l'ajouter dans l'éditeur
FlutterFlow. Le code est dans `lib/custom_code/` (widgets et actions) et
`lib/custom_code/functions/` (fonctions, exportées par
`lib/flutter_flow/custom_functions.dart`).

La colonne **Domaine** indique le membre responsable du sujet (répartition
du cahier des charges) ; l'historique git indique qui a écrit le code.

## Ajouter ou mettre à jour un élément

**Méthode utilisée par l'équipe : VS Code.**

1. Ouvrir le projet dans VS Code avec l'extension *FlutterFlow: Custom Code
   Editor*, puis *Pull latest changes*.
2. Créer ou modifier le fichier dans `lib/custom_code/widgets/` ou
   `lib/custom_code/actions/` en gardant l'en-tête généré
   (`// Automatic FlutterFlow imports … // DO NOT REMOVE OR MODIFY THE CODE
   ABOVE!`). Un widget doit être un `StatefulWidget` avec les paramètres
   `width` et `height` ; une action est une fonction `Future` de premier niveau
   dont le nom est celui du fichier en camelCase.
3. `flutter analyze` puis `flutter test`.
4. *Push to FlutterFlow*. Dans l'éditeur web : *Custom Code* → l'élément
   apparaît, puis l'icône des problèmes (bug) → *Custom Code* → vérifier qu'il
   n'y a pas d'erreur de compilation.

**Sans VS Code** : éditeur web → *Custom Code* → *+ Add* → *Widget*,
*Action* ou *Function* → nommer exactement comme ci-dessous → coller le code
sous l'en-tête → déclarer les paramètres (types ci-dessous) → *Save* puis
*Compile Code*.

**Utilisation dans une page** : un widget se place depuis *Widget Palette →
Components → Custom Code Widgets* (souvent dans une Column, réglé en
*Expanded*) ; une action s'ajoute dans *Actions → Custom Action* ; une
fonction s'utilise dans une valeur (*Set from Variable → Custom Functions*).
Les paramètres de type callback (`onItemTap`, `onChanged`…) se règlent dans
l'onglet *Actions* du widget.

Paquets utilisés (déjà déclarés dans FlutterFlow, versions imposées par
FlutterFlow) : `cloud_firestore`, `firebase_auth`, `cached_network_image`,
`flutter_cache_manager`, `flutter_local_notifications`, `timezone`,
`shared_preferences`, `image_picker`, `collection`.

## Widgets

| Widget | Paramètres | Rôle | Domaine |
|---|---|---|---|
| `MediaCard` | `title` String (requis), `posterUrl` String?, `mediaType` String?, `rating` double?, `releaseDate` DateTime?, `onTap` Action | carte affiche + badges | membre 2 |
| `CatalogBrowser` | `pageSize` int?, `initialMediaType` String?, `onItemTap(mediaId)` Action | recherche, filtres, tri, pagination infinie | membre 2 |
| `HomeFeed` | `onItemTap(tappedMediaId)` Action, `onOnboardingRequired` Action | accueil : Pour vous, Tendances, Bientôt, Mieux notés | membre 2 |
| `MediaDetailView` | `mediaId` String (requis) | fiche complète d'un titre | membre 2 |
| `NewsFeed` | `pageSize` int?, `onItemTap(linkedMediaId)` Action | actualités paginées | membre 2 |
| `OnboardingWalkthrough` | `onFinish` Action | 4 étapes, puis Préférences (genres, plateformes, types de contenus, notifications) ; autorisation des notifications ; flag sur le téléphone et dans Firestore | membre 3 |
| `UpcomingReleasesList` | `mediaId` String?, `pageSize` int?, `reminderMinutesBefore` int?, `onItemTap(selectedMediaId)` Action | calendrier des sorties en liste, rappels | membre 3 |
| `ReleaseCalendar` | `initialView` String? (`month` / `week`), `onItemTap(selectedMediaId)` Action | calendrier mois / semaine, points film / épisode, filtres, « Me prévenir », cache hors connexion | membre 3 |
| `NotificationBell` | `iconColor` Color?, `onTap` Action | cloche avec le nombre de non lues | membre 3 |
| `NotificationsCenter` | `pageSize` int?, `onOpenMedia(mediaId)` Action | page Notifications : remises, paginées, lu / tout marquer comme lu | membre 3 |
| `NotificationSettingsPanel` | — | réglages des notifications (à placer dans Parametres) | membre 3 |
| `OfflineBanner` | `onBackOnline` Action | bandeau hors connexion / synchronisation / à jour | membre 3 |
| `OfflineScreen` | `onBackOnline` Action, `onItemTap(mediaId)` Action | page Hors connexion : favoris et catalogue enregistrés, modifications en attente | membre 3 |
| `WalkthroughStep` | `title` String (requis), `text` String (requis), `stepNumber` int?, `stepCount` int?, `onNext` Action, `onSkip` Action | bulle d'une étape de la visite guidée (Walkthrough FlutterFlow) | membre 3 |
| `CineSkeleton` | `variant` String? (`list`, `grid`, `row`, `detail`), `itemCount` int? | squelette de chargement (shimmer) | membre 3 |
| `FadeSlideIn` | `child` Widget (requis), `index` int?, `enabled` bool? | apparition en cascade (utilisé depuis le code) | membre 3 |
| `FavoriteButton` | `mediaId` String (requis), `iconSize` double?, `onChanged(isFavorite)` Action | cœur, mise à jour optimiste | membre 1 |
| `FavoritesGrid` | `pageSize` int?, `onItemTap(tappedMediaId)` Action | grille des favoris paginée | membre 1 |
| `AddToWatchlistButton` | `mediaId` String (requis) | ajout à une liste (feuille du bas) | membre 1 |
| `MarkWatchedButton` | `mediaId` String (requis), `onChanged(isWatched)` Action | « Marquer comme vu », mise à jour optimiste | membre 1 |
| `ReviewsSection` | `mediaId` String (requis) | avis : moyenne, son avis, avis paginés, likes | membre 1 |
| `AvatarPicker` | `avatarUrl` String?, `onChanged(avatarUrl)` Action | photo de profil | membre 1 |
| `ProfileStats` | — | statistiques du profil | membre 1 |
| `PreferencesPanel` | — | thème, genres, plateformes, cache | membre 1 |
| `TrailerPlayer` | `trailerUrl` String (requis), `autoPlay` bool? | bande-annonce YouTube intégrée | membre 1 |

## Actions

Les actions qui modifient des données retournent `""` en cas de succès,
sinon le message d'erreur en français (à afficher dans une *SnackBar*).

| Action | Paramètres → retour | Rôle | Domaine |
|---|---|---|---|
| `authSignIn` | `email`, `password` → String | connexion | membre 1 |
| `authSignUp` | `username`, `email`, `password`, `confirmPassword` → String | inscription | membre 1 |
| `authConfirmSignUp` | `email`, `code` → String | adresse confirmée ? | membre 1 |
| `authResendCode` | `email` → String | renvoi du lien de confirmation | membre 1 |
| `authSendResetCode` | `email` → String | lien de réinitialisation | membre 1 |
| `authResetPassword` | `email`, `code`, `newPassword`, `confirmPassword` → String | nouveau mot de passe | membre 1 |
| `authService` | → bool | session ouverte et adresse confirmée (fichier du service d'authentification) | membre 1 |
| `firebaseService` | → bool | Firestore répond (fichier du service de données `CineFirebaseService`) | membre 1 |
| `cineModels` | → int | version du schéma (fichier des modèles Dart) | commun |
| `updateMyProfile` | `username`, `bio` → String | profil | membre 1 |
| `deleteMyAccount` | → String | suppression du compte et des données | membre 1 |
| `signOutCleanup` | → (rien) | à appeler avant *Log Out* : appelle `clearPrivateLocalData` (envoi des modifications hors connexion, notifications annulées, données privées SQLite effacées), puis efface les préférences locales du membre | membre 1 (+ membre 3) |
| `toggleFavorite` | `mediaId` → bool | ajoute / retire un favori | membre 1 |
| `toggleWatched` | `mediaId` → bool | marque / retire « vu » | membre 1 |
| `createWatchlist` | `name` → String | nouvelle liste | membre 1 |
| `renameWatchlist` | `watchlistId`, `name` → String | renommer | membre 1 |
| `deleteWatchlist` | `watchlistId` → String | supprimer une liste | membre 1 |
| `addToWatchlist` | `watchlistId`, `mediaId` → String | ajouter un titre | membre 1 |
| `removeWatchlistItem` | `watchlistId`, `itemId` → String | retirer un titre | membre 1 |
| `clearViewHistory` | → String | vide l'onglet Historique | membre 1 |
| `syncTmdbCatalog` | `force` bool → String | import TMDB dans le catalogue | membre 1 (pour le catalogue du membre 2) |
| `hasCompletedOnboarding` | → bool | onboarding déjà vu ? (téléphone, puis profil Firestore) | membre 3 |
| `completeOnboarding` | `favoriteGenres` List<String> → (rien) | fin de l'onboarding | membre 3 |
| `shouldStartHomeTour` | → bool | lancer la visite guidée de la HomePage ? | membre 3 |
| `markHomeTourDone` | → (rien) | visite guidée terminée ou passée | membre 3 |
| `resetOnboarding` | → (rien) | « Revoir la présentation » | membre 3 |
| `cineNotificationService` | → bool | à charger sur la HomePage : prépare les notifications, ouvre la fiche si une notification a lancé l'app, reprogramme ; vrai si activées (fichier du service de notifications) | membre 3 |
| `initLocalNotifications` | → bool | initialisation + permission | membre 3 |
| `scheduleReleaseNotification` | `reminderKey`, `title`, `body`, `scheduledAt` DateTime → bool | rappel programmé | membre 3 |
| `cancelReleaseNotification` | `reminderKey` → (rien) | annule un rappel | membre 3 |
| `getScheduledReminders` | → List<String> | rappels en attente | membre 3 |
| `showInstantNotification` | `title`, `body` → bool | notification immédiate | membre 3 |
| `rescheduleAllNotifications` | → int | reprogramme tout avec les réglages actuels | membre 3 |
| `cancelAllNotifications` | → (rien) | annule toutes les notifications programmées | membre 3 |
| `markAllNotificationsRead` | → int | « Tout marquer comme lu » | membre 3 |
| `getUnreadNotificationsCount` | → int | notifications remises non lues | membre 3 |
| `cineLocalDb` | → int | version de la base SQLite (fichier de `CineLocalDb`) | membre 3 |
| `cineSyncService` | → bool | démarre la synchronisation hors connexion ; vrai si en ligne (fichier de `CineSyncService`) | membre 3 |
| `saveToSqlite` | `table`, `key`, `json` → bool | met un contenu en cache SQLite | membre 3 |
| `syncSqliteWithFirestore` | → int | rejoue les écritures en attente ; nombre envoyé | membre 3 |
| `checkInternetConnection` | → bool | Internet répond ? | membre 3 |
| `getLocalCacheSize` | → String | taille du cache (« 1,2 Mo ») | membre 3 |
| `clearLocalCache` | → String | vide le cache public | membre 3 |
| `getPendingChangesCount` | → int | modifications hors connexion pas encore envoyées | membre 3 |
| `clearPrivateLocalData` | → int | appelée par `signOutCleanup` : envoie, puis efface les données privées et les notifications ; nombre de modifications perdues | membre 3 |

## Fonctions

Fonctions pures, testées dans `test/custom_functions_test.dart`.

| Fonction | Signature | Exemple |
|---|---|---|
| `formatRuntime` | `String formatRuntime(int? minutes)` | 135 → « 2 h 15 min » |
| `formatReleaseDate` | `String formatReleaseDate(DateTime? date)` | « 20 octobre 2026 » |
| `daysUntil` | `int daysUntil(DateTime? date)` | jours avant la sortie |
| `isReleaseSoon` | `bool isReleaseSoon(DateTime? date, int withinDays)` | sortie dans les N jours |
| `releaseCountdownLabel` | `String releaseCountdownLabel(DateTime? date)` | « Dans 3 jours », « Demain » |
| `mediaTypeLabel` | `String mediaTypeLabel(String? mediaType)` | « Film » / « Série » |
| `statusLabel` | `String statusLabel(String? status)` | « Terminée », « À venir »… |
| `seasonsLabel` | `String seasonsLabel(int? seasons, int? episodes)` | « 3 saisons • 24 épisodes » |
| `ratingLabel` | `String ratingLabel(double? rating)` | 8.44 → « 8.4 » |
| `ratingColor` | `Color ratingColor(double? rating)` | vert ≥ 7,5, jaune ≥ 5, rouge |
| `notificationIdFromString` | `int notificationIdFromString(String key)` | identifiant de notification stable |
