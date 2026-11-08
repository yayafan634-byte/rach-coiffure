class SupabaseConfig {
  SupabaseConfig._();

  static const bool actif = true;

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://bywczqqgaldngyrcxoko.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_9h8EaTEeRr1iUmB0QesZQg_-9nsFxv3',
  );
}
