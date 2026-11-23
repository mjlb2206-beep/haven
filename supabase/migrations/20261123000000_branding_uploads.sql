-- Host personalization (Nov 23):
-- 1. "brand-assets" storage bucket so hosts upload their logo instead of pasting a link.
--    Files live under <organization_id>/..., and only members of that company can write there.
--    The bucket is public-read because guests (not signed in) must see the logo.
-- 2. get_brand_public(slug): the look of a host's portal before the guest finds their stay,
--    used by personal links like /find-my-stay?h=palm-stays. Only public brand fields.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('brand-assets', 'brand-assets', true, 2097152,
        array['image/png', 'image/jpeg', 'image/webp', 'image/svg+xml'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- First folder of the path must be an organization id the user belongs to.
create or replace function public.brand_asset_org_ok(p_name text)
returns boolean language sql stable security definer set search_path = public as $$
  select case
    when (storage.foldername(p_name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then public.is_org_member(((storage.foldername(p_name))[1])::uuid)
    else false end
$$;

drop policy if exists brand_assets_read   on storage.objects;
drop policy if exists brand_assets_insert on storage.objects;
drop policy if exists brand_assets_update on storage.objects;
drop policy if exists brand_assets_delete on storage.objects;
create policy brand_assets_read   on storage.objects for select using (bucket_id = 'brand-assets');
create policy brand_assets_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'brand-assets' and public.brand_asset_org_ok(name));
create policy brand_assets_update on storage.objects for update to authenticated
  using (bucket_id = 'brand-assets' and public.brand_asset_org_ok(name))
  with check (bucket_id = 'brand-assets' and public.brand_asset_org_ok(name));
create policy brand_assets_delete on storage.objects for delete to authenticated
  using (bucket_id = 'brand-assets' and public.brand_asset_org_ok(name));

create or replace function public.get_brand_public(p_slug text)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'slug', o.slug, 'business_name', coalesce(b.business_name, o.name), 'tagline', b.tagline,
    'logo_url', b.logo_url, 'primary_color', b.primary_color, 'accent_color', b.accent_color,
    'default_language', b.default_language, 'show_powered_by', coalesce(b.show_powered_by, true))
  from organizations o left join brand_settings b on b.organization_id = o.id
  where o.slug = lower(trim(coalesce(p_slug, '')));
$$;
grant execute on function public.get_brand_public(text) to anon, authenticated;
