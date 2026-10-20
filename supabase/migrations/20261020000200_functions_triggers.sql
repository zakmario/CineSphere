-- CinéSphère — migration 2/4 : fonctions et triggers.

begin;

-- updated_at automatique --------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists user_preferences_set_updated_at on public.user_preferences;
create trigger user_preferences_set_updated_at
  before update on public.user_preferences
  for each row execute function public.set_updated_at();

drop trigger if exists reviews_set_updated_at on public.reviews;
create trigger reviews_set_updated_at
  before update on public.reviews
  for each row execute function public.set_updated_at();

-- Rôle administrateur -----------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'admin'
  );
$$;

-- Un utilisateur ne peut pas s'attribuer le rôle admin. Les appels sans
-- utilisateur (SQL Editor, clé service_role) restent autorisés.
create or replace function public.protect_profile_role()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.role is distinct from old.role
     and (select auth.uid()) is not null
     and not public.is_admin() then
    raise exception 'Seul un administrateur peut modifier un rôle.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_protect_role on public.profiles;
create trigger profiles_protect_role
  before update of role on public.profiles
  for each row execute function public.protect_profile_role();

-- Pseudo unique dérivé d'une proposition (métadonnées d'inscription ou e-mail).
create or replace function public.unique_username(proposal text)
returns text
language plpgsql
stable
set search_path = ''
as $$
declare
  base text;
  candidate text;
  suffix int := 0;
begin
  base := left(regexp_replace(coalesce(proposal, ''), '[^a-zA-Z0-9_.-]', '', 'g'), 24);
  if base = '' then
    base := 'membre';
  end if;
  candidate := base;
  while exists (select 1 from public.profiles where lower(username) = lower(candidate)) loop
    suffix := suffix + 1;
    candidate := base || suffix::text;
  end loop;
  return candidate;
end;
$$;

-- Création automatique du profil et des préférences à l'inscription -------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, username, email)
  values (
    new.id,
    public.unique_username(
      coalesce(nullif(trim(new.raw_user_meta_data ->> 'username'), ''),
               split_part(new.email, '@', 1))),
    new.email
  )
  on conflict (id) do nothing;

  insert into public.user_preferences (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Comptes créés avant ce trigger : profil et préférences manquants.
insert into public.profiles (id, username, email)
select u.id, public.unique_username(split_part(u.email, '@', 1)), u.email
from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id);

insert into public.user_preferences (user_id)
select p.id from public.profiles p
on conflict (user_id) do nothing;

-- Mise en cache des contenus TMDB ----------------------------------------
-- Les tables du catalogue ne sont modifiables que par un admin (RLS). Ces
-- fonctions permettent à tout utilisateur connecté d'enregistrer un contenu
-- consulté (avant un favori, un avis...), avec des champs contrôlés.
create or replace function public.upsert_movie_from_tmdb(payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  movie_uuid uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentification requise.' using errcode = '42501';
  end if;
  if (payload ->> 'tmdb_id') is null or (payload ->> 'title') is null then
    raise exception 'tmdb_id et title sont obligatoires.' using errcode = '22023';
  end if;

  insert into public.movies as m
    (tmdb_id, title, description, poster_url, backdrop_url, release_date,
     duration, rating, trailer_url, status)
  values (
    (payload ->> 'tmdb_id')::int,
    payload ->> 'title',
    payload ->> 'description',
    payload ->> 'poster_url',
    payload ->> 'backdrop_url',
    (payload ->> 'release_date')::date,
    (payload ->> 'duration')::int,
    (payload ->> 'rating')::numeric(3, 1),
    payload ->> 'trailer_url',
    payload ->> 'status'
  )
  on conflict (tmdb_id) do update set
    title = excluded.title,
    description = coalesce(excluded.description, m.description),
    poster_url = coalesce(excluded.poster_url, m.poster_url),
    backdrop_url = coalesce(excluded.backdrop_url, m.backdrop_url),
    release_date = coalesce(excluded.release_date, m.release_date),
    duration = coalesce(excluded.duration, m.duration),
    rating = coalesce(excluded.rating, m.rating),
    trailer_url = coalesce(excluded.trailer_url, m.trailer_url),
    status = coalesce(excluded.status, m.status)
  returning m.id into movie_uuid;

  if payload ? 'genre_ids' then
    delete from public.movie_genres where movie_id = movie_uuid;
    insert into public.movie_genres (movie_id, genre_id)
    select movie_uuid, g.id
    from public.genres g
    where g.id in (select jsonb_array_elements_text(payload -> 'genre_ids')::int);
  end if;

  return movie_uuid;
end;
$$;

create or replace function public.upsert_series_from_tmdb(payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  series_uuid uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentification requise.' using errcode = '42501';
  end if;
  if (payload ->> 'tmdb_id') is null or (payload ->> 'title') is null then
    raise exception 'tmdb_id et title sont obligatoires.' using errcode = '22023';
  end if;

  insert into public.series as s
    (tmdb_id, title, description, poster_url, backdrop_url, first_air_date,
     number_of_seasons, number_of_episodes, rating, status)
  values (
    (payload ->> 'tmdb_id')::int,
    payload ->> 'title',
    payload ->> 'description',
    payload ->> 'poster_url',
    payload ->> 'backdrop_url',
    (payload ->> 'first_air_date')::date,
    (payload ->> 'number_of_seasons')::int,
    (payload ->> 'number_of_episodes')::int,
    (payload ->> 'rating')::numeric(3, 1),
    payload ->> 'status'
  )
  on conflict (tmdb_id) do update set
    title = excluded.title,
    description = coalesce(excluded.description, s.description),
    poster_url = coalesce(excluded.poster_url, s.poster_url),
    backdrop_url = coalesce(excluded.backdrop_url, s.backdrop_url),
    first_air_date = coalesce(excluded.first_air_date, s.first_air_date),
    number_of_seasons = coalesce(excluded.number_of_seasons, s.number_of_seasons),
    number_of_episodes = coalesce(excluded.number_of_episodes, s.number_of_episodes),
    rating = coalesce(excluded.rating, s.rating),
    status = coalesce(excluded.status, s.status)
  returning s.id into series_uuid;

  if payload ? 'genre_ids' then
    delete from public.series_genres where series_id = series_uuid;
    insert into public.series_genres (series_id, genre_id)
    select series_uuid, g.id
    from public.genres g
    where g.id in (select jsonb_array_elements_text(payload -> 'genre_ids')::int);
  end if;

  return series_uuid;
end;
$$;

revoke execute on function public.upsert_movie_from_tmdb(jsonb) from public, anon;
revoke execute on function public.upsert_series_from_tmdb(jsonb) from public, anon;
grant execute on function public.upsert_movie_from_tmdb(jsonb) to authenticated;
grant execute on function public.upsert_series_from_tmdb(jsonb) to authenticated;

-- Profils publics : uniquement les champs non sensibles (pas l'e-mail).
-- La vue s'exécute avec les droits de son propriétaire, ce qui contourne
-- volontairement la RLS de profiles pour ces seules colonnes.
create or replace view public.public_profiles as
  select id, username, avatar_url, bio, created_at
  from public.profiles;

revoke all on public.public_profiles from public;
grant select on public.public_profiles to anon, authenticated;

commit;
