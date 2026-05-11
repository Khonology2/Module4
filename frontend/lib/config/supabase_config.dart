class SupabaseConfig {
  // Replace these with your actual Supabase project credentials
  static const String supabaseUrl = 'https://your-project-id.supabase.co';
  static const String supabaseAnonKey = 'your-anon-key-here';
  
  // For development, you can use these demo values
  // In production, replace with your actual Supabase project
  static const bool isDevelopment = true;
  
  static String get url => isDevelopment 
      ? 'https://demo.supabase.co' 
      : supabaseUrl;
      
  static String get anonKey => isDevelopment
      ? 'demo-key'
      : supabaseAnonKey;
}
