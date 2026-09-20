import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client {
    return Supabase.instance.client;
  }
}
