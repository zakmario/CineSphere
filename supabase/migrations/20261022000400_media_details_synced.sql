-- Bandes-annonces manquantes (membre 1). La complétion visait seulement les
-- titres sans durée ni saisons : les titres de démonstration, déjà renseignés,
-- n'étaient jamais enrichis. media.details_synced_at note le dernier passage
-- DetailFilm / DetailSerie ; un titre est repris s'il n'a jamais été complété,
-- ou s'il n'a toujours pas de bande-annonce 7 jours après le dernier passage
-- (un titre sans bande-annonce ne bloque donc pas les autres).

begin;

alter table public.media add column if not exists details_synced_at timestamptz;
create index if not exists media_details_todo_idx
  on public.media (popularity desc) where tmdb_id is not null;

create or replace function public.enrich_tmdb_media(items jsonb)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  item jsonb;
  updated int := 0;
  n int;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentification requise.' using errcode = '42501';
  end if;
  if jsonb_typeof(items) is distinct from 'array' or jsonb_array_length(items) > 100 then
    raise exception 'items doit être un tableau de 100 titres au plus.' using errcode = '22023';
  end if;

  for item in select value from jsonb_array_elements(items) loop
    update public.media m set
      runtime_minutes = coalesce(nullif((item ->> 'runtime_minutes')::int, 0),
                                 m.runtime_minutes),
      seasons = coalesce(nullif((item ->> 'seasons')::int, 0), m.seasons),
      episodes = coalesce(nullif((item ->> 'episodes')::int, 0), m.episodes),
      status = case when m.media_type = 'series' and (item ->> 'ended')::boolean
                    then 'ended' else m.status end,
      trailer_url = coalesce(nullif(item ->> 'trailer_url', ''), m.trailer_url),
      platforms = case
        when jsonb_array_length(coalesce(item -> 'providers', '[]'::jsonb)) = 0
          then m.platforms
        else array(
          select distinct coalesce(p.name, pr ->> 'name')
          from jsonb_array_elements(item -> 'providers') pr
          left join public.platforms p on p.id = (pr ->> 'id')::int
          where coalesce(p.name, pr ->> 'name') is not null)
      end,
      details_synced_at = now()
    where m.media_type = item ->> 'media_type'
      and m.tmdb_id = (item ->> 'tmdb_id')::int;
    get diagnostics n = row_count;
    updated := updated + n;
  end loop;

  return updated;
end;
$$;

revoke execute on function public.enrich_tmdb_media(jsonb) from public, anon;
grant execute on function public.enrich_tmdb_media(jsonb) to authenticated;

commit;
