import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;
  bool isLoggedIn() => currentUser != null;
  Session? get currentSession => _supabase.auth.currentSession;
  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;

  Future<AuthResponse> signInWithEmailPassword(
      String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmailPassword(
      String email, String password, String fullName, String role) async {
    final response =
        await _supabase.auth.signUp(email: email, password: password);

    final user = response.user;

    if (user != null) {
      final insertData = {
        'id': user.id,
        'username': email,
        'full_name': fullName,
        'role': role,
      };

      await _supabase.from('profiles').insert(insertData);
    }

    return response;
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    return await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
  }

  Future<void> updateProfile(
      String userId, Map<String, dynamic> updates) async {
    await _supabase.from('profiles').update(updates).eq('id', userId);
  }
}
