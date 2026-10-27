-- CinéSphère — migration 12 : avertissements du Security Advisor (27/10).
--
-- 1. public.rls_auto_enable() : fonction de trigger d'événement ajoutée par
--    Supabase, jamais appelée par l'app. Plus exécutable via l'API.
-- 2. Bucket avatars : la politique SELECT large permettait de lister tous les
--    fichiers. Un bucket public sert ses fichiers par URL sans politique
--    SELECT ; seul le propriétaire peut encore lister son dossier `{user_id}/`.
--
-- Restent volontairement signalées : les RPC appelées par l'app
-- (username_available, get_public_profile, delete_my_account, import/enrich
-- TMDB, upsert_*_from_tmdb), is_admin() utilisée par les politiques RLS, et la
-- protection des mots de passe divulgués (offre Pro uniquement).

begin;

-- 1. rls_auto_enable ---------------------------------------------------------
do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
  end if;
end $$;

-- 2. Bucket avatars ----------------------------------------------------------
drop policy if exists "avatars public read" on storage.objects;
drop policy if exists "avatars owner read" on storage.objects;

create policy "avatars owner read" on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars'
         and (storage.foldername(name))[1] = (select auth.uid())::text);

commit;
