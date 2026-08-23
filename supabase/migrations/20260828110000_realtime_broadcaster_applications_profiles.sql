-- ===========================================================================
-- Enable Supabase Realtime for broadcaster_applications and profiles tables
-- ===========================================================================

-- 1. Add broadcaster_applications to the supabase_realtime publication
alter publication supabase_realtime add table public.broadcaster_applications;

-- 2. Add profiles to the supabase_realtime publication
alter publication supabase_realtime add table public.profiles;
