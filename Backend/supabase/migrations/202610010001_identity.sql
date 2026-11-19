-- Apply once using Supabase SQL Editor or `supabase db push`.
-- Authentication/passwords/sessions belong to Supabase Auth, not these tables.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('parent', 'teacher')),
  display_name text not null check (length(trim(display_name)) between 2 and 100),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (display_name) on public.profiles to authenticated;
create policy profile_read_self on public.profiles for select to authenticated
  using (id = (select auth.uid()));
create policy profile_update_self on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- Initial role is validated here, then immutable from mobile clients.
-- Never grant owner/admin authority from user-editable auth metadata.
create function public.create_signup_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(new.raw_user_meta_data->>'role', '') not in ('parent', 'teacher') then
    raise exception 'A valid account role is required';
  end if;
  insert into public.profiles(id, role, display_name)
  values (new.id, new.raw_user_meta_data->>'role', trim(new.raw_user_meta_data->>'display_name'));
  return new;
end;
$$;
revoke all on function public.create_signup_profile() from public, anon, authenticated;
create trigger create_daam_profile after insert on auth.users
  for each row execute procedure public.create_signup_profile();

-- Certificates are never publicly readable. Owner review will be a separate
-- server-authorized workflow, not an admin toggle exposed to mobile clients.
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('teacher-certificates', 'teacher-certificates', false, 10485760,
        array['application/pdf', 'image/jpeg', 'image/png']);
create policy certificate_upload_self on storage.objects for insert to authenticated
with check (
  bucket_id = 'teacher-certificates'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'teacher')
);
create policy certificate_read_self on storage.objects for select to authenticated
using (bucket_id = 'teacher-certificates' and owner_id = (select auth.uid())::text);
create policy certificate_delete_self on storage.objects for delete to authenticated
using (bucket_id = 'teacher-certificates' and owner_id = (select auth.uid())::text);
