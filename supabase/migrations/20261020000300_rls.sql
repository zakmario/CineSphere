-- CinéSphère — migration 3/4 : Row Level Security sur toutes les tables.
-- `(select auth.uid())` est évalué une seule fois par requête (performances).

begin;

alter table public.profiles enable row level security;
alter table public.user_preferences enable row level security;
alter table public.genres enable row level security;
alter table public.movies enable row level security;
alter table public.series enable row level security;
alter table public.movie_genres enable row level security;
alter table public.series_genres enable row level security;
alter table public.platforms enable row level security;
alter table public.favorites enable row level security;
alter table public.watchlists enable row level security;
alter table public.watchlist_items enable row level security;
alter table public.watched enable row level security;
alter table public.reviews enable row level security;
alter table public.review_likes enable row level security;
alter table public.release_events enable row level security;
alter table public.notifications enable row level security;
alter table public.search_history enable row level security;

-- Profils : le propriétaire lit et modifie sa ligne. La lecture publique
-- passe par la vue public_profiles (sans l'e-mail). -----------------------
drop policy if exists "members can read their profile" on public.profiles;
drop policy if exists "members can create their profile" on public.profiles;
drop policy if exists "members can update their profile" on public.profiles;
drop policy if exists "profiles owner select" on public.profiles;
drop policy if exists "profiles owner insert" on public.profiles;
drop policy if exists "profiles owner update" on public.profiles;

create policy "profiles owner select" on public.profiles
  for select to authenticated using ((select auth.uid()) = id or public.is_admin());
create policy "profiles owner insert" on public.profiles
  for insert to authenticated with check ((select auth.uid()) = id);
create policy "profiles owner update" on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id or public.is_admin())
  with check ((select auth.uid()) = id or public.is_admin());

-- Tables strictement privées : CRUD si auth.uid() = user_id ------------------
do $$
declare
  t text;
begin
  foreach t in array array['user_preferences', 'favorites', 'watched',
                           'notifications', 'search_history'] loop
    execute format('drop policy if exists "%1$s owner select" on public.%1$I', t);
    execute format('drop policy if exists "%1$s owner insert" on public.%1$I', t);
    execute format('drop policy if exists "%1$s owner update" on public.%1$I', t);
    execute format('drop policy if exists "%1$s owner delete" on public.%1$I', t);
    execute format('create policy "%1$s owner select" on public.%1$I for select '
                   'to authenticated using ((select auth.uid()) = user_id)', t);
    execute format('create policy "%1$s owner insert" on public.%1$I for insert '
                   'to authenticated with check ((select auth.uid()) = user_id)', t);
    execute format('create policy "%1$s owner update" on public.%1$I for update '
                   'to authenticated using ((select auth.uid()) = user_id) '
                   'with check ((select auth.uid()) = user_id)', t);
    execute format('create policy "%1$s owner delete" on public.%1$I for delete '
                   'to authenticated using ((select auth.uid()) = user_id)', t);
  end loop;
end $$;

-- Anciennes politiques de favorites (schema.sql), remplacées ci-dessus.
drop policy if exists "own favorites select" on public.favorites;
drop policy if exists "own favorites insert" on public.favorites;
drop policy if exists "own favorites delete" on public.favorites;

-- Listes : propriétaire en écriture, lecture publique si is_public ------------
drop policy if exists "watchlists read" on public.watchlists;
drop policy if exists "watchlists owner insert" on public.watchlists;
drop policy if exists "watchlists owner update" on public.watchlists;
drop policy if exists "watchlists owner delete" on public.watchlists;

create policy "watchlists read" on public.watchlists
  for select to anon, authenticated
  using (is_public or (select auth.uid()) = user_id);
create policy "watchlists owner insert" on public.watchlists
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "watchlists owner update" on public.watchlists
  for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "watchlists owner delete" on public.watchlists
  for delete to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "watchlist items read" on public.watchlist_items;
drop policy if exists "watchlist items owner insert" on public.watchlist_items;
drop policy if exists "watchlist items owner update" on public.watchlist_items;
drop policy if exists "watchlist items owner delete" on public.watchlist_items;

create policy "watchlist items read" on public.watchlist_items
  for select to anon, authenticated
  using (exists (
    select 1 from public.watchlists w
    where w.id = watchlist_id and (w.is_public or w.user_id = (select auth.uid()))));
create policy "watchlist items owner insert" on public.watchlist_items
  for insert to authenticated
  with check (exists (
    select 1 from public.watchlists w
    where w.id = watchlist_id and w.user_id = (select auth.uid())));
create policy "watchlist items owner update" on public.watchlist_items
  for update to authenticated
  using (exists (
    select 1 from public.watchlists w
    where w.id = watchlist_id and w.user_id = (select auth.uid())))
  with check (exists (
    select 1 from public.watchlists w
    where w.id = watchlist_id and w.user_id = (select auth.uid())));
create policy "watchlist items owner delete" on public.watchlist_items
  for delete to authenticated
  using (exists (
    select 1 from public.watchlists w
    where w.id = watchlist_id and w.user_id = (select auth.uid())));

-- Avis : publics sauf is_private ; écriture par l'auteur ------------------------
drop policy if exists "reviews read" on public.reviews;
drop policy if exists "reviews owner insert" on public.reviews;
drop policy if exists "reviews owner update" on public.reviews;
drop policy if exists "reviews owner delete" on public.reviews;

create policy "reviews read" on public.reviews
  for select to anon, authenticated
  using (not is_private or (select auth.uid()) = user_id);
create policy "reviews owner insert" on public.reviews
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "reviews owner update" on public.reviews
  for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "reviews owner delete" on public.reviews
  for delete to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "review likes read" on public.review_likes;
drop policy if exists "review likes owner insert" on public.review_likes;
drop policy if exists "review likes owner delete" on public.review_likes;

create policy "review likes read" on public.review_likes
  for select to anon, authenticated
  using (exists (
    select 1 from public.reviews r
    where r.id = review_id and (not r.is_private or r.user_id = (select auth.uid()))));
create policy "review likes owner insert" on public.review_likes
  for insert to authenticated
  with check ((select auth.uid()) = user_id and exists (
    select 1 from public.reviews r where r.id = review_id and not r.is_private));
create policy "review likes owner delete" on public.review_likes
  for delete to authenticated using ((select auth.uid()) = user_id);

-- Catalogue : lecture pour les utilisateurs connectés, écriture admin --------
-- (les tables historiques media/news/genres/release_events restaient lisibles
-- par anon : conservé pour genres et release_events pendant la transition).
do $$
declare
  t text;
begin
  foreach t in array array['genres', 'movies', 'series', 'movie_genres',
                           'series_genres', 'platforms', 'release_events'] loop
    execute format('drop policy if exists "catalog readable" on public.%I', t);
    execute format('drop policy if exists "%1$s read" on public.%1$I', t);
    execute format('drop policy if exists "%1$s admin write" on public.%1$I', t);
    execute format('create policy "%1$s read" on public.%1$I for select '
                   'to authenticated using (true)', t);
    execute format('create policy "%1$s admin write" on public.%1$I for all '
                   'to authenticated using (public.is_admin()) '
                   'with check (public.is_admin())', t);
  end loop;
end $$;

-- Transition : l'onboarding lit les genres avant connexion.
drop policy if exists "genres anon read" on public.genres;
create policy "genres anon read" on public.genres for select to anon using (true);

commit;
