/// Supabase Configuration
/// Replace these with your actual Supabase credentials
class SupabaseConfig {
  SupabaseConfig._();

  // Supabase project URL
  static const String supabaseUrl = 'https://twzrmmheyokdktmnszno.supabase.co';
  
  // Supabase anon key
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR3enJtbWhleW9rZGt0bW5zem5vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2MTY2OTUsImV4cCI6MjA4NTE5MjY5NX0.yBAF7QRK33deuCZgi_2l5jjJTBGoA161kpElEUzOybU';
}

/// App Configuration
class AppConfig {
  AppConfig._();

  static const String appName = 'LAMP';
  static const String appFullName = 'Limitless Advancement Mentoring Program';
  static const String appTagline = 'Regularise • Organise • Interiorise';
  static const String organizationName = 'Heartfulness';
}

/// User Roles
class UserRole {
  UserRole._();

  static const String protege = 'protege';
  static const String chaperone = 'chaperone';
  static const String admin = 'admin';
}

/// Habit Verification Status
class VerificationStatus {
  VerificationStatus._();

  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
}

/// Task Assignment Status
class TaskStatus {
  TaskStatus._();

  static const String assigned = 'assigned';
  static const String toVerify = 'ToVerify';
  static const String verified = 'verified';
}
