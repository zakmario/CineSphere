-- Détails TMDB des titres du catalogue (membre 1) : durée, saisons, épisodes,
-- statut d'une série, bande-annonce, plateformes en France. Les listes TMDB
-- ne les donnent pas : l'application appelle DetailFilm / DetailSerie pour
-- les titres incomplets et envoie le résultat à enrich_tmdb_media.

begin;

-- items : tableau JSON (100 titres au plus) de
--   {media_type: movie|series, tmdb_id, runtime_minutes, seasons, episodes,
--    ended: bool, trailer_url, providers: [{id, name}]}
-- Les plateformes connues prennent le nom de la table platforms (id TMDB).
-- Retourne le nombre de titres mis à jour.
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
      end
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
