-- Import du catalogue TMDB dans la table media (membre 1).
--
-- Les widgets du catalogue (HomeFeed, CatalogBrowser, MediaDetailView) lisent
-- la table media. L'application récupère les listes TMDB (groupe d'appels
-- « TMDB » de FlutterFlow) et les envoie à import_tmdb_media, qui crée ou met
-- à jour les titres : favoris, listes et vus continuent de viser media.id.

begin;

alter table public.media add column if not exists tmdb_id int
  check (tmdb_id is null or tmdb_id > 0);
create unique index if not exists media_tmdb_key
  on public.media (media_type, tmdb_id) where tmdb_id is not null;

-- Identifiants TMDB des 34 titres de démonstration (correspondance faite pour
-- la migration 20261021000100) : l'import les met à jour au lieu de les dupliquer.
update public.media m set tmdb_id = v.tmdb_id
from (values
  ('b55faa3d-4d10-4aca-9934-25d21a97b3a4'::uuid, 94605), -- Arcane
  ('62917769-4c15-4e0c-a177-fd9ad600bd02'::uuid, 83533), -- Avatar 3 : De feu et de cendres
  ('6a07fb43-6188-457e-8db4-718e5847f8c5'::uuid, 1396), -- Breaking Bad
  ('037a4563-5167-40df-9701-8b1a8e25f60a'::uuid, 70523), -- Dark
  ('a066da98-5a93-4fd1-b167-463807982fa8'::uuid, 693134), -- Dune : Deuxième Partie
  ('a57d722d-8add-4407-9aa7-009192afad43'::uuid, 545611), -- Everything Everywhere All at Once
  ('abb5b67d-a0f4-4ce9-a33b-0314c7543959'::uuid, 106379), -- Fallout
  ('2b5b8e27-371b-462f-947b-c20ef5d700c3'::uuid, 1399), -- Game of Thrones
  ('7dc21079-0865-42b2-b7ab-59ce6155cc8d'::uuid, 419430), -- Get Out
  ('061e816e-f19e-42d6-89f1-80be9f9f4f9f'::uuid, 94997), -- House of the Dragon : Saison 3
  ('d31f240b-a29c-44f3-b2c6-107a7a3734c3'::uuid, 27205), -- Inception
  ('179843e5-c4cc-4076-9133-4da2297ac5d8'::uuid, 157336), -- Interstellar
  ('780c3ad5-b337-44ec-9775-1f789221e316'::uuid, 77338), -- Intouchables
  ('48e35e91-2a63-419a-8471-423c4baf05c4'::uuid, 475557), -- Joker
  ('db502d4c-fcfe-4db5-a2e9-95c76a751737'::uuid, 313369), -- La La Land
  ('4636d93b-9c62-4624-8860-c867b9fe888d'::uuid, 62476), -- Le Bureau des Légendes
  ('224e8092-b7f3-4824-bdb8-031c9c89fc9e'::uuid, 194), -- Le Fabuleux Destin d'Amélie Poulain
  ('899be626-c240-4b8e-bffb-03690708a41e'::uuid, 120), -- Le Seigneur des Anneaux : La Communauté de l'Anneau
  ('b2e69f14-e712-4753-a788-309bfad0b74c'::uuid, 129), -- Le Voyage de Chihiro
  ('2963ce34-9a79-47ae-a513-563d07650f71'::uuid, 96677), -- Lupin
  ('5110043f-0527-424b-9438-e91e37b459b9'::uuid, 76341), -- Mad Max : Fury Road
  ('c4110240-ebb7-424d-9178-7049794fa5e9'::uuid, 111110), -- One Piece : Saison 2
  ('43832fe1-8a38-4449-a078-9ae48812ed1e'::uuid, 872585), -- Oppenheimer
  ('0d47c684-5f37-40dc-a7fc-0e5476c3a1a5'::uuid, 496243), -- Parasite
  ('ae5235ed-4085-4110-9cc7-11dd9e9c1f33'::uuid, 95396), -- Severance
  ('c72b5e00-91a0-439d-a2ba-4ed32ffbac09'::uuid, 421892), -- Shrek 5
  ('a48d76e2-c006-4f3f-85cd-de2c45f96097'::uuid, 126308), -- Shōgun
  ('b979eede-b955-4a8c-87d6-05557f312df2'::uuid, 569094), -- Spider-Man : Across the Spider-Verse
  ('aa9a9b4b-e60c-4962-af34-4e0927ba1c23'::uuid, 66732), -- Stranger Things
  ('6d669c61-f936-489c-8d0d-c4fdfeca7e6c'::uuid, 806704), -- The Batman Part II
  ('ae5073c6-c84d-4d76-9808-cf5caf8ff306'::uuid, 136315), -- The Bear
  ('71e80217-5699-4931-a54f-5576180c14a5'::uuid, 100088), -- The Last of Us
  ('374217fd-8bfd-463e-a3ad-4c385d088449'::uuid, 82856), -- The Mandalorian
  ('d7a7e59d-328f-4182-b173-598a36e7370c'::uuid, 119051) -- Wednesday
) as v(id, tmdb_id)
where m.id = v.id and m.tmdb_id is null;

-- items : tableau JSON (200 titres au plus) de
--   {media_type: movie|series, tmdb_id, title, overview, poster_url,
--    backdrop_url, release_date, rating, popularity, genre_ids: [int]}
-- Retourne le nombre de titres créés ou mis à jour. Un film à venir reçoit
-- aussi un événement « Sortie au cinéma » dans release_events (calendrier).
create or replace function public.import_tmdb_media(items jsonb)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  item jsonb;
  kind text;
  day date;
  media_uuid uuid;
  imported int := 0;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentification requise.' using errcode = '42501';
  end if;
  if jsonb_typeof(items) is distinct from 'array' or jsonb_array_length(items) > 200 then
    raise exception 'items doit être un tableau de 200 titres au plus.' using errcode = '22023';
  end if;

  for item in select value from jsonb_array_elements(items) loop
    kind := item ->> 'media_type';
    if kind is null or kind not in ('movie', 'series')
       or (item ->> 'tmdb_id') is null or coalesce(trim(item ->> 'title'), '') = '' then
      continue;
    end if;
    day := nullif(item ->> 'release_date', '')::date;

    insert into public.media as m
      (media_type, tmdb_id, title, overview, poster_url, backdrop_url,
       release_date, status, rating, popularity, genres)
    values (
      kind,
      (item ->> 'tmdb_id')::int,
      left(trim(item ->> 'title'), 300),
      nullif(trim(item ->> 'overview'), ''),
      nullif(item ->> 'poster_url', ''),
      nullif(item ->> 'backdrop_url', ''),
      day,
      case when day > current_date then 'upcoming'
           when kind = 'series' then 'ongoing'
           else 'released' end,
      least(greatest(coalesce((item ->> 'rating')::numeric, 0), 0), 10)::numeric(3, 1),
      greatest(round(coalesce((item ->> 'popularity')::numeric, 0)), 0)::int,
      array(select g.name from public.genres g
            where g.id in (select jsonb_array_elements_text(
                             coalesce(item -> 'genre_ids', '[]'::jsonb))::int)
            order by g.name)
    )
    on conflict (media_type, tmdb_id) where tmdb_id is not null do update set
      title = excluded.title,
      overview = coalesce(excluded.overview, m.overview),
      poster_url = coalesce(excluded.poster_url, m.poster_url),
      backdrop_url = coalesce(excluded.backdrop_url, m.backdrop_url),
      release_date = coalesce(excluded.release_date, m.release_date),
      status = case when m.status = 'ended' then m.status else excluded.status end,
      rating = excluded.rating,
      popularity = excluded.popularity,
      genres = case when cardinality(excluded.genres) > 0 then excluded.genres
                    else m.genres end
    returning m.id into media_uuid;

    if kind = 'movie' and day > current_date then
      insert into public.release_events (media_id, title, release_at, platform)
      select media_uuid, 'Sortie au cinéma', day::timestamptz, 'Cinéma'
      where not exists (select 1 from public.release_events e
                        where e.media_id = media_uuid and e.release_date = day);
    end if;
    imported := imported + 1;
  end loop;

  return imported;
end;
$$;

revoke execute on function public.import_tmdb_media(jsonb) from public, anon;
grant execute on function public.import_tmdb_media(jsonb) to authenticated;

commit;
