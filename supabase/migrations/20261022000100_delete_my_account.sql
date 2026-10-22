-- Suppression de compte par le membre lui-même (page Paramètres).
-- Supprimer la ligne auth.users efface en cascade profiles puis toutes les
-- données du membre (préférences, favoris, listes, vus, avis, likes,
-- notifications, historique). Les fichiers du bucket avatars ne peuvent pas
-- être supprimés en SQL : l'application les retire avant d'appeler la fonction.

begin;

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  delete from auth.users where id = uid;
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

commit;
