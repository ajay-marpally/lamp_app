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
