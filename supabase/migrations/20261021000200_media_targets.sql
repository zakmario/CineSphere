-- ---------------------------------------------------------------------------
-- Listes et contenus vus : le catalogue de démonstration (table media)
-- devient une cible, comme pour favorites (transition tant que la table
-- media existe). Une ligne vise exactement un media, un film ou une série.
-- ---------------------------------------------------------------------------
alter table public.watchlist_items
  add column if not exists media_id uuid references public.media (id) on delete cascade;
alter table public.watched
  add column if not exists media_id uuid references public.media (id) on delete cascade;

alter table public.watchlist_items drop constraint if exists watchlist_items_one_target;
alter table public.watchlist_items add constraint watchlist_items_one_target
  check (num_nonnulls(media_id, movie_id, series_id) = 1);

alter table public.watched drop constraint if exists watched_one_target;
alter table public.watched add constraint watched_one_target
  check (num_nonnulls(media_id, movie_id, series_id) = 1);

create unique index if not exists watchlist_items_media_key
  on public.watchlist_items (watchlist_id, media_id) where media_id is not null;
create unique index if not exists watched_user_media_key
  on public.watched (user_id, media_id) where media_id is not null;

create index if not exists watchlist_items_media_idx on public.watchlist_items (media_id);
create index if not exists watched_media_idx on public.watched (media_id);
