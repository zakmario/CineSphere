-- CinéSphère — migration 5 : corrections des audits Supabase (advisors).
--
-- 1. security_definer_view : la vue public_profiles est remplacée par deux
--    fonctions qui n'exposent que les champs publics.
-- 2. Fonctions SECURITY DEFINER appelables par anon : droits retirés.
-- 3. multiple_permissive_policies : la politique admin « for all » est
--    découpée en insert / update / delete (la lecture a sa propre politique).
-- 4. Index manquant sur news.media_id.

begin;

-- 1. Profils publics ---------------------------------------------------------
drop view if exists public.public_profiles;

create or replace function public.get_public_profile(profile_id uuid)
returns table (id uuid, username text, avatar_url text, bio text, created_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.username, p.avatar_url, p.bio, p.created_at
  from public.profiles p
  where p.id = profile_id;
$$;

-- Vrai si le pseudo est libre (ou déjà le sien), insensible à la casse.
create or replace function public.username_available(candidate text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1 from public.profiles p
    where lower(p.username) = lower(trim(candidate))
      and p.id is distinct from (select auth.uid())
  );
$$;

revoke execute on function public.get_public_profile(uuid) from public, anon;
revoke execute on function public.username_available(text) from public, anon;
grant execute on function public.get_public_profile(uuid) to authenticated;
-- L'écran d'inscription vérifie le pseudo avant la création du compte.
grant execute on function public.username_available(text) to anon, authenticated;

-- 2. Droits d'exécution --------------------------------------------------------
-- Trigger uniquement : ne doit pas être appelable via /rest/v1/rpc.
revoke execute on function public.handle_new_user() from public, anon, authenticated;
-- Utilisée par les politiques RLS des utilisateurs connectés.
revoke execute on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;
revoke execute on function public.unique_username(text) from public, anon, authenticated;

-- 3. Politiques d'écriture admin sans SELECT -----------------------------------
do $$
declare
  t text;
begin
  foreach t in array array['genres', 'movies', 'series', 'movie_genres',
                           'series_genres', 'platforms', 'release_events'] loop
    execute format('drop policy if exists "%1$s admin write" on public.%1$I', t);
    execute format('drop policy if exists "%1$s admin insert" on public.%1$I', t);
    execute format('drop policy if exists "%1$s admin update" on public.%1$I', t);
    execute format('drop policy if exists "%1$s admin delete" on public.%1$I', t);
    execute format('create policy "%1$s admin insert" on public.%1$I for insert '
                   'to authenticated with check (public.is_admin())', t);
    execute format('create policy "%1$s admin update" on public.%1$I for update '
                   'to authenticated using (public.is_admin()) '
                   'with check (public.is_admin())', t);
    execute format('create policy "%1$s admin delete" on public.%1$I for delete '
                   'to authenticated using (public.is_admin())', t);
  end loop;
end $$;

-- 4. Index ----------------------------------------------------------------------
create index if not exists news_media_idx on public.news (media_id);

commit;
