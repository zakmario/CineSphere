# Base de données Supabase — CinéSphère

Responsable : **Membre 1 — Authentification, profil et Supabase**.

## Installation (projet neuf ou existant)

Dans Supabase → **SQL Editor**, exécuter dans cet ordre (chaque script est
rejouable) :

1. `schema.sql` — schéma historique et données de démonstration
2. `migrations/20261020000100_core_schema.sql` — tables de la section 5.2
3. `migrations/20261020000200_functions_triggers.sql` — triggers et fonctions
4. `migrations/20261020000300_rls.sql` — Row Level Security
5. `migrations/20261020000400_storage_avatars.sql` — bucket `avatars`
6. `migrations/20261020000500_security_hardening.sql` — corrections des audits Supabase
7. `migrations/20261021000100_media_tmdb_images.sql` — vraies affiches TMDB du catalogue de démonstration
8. `migrations/20261021000200_media_targets.sql` — listes et vus visent aussi `media`
9. `migrations/20261022000100_delete_my_account.sql` — suppression de compte par le membre
10. `migrations/20261022000200_media_tmdb_import.sql` — `media.tmdb_id` et import du catalogue TMDB
11. `migrations/20261022000300_media_tmdb_details.sql` — détails TMDB (durée, saisons, bande-annonce, plateformes)
12. `migrations/20261022000400_media_details_synced.sql` — `media.details_synced_at` (bandes-annonces manquantes)
13. `seed.sql` — genres TMDB et plateformes

Puis dans FlutterFlow : *Settings → Integrations → Supabase → Get Schema*.

Avec la CLI Supabase : `supabase db push` puis `supabase db seed`.

## Tables

| Table | Contenu | Accès (RLS) |
|---|---|---|
| `profiles` | pseudo unique, e-mail, avatar, bio, rôle | propriétaire ; profil public d'un autre membre via `get_public_profile()` (sans e-mail), pseudo libre via `username_available()` |
| `user_preferences` | genres, plateformes, notifications, thème, onboarding | propriétaire |
| `movies`, `series`, `movie_genres`, `series_genres` | copie légère des contenus TMDB utilisés | lecture connectés, écriture admin ou fonctions `upsert_*_from_tmdb` |
| `genres`, `platforms` | référentiels TMDB | lecture connectés, écriture admin |
| `favorites`, `watched`, `notifications`, `search_history` | données privées | propriétaire |
| `watchlists`, `watchlist_items` | listes personnalisées | propriétaire ; lecture publique si `is_public` |
| `reviews`, `review_likes` | avis et likes | lecture publique sauf `is_private` ; écriture auteur |
| `release_events` | sorties (films, épisodes) | lecture connectés, écriture admin |

Automatismes :

- `on_auth_user_created` crée `profiles` + `user_preferences` à l'inscription
  (pseudo tiré de `raw_user_meta_data.username` ou de l'e-mail, rendu unique) ;
- `updated_at` mis à jour automatiquement ;
- `import_tmdb_media(items)` (membres connectés, 200 titres au plus par appel)
  crée ou met à jour les titres de `media` à partir des listes TMDB (clé
  `media_type` + `tmdb_id`, genres retrouvés dans `genres` par leur identifiant
  TMDB) et ajoute la sortie au cinéma des films à venir dans `release_events` ;
- `enrich_tmdb_media(items)` (membres connectés, 100 titres au plus) complète
  durée, saisons, épisodes, statut « terminée », bande-annonce et plateformes
  (noms de la table `platforms` pour les identifiants TMDB connus) et note
  la date du passage dans `details_synced_at` ;
- `delete_my_account()` (membres connectés uniquement) supprime le compte de
  l'appelant et toutes ses données en cascade ;
- un utilisateur ne peut pas modifier son propre `role` ;
- Storage `avatars` : lecture publique, écriture dans `{user_id}/` uniquement,
  2 Mo maximum, JPEG / PNG / WebP.

## Audits Supabase (advisors)

Aucune erreur. Avertissements restants, volontaires : les fonctions
`SECURITY DEFINER` appelables par l'application (`username_available`,
`get_public_profile`, `upsert_*_from_tmdb`, `import_tmdb_media`, `enrich_tmdb_media`, `is_admin` pour la RLS) ; elles
n'exposent que des champs contrôlés. `rls_auto_enable` est une fonction
préexistante du projet.

## Transition « expand / contract »

Les widgets actuels des membres 2 et 3 lisent encore la table `media`
(`favorites.media_id`, `release_events.media_id`, `news`). La migration 1
ajoute le nouveau schéma **sans** supprimer ces colonnes : pendant la
transition, une ligne de `favorites` / `release_events` vise exactement un
de `media_id`, `movie_id` ou `series_id`. La migration 7 fait de même pour
`watchlist_items` et `watched` (un titre au plus une fois par liste, un seul
« vu » par membre).

Quand plus aucun widget n'utilise `media`, une migration « contract »
supprimera `media`, `news`, les colonnes `media_id` et
`profiles.favorite_genres / favorite_platforms / onboarding_done`, et
ramènera les contraintes à `num_nonnulls(movie_id, series_id) = 1`.

## Code Dart

FlutterFlow ne synchronise que les actions, widgets et fonctions
personnalisés. Le code d'accès aux données vit donc dans deux actions :

- `lib/custom_code/actions/cine_models.dart` — modèles (`fromJson`, `toJson`,
  `fromMap`/`toMap` SQLite, `copyWith`, égalité par valeur) ;
- `lib/custom_code/actions/supabase_service.dart` — `SupabaseService`
  (profil, pseudo, avatar, préférences, genres, plateformes, cache TMDB),
  erreurs typées `CineFailure` avec messages en français.

Tests : `test/cine_models_test.dart`, `test/supabase_service_test.dart`
(réponses HTTP Supabase simulées).
