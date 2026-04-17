import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SupabaseService {
  static const String url = 'https://ysgdcumofngtytxvyxbe.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlzZ2RjdW1vZm5ndHl0eHZ5eGJlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUzODkyMTksImV4cCI6MjA5MDk2NTIxOX0.J0I2SrwmQ3PkV52ckrYQSGgDCUTL5xSKC-QHoeWRw0s';

  static Future<void> init() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }

  final _client = Supabase.instance.client;

  GoTrueClient get auth => _client.auth;
  SupabaseQueryBuilder get profiles => _client.from('profiles');
  
  User? get currentUser => auth.currentUser;
  Session? get currentSession => auth.currentSession;
}

final supabaseServiceProvider = Provider<SupabaseService>((ref) => SupabaseService());
