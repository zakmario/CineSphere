-- CinéSphère — migration 1/4 : schéma (section 5.2 du cahier des charges).
--
-- Stratégie « expand / contract » : cette migration AJOUTE le nouveau schéma
-- sans casser les tables historiques de supabase/schema.sql (media, news,
-- favorites.media_id, release_events.media_id) encore utilisées par les
-- widgets des membres 2 et 3. Une migration ultérieure (« contract »)
-- supprimera ces colonnes quand plus aucun widget ne les lira.
--
-- Prérequis : supabase/schema.sql déjà exécuté. Script rejouable.

begin;

-- ---------------------------------------------------------------------------
-- Genres : les identifiants deviennent ceux de TMDB.
-- media.genres stocke des noms, aucune clé étrangère ne pointe sur genres.id.
-- ---------------------------------------------------------------------------
alter table public.genres alter column id drop default;
drop sequence if exists public.genres_id_seq;

update public.media
set genres = array_replace(genres, 'Science-fiction', 'Science-Fiction')
where 'Science-fiction' = any (genres);

update public.genres g
set id = m.tmdb_id, name = m.tmdb_name
from (values
  ('Action', 28, 'Action'), ('Aventure', 12, 'Aventure'),
  ('Animation', 16, 'Animation'), ('Comédie', 35, 'Comédie'),
  ('Crime', 80, 'Crime'), ('Drame', 18, 'Drame'),
  ('Fantastique', 14, 'Fantastique'), ('Horreur', 27, 'Horreur'),
  ('Science-fiction', 878, 'Science-Fiction'), ('Thriller', 53, 'Thriller'),
  ('Romance', 10749, 'Romance'), ('Documentaire', 99, 'Documentaire')
) as m(old_name, tmdb_id, tmdb_name)
where g.name = m.old_name and g.id <> m.tmdb_id;

-- ---------------------------------------------------------------------------
-- Profils
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists role text not null default 'user',
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_role_check') then
    alter table public.profiles
      add constraint profiles_role_check check (role in ('user', 'admin'));
  end if;
end $$;

-- Pseudos en double (insensible à la casse) : suffixe avant la contrainte.
update public.profiles p
set username = p.username || '_' || left(p.id::text, 4)
where exists (
  select 1 from public.profiles q
  where lower(q.username) = lower(p.username) and q.id < p.id
);
create unique index if not exists profiles_username_key
  on public.profiles (lower(username));

-- ---------------------------------------------------------------------------
-- Préférences utilisateur
-- ---------------------------------------------------------------------------
create table if not exists public.user_preferences (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  favorite_genres int[] not null default '{}',
  favorite_platforms text[] not null default '{}',
  content_types text[] not null default '{movie,series}'
    check (content_types <@ array['movie', 'series']),
  notifications_enabled boolean not null default true,
  notify_releases boolean not null default true,
  notify_favorite_series boolean not null default true,
  reminder_time time not null default '18:00',
  theme_mode text not null default 'dark'
    check (theme_mode in ('system', 'light', 'dark')),
  onboarding_completed boolean not null default false,
  updated_at timestamptz not null default now()
);

-- Reprise des préférences stockées jusqu'ici dans profiles.
insert into public.user_preferences
  (user_id, favorite_genres, favorite_platforms, onboarding_completed)
select p.id,
       array(select g.id from public.genres g where g.name = any (p.favorite_genres)),
       p.favorite_platforms,
       p.onboarding_done
from public.profiles p
on conflict (user_id) do nothing;

-- ---------------------------------------------------------------------------
-- Catalogue (copie légère des contenus TMDB utilisés)
-- ---------------------------------------------------------------------------
create table if not exists public.movies (
  id uuid primary key default gen_random_uuid(),
  tmdb_id int not null unique,
  title text not null,
  description text,
  poster_url text,
  backdrop_url text,
  release_date date,
  duration int check (duration is null or duration >= 0),
  rating numeric(3, 1) check (rating is null or rating between 0 and 10),
  trailer_url text,
  status text check (status in ('upcoming', 'released', 'canceled')),
  created_at timestamptz not null default now()
);

create table if not exists public.series (
  id uuid primary key default gen_random_uuid(),
  tmdb_id int not null unique,
  title text not null,
  description text,
  poster_url text,
  backdrop_url text,
  first_air_date date,
  number_of_seasons int check (number_of_seasons is null or number_of_seasons >= 0),
  number_of_episodes int check (number_of_episodes is null or number_of_episodes >= 0),
  rating numeric(3, 1) check (rating is null or rating between 0 and 10),
  status text check (status in ('upcoming', 'ongoing', 'ended', 'canceled')),
  created_at timestamptz not null default now()
);

create table if not exists public.movie_genres (
  movie_id uuid not null references public.movies (id) on delete cascade,
  genre_id int not null references public.genres (id) on delete cascade,
  primary key (movie_id, genre_id)
);

create table if not exists public.series_genres (
  series_id uuid not null references public.series (id) on delete cascade,
  genre_id int not null references public.genres (id) on delete cascade,
  primary key (series_id, genre_id)
);

-- id = identifiant du fournisseur TMDB (0 = sortie en salle).
create table if not exists public.platforms (
  id int primary key,
  name text not null unique,
  logo_url text
);

-- ---------------------------------------------------------------------------
-- Favoris : la table historique (user_id, media_id) est étendue.
-- ---------------------------------------------------------------------------
alter table public.favorites
  add column if not exists id uuid not null default gen_random_uuid(),
  add column if not exists movie_id uuid references public.movies (id) on delete cascade,
  add column if not exists series_id uuid references public.series (id) on delete cascade;
alter table public.favorites alter column media_id drop not null;

do $$
begin
  if exists (
    select 1 from pg_constraint
    where conname = 'favorites_pkey'
      and pg_get_constraintdef(oid) <> 'PRIMARY KEY (id)'
  ) then
    alter table public.favorites drop constraint favorites_pkey;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'favorites_pkey') then
    alter table public.favorites add constraint favorites_pkey primary key (id);
  end if;
  -- Transition : media_id compte encore comme cible tant que la table media existe.
  if not exists (select 1 from pg_constraint where conname = 'favorites_one_target') then
    alter table public.favorites add constraint favorites_one_target
      check (num_nonnulls(media_id, movie_id, series_id) = 1);
  end if;
end $$;

create unique index if not exists favorites_user_media_key
  on public.favorites (user_id, media_id) where media_id is not null;
create unique index if not exists favorites_user_movie_key
  on public.favorites (user_id, movie_id) where movie_id is not null;
create unique index if not exists favorites_user_series_key
  on public.favorites (user_id, series_id) where series_id is not null;

-- ---------------------------------------------------------------------------
-- Listes personnalisées
-- ---------------------------------------------------------------------------
create table if not exists public.watchlists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 60),
  description text,
  is_public boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.watchlist_items (
  id uuid primary key default gen_random_uuid(),
  watchlist_id uuid not null references public.watchlists (id) on delete cascade,
  movie_id uuid references public.movies (id) on delete cascade,
  series_id uuid references public.series (id) on delete cascade,
  added_at timestamptz not null default now(),
  constraint watchlist_items_one_target check (num_nonnulls(movie_id, series_id) = 1)
);
create unique index if not exists watchlist_items_movie_key
  on public.watchlist_items (watchlist_id, movie_id) where movie_id is not null;
create unique index if not exists watchlist_items_series_key
  on public.watchlist_items (watchlist_id, series_id) where series_id is not null;

-- ---------------------------------------------------------------------------
-- Contenus vus (episode_id = identifiant d'épisode TMDB)
-- ---------------------------------------------------------------------------
create table if not exists public.watched (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  movie_id uuid references public.movies (id) on delete cascade,
  series_id uuid references public.series (id) on delete cascade,
  episode_id int,
  watched_at timestamptz not null default now(),
  constraint watched_one_target check (num_nonnulls(movie_id, series_id) = 1),
  constraint watched_episode_needs_series check (episode_id is null or series_id is not null)
);
create unique index if not exists watched_user_movie_key
  on public.watched (user_id, movie_id) where movie_id is not null;
create unique index if not exists watched_user_episode_key
  on public.watched (user_id, series_id, coalesce(episode_id, -1)) where series_id is not null;

-- ---------------------------------------------------------------------------
-- Avis
-- ---------------------------------------------------------------------------
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  movie_id uuid references public.movies (id) on delete cascade,
  series_id uuid references public.series (id) on delete cascade,
  rating int not null check (rating between 1 and 10),
  content text check (content is null or char_length(content) <= 5000),
  is_private boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint reviews_one_target check (num_nonnulls(movie_id, series_id) = 1)
);
create unique index if not exists reviews_user_movie_key
  on public.reviews (user_id, movie_id) where movie_id is not null;
create unique index if not exists reviews_user_series_key
  on public.reviews (user_id, series_id) where series_id is not null;

create table if not exists public.review_likes (
  review_id uuid not null references public.reviews (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  primary key (review_id, user_id)
);

-- ---------------------------------------------------------------------------
-- Sorties : la table historique (media_id, release_at) est étendue.
-- ---------------------------------------------------------------------------
alter table public.release_events
  add column if not exists movie_id uuid references public.movies (id) on delete cascade,
  add column if not exists series_id uuid references public.series (id) on delete cascade,
  add column if not exists season_number int check (season_number is null or season_number >= 0),
  add column if not exists episode_number int check (episode_number is null or episode_number >= 0),
  add column if not exists release_date date
    generated always as ((release_at at time zone 'UTC')::date) stored;
alter table public.release_events alter column media_id drop not null;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'release_events_one_target') then
    alter table public.release_events add constraint release_events_one_target
      check (num_nonnulls(media_id, movie_id, series_id) = 1);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Notifications et historique de recherche
-- ---------------------------------------------------------------------------
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  message text not null,
  release_event_id uuid references public.release_events (id) on delete set null,
  scheduled_at timestamptz,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.search_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  query text not null check (char_length(trim(query)) between 1 and 200),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Index sur les clés étrangères et les tris fréquents
-- ---------------------------------------------------------------------------
create index if not exists movie_genres_genre_idx on public.movie_genres (genre_id);
create index if not exists series_genres_genre_idx on public.series_genres (genre_id);
create index if not exists favorites_user_created_idx on public.favorites (user_id, created_at desc);
create index if not exists favorites_movie_idx on public.favorites (movie_id);
create index if not exists favorites_series_idx on public.favorites (series_id);
create index if not exists favorites_media_idx on public.favorites (media_id);
create index if not exists watchlists_user_idx on public.watchlists (user_id);
create index if not exists watchlist_items_watchlist_idx on public.watchlist_items (watchlist_id, added_at desc);
create index if not exists watchlist_items_movie_idx on public.watchlist_items (movie_id);
create index if not exists watchlist_items_series_idx on public.watchlist_items (series_id);
create index if not exists watched_user_idx on public.watched (user_id, watched_at desc);
create index if not exists watched_movie_idx on public.watched (movie_id);
create index if not exists watched_series_idx on public.watched (series_id);
create index if not exists reviews_movie_idx on public.reviews (movie_id, created_at desc);
create index if not exists reviews_series_idx on public.reviews (series_id, created_at desc);
create index if not exists reviews_user_idx on public.reviews (user_id);
create index if not exists review_likes_user_idx on public.review_likes (user_id);
create index if not exists release_events_media_idx on public.release_events (media_id);
create index if not exists release_events_movie_idx on public.release_events (movie_id);
create index if not exists release_events_series_idx on public.release_events (series_id);
create index if not exists release_events_date_idx on public.release_events (release_date, id);
create index if not exists notifications_user_idx on public.notifications (user_id, created_at desc);
create index if not exists notifications_unread_idx on public.notifications (user_id) where not is_read;
create index if not exists notifications_event_idx on public.notifications (release_event_id);
create index if not exists search_history_user_idx on public.search_history (user_id, created_at desc);
create index if not exists movies_release_idx on public.movies (release_date desc);
create index if not exists series_first_air_idx on public.series (first_air_date desc);

commit;
