-- =====================================================================
-- CineSphere — schéma Supabase
-- À exécuter dans Supabase > SQL Editor (le script peut être relancé).
-- Ensuite, dans FlutterFlow : Settings > Supabase > "Get Schema".
-- =====================================================================

-- ---------------------------------------------------------------------
-- Profils (la table existe déjà : on ajoute les colonnes du walkthrough)
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null,
  email text,
  avatar_url text,
  bio text,
  created_at timestamptz default now()
);

alter table public.profiles
  add column if not exists favorite_genres text[] not null default '{}',
  add column if not exists favorite_platforms text[] not null default '{}',
  add column if not exists onboarding_done boolean not null default false;

-- ---------------------------------------------------------------------
-- Catalogue : une seule table pour les films ET les séries.
-- Une table unique permet une seule recherche / un seul filtre / une seule
-- pagination au lieu de fusionner deux listes côté application.
-- ---------------------------------------------------------------------
create table if not exists public.genres (
  id serial primary key,
  name text not null unique
);

create table if not exists public.media (
  id uuid primary key default gen_random_uuid(),
  media_type text not null check (media_type in ('movie', 'series')),
  title text not null,
  overview text,
  poster_url text,
  backdrop_url text,
  release_date date,
  runtime_minutes int,          -- films
  seasons int,                  -- séries
  episodes int,                 -- séries
  status text not null default 'released'
    check (status in ('released', 'ongoing', 'upcoming', 'ended')),
  rating numeric(3, 1) not null default 0 check (rating between 0 and 10),
  popularity int not null default 0,
  genres text[] not null default '{}',
  platforms text[] not null default '{}',
  trailer_url text,
  created_at timestamptz not null default now()
);

create index if not exists media_title_idx on public.media using gin (to_tsvector('simple', title));
create index if not exists media_genres_idx on public.media using gin (genres);
create index if not exists media_popularity_idx on public.media (popularity desc, id);
create index if not exists media_release_idx on public.media (release_date desc, id);

-- Dates de diffusion (sorties de films, épisodes de séries)
create table if not exists public.release_events (
  id uuid primary key default gen_random_uuid(),
  media_id uuid not null references public.media (id) on delete cascade,
  title text not null,                 -- ex. "S2E05 – Le retour"
  release_at timestamptz not null,
  platform text,
  description text
);
create index if not exists release_events_at_idx on public.release_events (release_at, id);

-- Actualités
create table if not exists public.news (
  id uuid primary key default gen_random_uuid(),
  media_id uuid references public.media (id) on delete set null,
  title text not null,
  summary text,
  image_url text,
  published_at timestamptz not null default now()
);

-- Favoris (un utilisateur ne peut mettre qu'une fois un contenu en favori)
create table if not exists public.favorites (
  user_id uuid not null references auth.users (id) on delete cascade,
  media_id uuid not null references public.media (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, media_id)
);

-- ---------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.genres enable row level security;
alter table public.media enable row level security;
alter table public.release_events enable row level security;
alter table public.news enable row level security;
alter table public.favorites enable row level security;

-- Catalogue : lecture publique, écriture réservée au dashboard Supabase.
drop policy if exists "catalog readable" on public.genres;
create policy "catalog readable" on public.genres for select to anon, authenticated using (true);
drop policy if exists "catalog readable" on public.media;
create policy "catalog readable" on public.media for select to anon, authenticated using (true);
drop policy if exists "catalog readable" on public.release_events;
create policy "catalog readable" on public.release_events for select to anon, authenticated using (true);
drop policy if exists "catalog readable" on public.news;
create policy "catalog readable" on public.news for select to anon, authenticated using (true);

-- Profils : chacun gère le sien.
drop policy if exists "members can read their profile" on public.profiles;
create policy "members can read their profile" on public.profiles
  for select to authenticated using (auth.uid() = id);
drop policy if exists "members can create their profile" on public.profiles;
create policy "members can create their profile" on public.profiles
  for insert to authenticated with check (auth.uid() = id);
drop policy if exists "members can update their profile" on public.profiles;
create policy "members can update their profile" on public.profiles
  for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

-- Favoris : chacun ne voit / modifie que les siens.
drop policy if exists "own favorites select" on public.favorites;
create policy "own favorites select" on public.favorites
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists "own favorites insert" on public.favorites;
create policy "own favorites insert" on public.favorites
  for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "own favorites delete" on public.favorites;
create policy "own favorites delete" on public.favorites
  for delete to authenticated using (auth.uid() = user_id);

-- =====================================================================
-- Données de démonstration (assez de lignes pour tester la pagination)
-- =====================================================================
insert into public.genres (name) values
  ('Action'), ('Aventure'), ('Animation'), ('Comédie'), ('Crime'), ('Drame'),
  ('Fantastique'), ('Horreur'), ('Science-fiction'), ('Thriller'), ('Romance'),
  ('Documentaire')
on conflict (name) do nothing;

insert into public.media
  (media_type, title, overview, poster_url, backdrop_url, release_date, runtime_minutes,
   seasons, episodes, status, rating, popularity, genres, platforms)
select v.media_type, v.title, v.overview,
       'https://picsum.photos/seed/' || md5(v.title) || '/400/600',
       'https://picsum.photos/seed/' || md5(v.title) || 'b/1280/720',
       v.release_date, v.runtime_minutes, v.seasons, v.episodes, v.status,
       v.rating, v.popularity, v.genres, v.platforms
from (values
  ('movie', 'Inception', 'Un voleur infiltre les rêves pour y implanter une idée.', date '2010-07-16', 148, null::int, null::int, 'released', 8.8, 980, array['Science-fiction','Action','Thriller'], array['Netflix']),
  ('movie', 'Interstellar', 'Des explorateurs traversent un trou de ver pour sauver l''humanité.', date '2014-11-05', 169, null, null, 'released', 8.7, 960, array['Science-fiction','Drame','Aventure'], array['Prime Video']),
  ('movie', 'Parasite', 'Une famille pauvre s''infiltre chez une famille riche.', date '2019-06-05', 132, null, null, 'released', 8.5, 870, array['Thriller','Drame','Comédie'], array['Canal+']),
  ('movie', 'Le Fabuleux Destin d''Amélie Poulain', 'Une jeune serveuse décide de changer la vie des gens qui l''entourent.', date '2001-04-25', 122, null, null, 'released', 8.3, 640, array['Comédie','Romance'], array['Netflix']),
  ('movie', 'Spider-Man : Across the Spider-Verse', 'Miles Morales voyage à travers le multivers.', date '2023-05-31', 140, null, null, 'released', 8.6, 900, array['Animation','Action','Aventure'], array['Netflix']),
  ('movie', 'Dune : Deuxième Partie', 'Paul Atréides s''allie aux Fremen.', date '2024-02-28', 166, null, null, 'released', 8.5, 940, array['Science-fiction','Aventure'], array['Max','Prime Video']),
  ('movie', 'Oppenheimer', 'L''histoire du père de la bombe atomique.', date '2023-07-19', 180, null, null, 'released', 8.4, 920, array['Drame'], array['Prime Video']),
  ('movie', 'Le Voyage de Chihiro', 'Une fillette se retrouve dans le monde des esprits.', date '2001-07-20', 125, null, null, 'released', 8.6, 850, array['Animation','Fantastique','Aventure'], array['Netflix']),
  ('movie', 'Joker', 'La naissance d''un des plus célèbres méchants de Gotham.', date '2019-10-09', 122, null, null, 'released', 8.4, 830, array['Crime','Drame','Thriller'], array['Max']),
  ('movie', 'Intouchables', 'Un aristocrate tétraplégique engage un auxiliaire de vie atypique.', date '2011-11-02', 112, null, null, 'released', 8.5, 760, array['Comédie','Drame'], array['Netflix','Canal+']),
  ('movie', 'Get Out', 'Un week-end chez la belle-famille vire au cauchemar.', date '2017-05-03', 104, null, null, 'released', 7.7, 610, array['Horreur','Thriller'], array['Prime Video']),
  ('movie', 'Mad Max : Fury Road', 'Une course-poursuite dans un désert post-apocalyptique.', date '2015-05-14', 120, null, null, 'released', 8.1, 780, array['Action','Aventure','Science-fiction'], array['Max']),
  ('movie', 'La La Land', 'Un pianiste et une actrice tombent amoureux à Los Angeles.', date '2017-01-25', 128, null, null, 'released', 8.0, 700, array['Romance','Comédie','Drame'], array['Netflix']),
  ('movie', 'Everything Everywhere All at Once', 'Une blanchisseuse découvre le multivers.', date '2022-08-31', 139, null, null, 'released', 7.8, 720, array['Science-fiction','Comédie','Action'], array['Prime Video']),
  ('movie', 'Le Seigneur des Anneaux : La Communauté de l''Anneau', 'Frodon part détruire l''Anneau unique.', date '2001-12-19', 178, null, null, 'released', 8.9, 950, array['Fantastique','Aventure'], array['Prime Video','Max']),
  ('movie', 'Avatar 3 : De feu et de cendres', 'Le retour sur Pandora.', current_date + 45, 190, null, null, 'upcoming', 0, 890, array['Science-fiction','Aventure'], array['Cinéma']),
  ('movie', 'The Batman Part II', 'Bruce Wayne affronte une nouvelle menace à Gotham.', current_date + 120, 170, null, null, 'upcoming', 0, 860, array['Action','Crime'], array['Cinéma']),
  ('movie', 'Shrek 5', 'L''ogre le plus célèbre revient.', current_date + 200, 95, null, null, 'upcoming', 0, 700, array['Animation','Comédie'], array['Cinéma']),
  ('series', 'Breaking Bad', 'Un professeur de chimie devient fabricant de méthamphétamine.', date '2008-01-20', null, 5, 62, 'ended', 9.5, 990, array['Crime','Drame','Thriller'], array['Netflix']),
  ('series', 'Game of Thrones', 'Des familles nobles se disputent le Trône de fer.', date '2011-04-17', null, 8, 73, 'ended', 9.2, 970, array['Fantastique','Drame','Aventure'], array['Max']),
  ('series', 'Stranger Things', 'Des enfants affrontent des forces surnaturelles à Hawkins.', date '2016-07-15', null, 5, 42, 'ended', 8.7, 950, array['Science-fiction','Horreur','Drame'], array['Netflix']),
  ('series', 'The Last of Us', 'Joel escorte Ellie à travers des États-Unis dévastés.', date '2023-01-15', null, 2, 16, 'ongoing', 8.8, 930, array['Drame','Action','Horreur'], array['Max']),
  ('series', 'Arcane', 'Deux sœurs divisées par le conflit entre Piltover et Zaun.', date '2021-11-06', null, 2, 18, 'ended', 9.0, 910, array['Animation','Action','Fantastique'], array['Netflix']),
  ('series', 'Lupin', 'Assane Diop s''inspire d''Arsène Lupin pour venger son père.', date '2021-01-08', null, 4, 22, 'ongoing', 7.5, 800, array['Crime','Thriller'], array['Netflix']),
  ('series', 'The Bear', 'Un chef étoilé reprend la sandwicherie familiale.', date '2022-06-23', null, 4, 38, 'ongoing', 8.6, 820, array['Comédie','Drame'], array['Disney+']),
  ('series', 'Severance', 'Des employés dont les souvenirs sont séparés entre travail et vie privée.', date '2022-02-18', null, 2, 19, 'ongoing', 8.7, 880, array['Science-fiction','Thriller','Drame'], array['Apple TV+']),
  ('series', 'Le Bureau des Légendes', 'Le quotidien des agents clandestins de la DGSE.', date '2015-04-27', null, 5, 50, 'ended', 8.6, 690, array['Thriller','Drame'], array['Canal+']),
  ('series', 'Wednesday', 'Mercredi Addams enquête à l''académie Nevermore.', date '2022-11-23', null, 2, 16, 'ongoing', 8.0, 860, array['Comédie','Fantastique','Horreur'], array['Netflix']),
  ('series', 'Shōgun', 'Un navigateur anglais échoue dans le Japon féodal.', date '2024-02-27', null, 1, 10, 'ongoing', 8.7, 840, array['Drame','Aventure'], array['Disney+']),
  ('series', 'The Mandalorian', 'Un chasseur de primes protège un mystérieux enfant.', date '2019-11-12', null, 3, 24, 'ongoing', 8.7, 870, array['Science-fiction','Action','Aventure'], array['Disney+']),
  ('series', 'Dark', 'Des disparitions révèlent les secrets de quatre familles.', date '2017-12-01', null, 3, 26, 'ended', 8.7, 780, array['Science-fiction','Thriller','Drame'], array['Netflix']),
  ('series', 'Fallout', 'Une habitante d''abri découvre le monde post-nucléaire.', date '2024-04-10', null, 2, 16, 'ongoing', 8.3, 850, array['Science-fiction','Action','Comédie'], array['Prime Video']),
  ('series', 'House of the Dragon : Saison 3', 'La guerre des Targaryen continue.', current_date + 30, null, 3, 26, 'upcoming', 0, 900, array['Fantastique','Drame'], array['Max']),
  ('series', 'One Piece : Saison 2', 'Luffy et son équipage reprennent la mer.', current_date + 10, null, 2, 16, 'upcoming', 0, 880, array['Aventure','Action','Comédie'], array['Netflix'])
) as v(media_type, title, overview, release_date, runtime_minutes, seasons, episodes, status, rating, popularity, genres, platforms)
where not exists (select 1 from public.media m where m.title = v.title);

-- Dates de diffusion relatives à aujourd'hui : le calendrier a toujours du contenu.
insert into public.release_events (media_id, title, release_at, platform, description)
select m.id, e.title, now() + e.offset_interval, e.platform, e.description
from (values
  ('One Piece : Saison 2', 'Saison 2 – Épisodes 1 à 8', interval '10 days', 'Netflix', 'Toute la première partie de la saison.'),
  ('House of the Dragon : Saison 3', 'S3E01', interval '30 days', 'Max', 'Premier épisode de la saison 3.'),
  ('House of the Dragon : Saison 3', 'S3E02', interval '37 days', 'Max', null),
  ('Avatar 3 : De feu et de cendres', 'Sortie en salles', interval '45 days', 'Cinéma', null),
  ('The Batman Part II', 'Sortie en salles', interval '120 days', 'Cinéma', null),
  ('Shrek 5', 'Sortie en salles', interval '200 days', 'Cinéma', null),
  ('The Last of Us', 'S3E01', interval '3 days', 'Max', 'Retour de la série.'),
  ('Severance', 'S3E01', interval '1 day', 'Apple TV+', null),
  ('Fallout', 'S2E05', interval '6 hours', 'Prime Video', null),
  ('The Bear', 'S5 – Tous les épisodes', interval '14 days', 'Disney+', null),
  ('Lupin', 'S4E01', interval '21 days', 'Netflix', null),
  ('Wednesday', 'S3E01', interval '60 days', 'Netflix', null)
) as e(media_title, title, offset_interval, platform, description)
join public.media m on m.title = e.media_title
where not exists (
  select 1 from public.release_events r where r.media_id = m.id and r.title = e.title
);

insert into public.news (media_id, title, summary, image_url, published_at)
select m.id, n.title, n.summary,
       'https://picsum.photos/seed/' || md5(n.title) || '/800/450',
       now() - n.age
from (values
  ('House of the Dragon : Saison 3', 'House of the Dragon : une date pour la saison 3', 'La plateforme confirme le retour de la série dans un mois.', interval '2 hours'),
  ('Avatar 3 : De feu et de cendres', 'Avatar 3 dévoile sa bande-annonce finale', 'Le nouveau clan des Na''vi se montre enfin.', interval '1 day'),
  ('One Piece : Saison 2', 'One Piece : le casting de la saison 2 complété', 'Plusieurs nouveaux pirates rejoignent la distribution.', interval '3 days'),
  ('Severance', 'Severance renouvelée pour une saison 3', 'Le tournage a commencé.', interval '5 days')
) as n(media_title, title, summary, age)
join public.media m on m.title = n.media_title
where not exists (select 1 from public.news x where x.title = n.title);
