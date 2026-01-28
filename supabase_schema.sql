-- ============================================
-- LAMP App - Complete Supabase Schema
-- Run this in Supabase SQL Editor
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 1. USERS TABLE
-- ============================================
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  name TEXT,
  email TEXT,
  role TEXT DEFAULT 'protege' CHECK (role IN ('protege', 'chaperone', 'admin')),
  chaperone_id UUID REFERENCES public.users(id),
  phone TEXT,
  location TEXT,
  current_streak BIGINT DEFAULT 0
);

-- RLS for users
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all users" ON public.users
  FOR SELECT USING (true);

CREATE POLICY "Users can insert own profile" ON public.users
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.users
  FOR UPDATE USING (auth.uid() = id);

-- ============================================
-- 2. CHAPERONE-PROTEGE RELATIONSHIP
-- ============================================
CREATE TABLE public.chaperone_protege (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chaperone_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  protege_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  protege_name TEXT NOT NULL,
  assigned_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(chaperone_id, protege_id)
);

ALTER TABLE public.chaperone_protege ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Chaperones can view their proteges" ON public.chaperone_protege
  FOR SELECT USING (auth.uid() = chaperone_id OR auth.uid() = protege_id);

CREATE POLICY "Chaperones can insert relationships" ON public.chaperone_protege
  FOR INSERT WITH CHECK (auth.uid() = chaperone_id);

CREATE POLICY "Chaperones can delete relationships" ON public.chaperone_protege
  FOR DELETE USING (auth.uid() = chaperone_id);

-- ============================================
-- 3. HABITS
-- ============================================
CREATE TABLE public.habits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  icon_url TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  created_by UUID REFERENCES public.users(id)
);

ALTER TABLE public.habits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view habits" ON public.habits
  FOR SELECT USING (true);

CREATE POLICY "Chaperones/Admins can create habits" ON public.habits
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('chaperone', 'admin'))
  );

-- ============================================
-- 4. HABIT ASSIGNMENTS
-- ============================================
CREATE TABLE public.habit_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  protege_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  habit_id UUID NOT NULL REFERENCES public.habits(id) ON DELETE CASCADE,
  assigned_at TIMESTAMPTZ DEFAULT now(),
  repetition_days TEXT[] DEFAULT ARRAY['Mon','Tue','Wed','Thu','Fri','Sat','Sun']
);

ALTER TABLE public.habit_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own habit assignments" ON public.habit_assignments
  FOR SELECT USING (auth.uid() = protege_id);

CREATE POLICY "Chaperones can view protege assignments" ON public.habit_assignments
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.chaperone_protege WHERE chaperone_id = auth.uid() AND protege_id = habit_assignments.protege_id)
  );

CREATE POLICY "Chaperones can assign habits" ON public.habit_assignments
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('chaperone', 'admin'))
  );

-- ============================================
-- 5. HABIT LOGS
-- ============================================
CREATE TABLE public.habit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  habit_id UUID REFERENCES public.habits(id) ON DELETE CASCADE,
  protege_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  start_time TIME,
  duration_minutes INTEGER,
  before_feeling TEXT,
  after_feeling TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  verification_status TEXT DEFAULT 'approved' CHECK (verification_status IN ('pending', 'approved', 'rejected'))
);

ALTER TABLE public.habit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own logs" ON public.habit_logs
  FOR SELECT USING (auth.uid() = protege_id);

CREATE POLICY "Chaperones can view protege logs" ON public.habit_logs
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.chaperone_protege WHERE chaperone_id = auth.uid() AND protege_id = habit_logs.protege_id)
  );

CREATE POLICY "Users can insert own logs" ON public.habit_logs
  FOR INSERT WITH CHECK (auth.uid() = protege_id);

CREATE POLICY "Users can update own logs" ON public.habit_logs
  FOR UPDATE USING (auth.uid() = protege_id);

-- ============================================
-- 6. HABIT STREAKS
-- ============================================
CREATE TABLE public.habit_streaks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  protege_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  habit_id UUID REFERENCES public.habits(id) ON DELETE CASCADE,
  current_streak INTEGER DEFAULT 0,
  longest_streak INTEGER DEFAULT 0,
  last_logged_date DATE,
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.habit_streaks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own streaks" ON public.habit_streaks
  FOR SELECT USING (auth.uid() = protege_id);

CREATE POLICY "Users can insert own streaks" ON public.habit_streaks
  FOR INSERT WITH CHECK (auth.uid() = protege_id);

CREATE POLICY "Users can update own streaks" ON public.habit_streaks
  FOR UPDATE USING (auth.uid() = protege_id);

-- ============================================
-- 7. TASKS
-- ============================================
CREATE TABLE public.tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  type TEXT DEFAULT 'medium',
  video_url TEXT,
  document_url TEXT,
  deadline TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  created_by UUID REFERENCES public.users(id)
);

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view tasks" ON public.tasks
  FOR SELECT USING (true);

CREATE POLICY "Chaperones can create tasks" ON public.tasks
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('chaperone', 'admin'))
  );

CREATE POLICY "Chaperones can delete own tasks" ON public.tasks
  FOR DELETE USING (created_by = auth.uid());

-- ============================================
-- 8. TASK ASSIGNMENTS
-- ============================================
CREATE TABLE public.task_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID REFERENCES public.tasks(id) ON DELETE CASCADE,
  protege_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  chaperone_id UUID REFERENCES public.users(id),
  assigned_by_role TEXT CHECK (assigned_by_role IN ('admin', 'chaperone')),
  status TEXT DEFAULT 'assigned' CHECK (status IN ('assigned', 'ToVerify', 'verified')),
  remarks TEXT,
  assigned_at TIMESTAMPTZ DEFAULT now(),
  completed_at TIMESTAMPTZ,
  reviewed_at TIMESTAMPTZ
);

ALTER TABLE public.task_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own task assignments" ON public.task_assignments
  FOR SELECT USING (auth.uid() = protege_id OR auth.uid() = chaperone_id);

CREATE POLICY "Chaperones can insert task assignments" ON public.task_assignments
  FOR INSERT WITH CHECK (auth.uid() = chaperone_id);

CREATE POLICY "Users can update own task assignments" ON public.task_assignments
  FOR UPDATE USING (auth.uid() = protege_id OR auth.uid() = chaperone_id);

-- ============================================
-- 9. INSERT DEFAULT HABITS
-- ============================================
INSERT INTO public.habits (name, description) VALUES
  ('Morning Meditation', 'Start your day with Heartfulness meditation'),
  ('Cleaning', 'Evening cleaning practice to remove impressions'),
  ('Prayer', 'Connect with the divine through heartfelt prayer'),
  ('Reading', 'Read spiritual literature for 15 minutes'),
  ('Journaling', 'Reflect on your day and inner experiences');

-- ============================================
-- DONE! Your database is ready.
-- ============================================

-- ============================================
-- PHASE 2: ADDITIONAL TABLES
-- Run this AFTER the initial schema
-- ============================================

-- ============================================
-- 10. UPDATE USERS TABLE
-- ============================================
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS interests TEXT[];
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS courses TEXT[];

-- ============================================
-- 11. USER INVITES (Admin invites users)
-- ============================================
CREATE TABLE IF NOT EXISTS public.user_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('protege', 'chaperone', 'admin')),
  invited_by UUID REFERENCES public.users(id),
  invited_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '7 days'),
  accepted_at TIMESTAMPTZ,
  UNIQUE(email)
);

ALTER TABLE public.user_invites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage invites" ON public.user_invites
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Users can view their own invite" ON public.user_invites
  FOR SELECT USING (email = (SELECT email FROM auth.users WHERE id = auth.uid()));

-- ============================================
-- 12. COMMUNITY POSTS
-- ============================================
CREATE TABLE IF NOT EXISTS public.posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view posts" ON public.posts
  FOR SELECT USING (true);

CREATE POLICY "Users can create posts" ON public.posts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own posts" ON public.posts
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Admins can delete any post" ON public.posts
  FOR DELETE USING (
    auth.uid() = user_id OR
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
  );

-- ============================================
-- 13. POST REACTIONS (upvote/downvote)
-- ============================================
CREATE TABLE IF NOT EXISTS public.post_reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  reaction_type TEXT NOT NULL CHECK (reaction_type IN ('up', 'down')),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(post_id, user_id)
);

ALTER TABLE public.post_reactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view reactions" ON public.post_reactions
  FOR SELECT USING (true);

CREATE POLICY "Users can manage own reactions" ON public.post_reactions
  FOR ALL USING (auth.uid() = user_id);

-- ============================================
-- 14. COMMENTS
-- ============================================
CREATE TABLE IF NOT EXISTS public.comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view comments" ON public.comments
  FOR SELECT USING (true);

CREATE POLICY "Users can create comments" ON public.comments
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users/Admins can delete comments" ON public.comments
  FOR DELETE USING (
    auth.uid() = user_id OR
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
  );

-- ============================================
-- 15. ADMIN KPI VIEW (for analytics)
-- ============================================
CREATE OR REPLACE VIEW public.user_kpis AS
SELECT 
  u.id,
  u.name,
  u.email,
  u.role,
  -- Task completion rate
  COALESCE(
    (SELECT COUNT(*) FILTER (WHERE status = 'verified') * 100.0 / NULLIF(COUNT(*), 0)
     FROM public.task_assignments WHERE protege_id = u.id), 0
  ) as task_completion_percent,
  -- Habit consistency (days logged / 30)
  COALESCE(
    (SELECT COUNT(DISTINCT date) * 100.0 / 30
     FROM public.habit_logs 
     WHERE protege_id = u.id AND date >= CURRENT_DATE - 30), 0
  ) as habit_consistency_percent
FROM public.users u
WHERE u.role = 'protege';

-- ============================================
-- PHASE 2 COMPLETE!
-- ============================================

-- ============================================
-- PHASE 3: MEDIA STORAGE
-- Run this AFTER Phase 2
-- ============================================

-- Add media columns to posts
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS photos TEXT[];
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS video_url TEXT;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS document_url TEXT;

-- Create storage bucket for media
-- NOTE: Run this in Supabase Dashboard > Storage > New Bucket
-- Bucket name: media
-- Public: Yes (for easy access)
-- Or use SQL:
INSERT INTO storage.buckets (id, name, public)
VALUES ('media', 'media', true)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS policies
CREATE POLICY "Anyone can view media" ON storage.objects
  FOR SELECT USING (bucket_id = 'media');

CREATE POLICY "Authenticated users can upload media" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'media' AND
    auth.role() = 'authenticated'
  );

CREATE POLICY "Users can delete own media" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'media' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- ============================================
-- PHASE 3 COMPLETE!
-- ============================================

-- ============================================
-- PHASE 4: INVITE SYSTEM & MATCHING
-- Run this AFTER Phase 3
-- ============================================

-- Add invite code to user_invites
ALTER TABLE public.user_invites ADD COLUMN IF NOT EXISTS invite_code TEXT;
ALTER TABLE public.user_invites ADD COLUMN IF NOT EXISTS chaperone_id UUID REFERENCES public.users(id);

-- Create unique index for invite lookup
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_invites_code ON public.user_invites(invite_code) WHERE invite_code IS NOT NULL;

-- Predefined interests (admin-managed)
CREATE TABLE IF NOT EXISTS public.predefined_interests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.predefined_interests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view interests" ON public.predefined_interests
  FOR SELECT USING (true);

CREATE POLICY "Admins can manage interests" ON public.predefined_interests
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
  );

-- Predefined courses (admin-managed)
CREATE TABLE IF NOT EXISTS public.predefined_courses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.predefined_courses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view courses" ON public.predefined_courses
  FOR SELECT USING (true);

CREATE POLICY "Admins can manage courses" ON public.predefined_courses
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
  );

-- Insert default interests
INSERT INTO public.predefined_interests (name, description) VALUES
  ('Meditation', 'Daily meditation practice'),
  ('Spirituality', 'Spiritual growth and development'),
  ('Mindfulness', 'Being present and aware'),
  ('Yoga', 'Physical and mental wellness'),
  ('Reading', 'Spiritual literature'),
  ('Service', 'Helping others'),
  ('Nature', 'Connecting with nature')
ON CONFLICT (name) DO NOTHING;

-- Insert default courses
INSERT INTO public.predefined_courses (name, description) VALUES
  ('Heartfulness Masterclass', 'Core meditation techniques'),
  ('Relaxation', 'Stress management'),
  ('Cleaning', 'Removing impressions'),
  ('Introduction to Meditation', 'Beginner course'),
  ('Advanced Practices', 'Deepening your practice')
ON CONFLICT (name) DO NOTHING;

-- Function to generate invite code
CREATE OR REPLACE FUNCTION generate_invite_code()
RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result TEXT := '';
  i INTEGER;
BEGIN
  FOR i IN 1..8 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::INTEGER, 1);
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-generate invite code
CREATE OR REPLACE FUNCTION set_invite_code()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.invite_code IS NULL THEN
    NEW.invite_code := generate_invite_code();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_set_invite_code ON public.user_invites;
CREATE TRIGGER trigger_set_invite_code
  BEFORE INSERT ON public.user_invites
  FOR EACH ROW
  EXECUTE FUNCTION set_invite_code();

-- Auto-matching function (finds best chaperone based on interests)
CREATE OR REPLACE FUNCTION find_best_chaperone(protege_interests TEXT[])
RETURNS UUID AS $$
DECLARE
  best_chaperone UUID;
BEGIN
  SELECT u.id INTO best_chaperone
  FROM public.users u
  LEFT JOIN public.chaperone_protege cp ON cp.chaperone_id = u.id
  WHERE u.role = 'chaperone'
  GROUP BY u.id, u.interests
  HAVING COUNT(cp.id) < 5  -- Max 5 proteges
  ORDER BY 
    COALESCE(array_length(ARRAY(SELECT unnest(u.interests) INTERSECT SELECT unnest(protege_interests)), 1), 0) DESC,
    COUNT(cp.id) ASC  -- Prefer less loaded chaperones
  LIMIT 1;
  
  RETURN best_chaperone;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- BOOTSTRAP: CREATE FIRST ADMIN USER
-- Replace with your actual email after signing up!
-- ============================================
-- Step 1: Sign up with email/password in the app
-- Step 2: Run this SQL (replace YOUR_USER_ID):
-- 
-- UPDATE public.users 
-- SET role = 'admin' 
-- WHERE id = 'YOUR_USER_ID';
--
-- OR if user doesn't exist yet, insert manually:
-- INSERT INTO public.users (id, email, name, role)
-- VALUES ('YOUR_AUTH_USER_ID', 'admin@example.com', 'Admin', 'admin');
-- ============================================

-- ============================================
-- PHASE 4 COMPLETE!
-- ============================================
