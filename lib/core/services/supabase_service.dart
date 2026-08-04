import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// =======================================================
/// FAMHUB SUPABASE SERVICE
/// =======================================================
///
/// RESPONSIBILITY:
/// - Centralized Supabase client access
/// - Auth session access
/// - RPC execution
/// - Realtime channel creation
/// - Storage bucket access
/// - Generic database helpers
///
/// RULES:
/// - NO business logic
/// - NO feature-specific operations
/// - NO ownership/user_id injection
/// - Backend/RLS remains authoritative
///
/// =======================================================

class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  /// =======================================================
  /// CLIENT
  /// =======================================================

  final SupabaseClient client = Supabase.instance.client;

  /// =======================================================
  /// AUTH
  /// =======================================================

  User? get currentUser => client.auth.currentUser;

  Session? get currentSession => client.auth.currentSession;

  bool get isAuthenticated => currentUser != null;

  String? get currentUserId => currentUser?.id;

  Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;

  /// =======================================================
  /// DATABASE
  /// =======================================================

    SupabaseQueryBuilder from(String table, {String? schema}) {
    if (schema != null) {
      return client.schema(schema).from(table);
    }
    return client.from(table);
  }

  /// =======================================================
  /// RPC
  /// =======================================================

  Future<dynamic> rpc(
    String functionName, {
    Map<String, dynamic>? params,
  }) async {
    return client.rpc(
      functionName,
      params: params,
    );
  }

  /// =======================================================
  /// STORAGE
  /// =======================================================

  SupabaseStorageClient get storage => client.storage;

    Future<String> uploadFile({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
    FileOptions? options,
  }) async {
    await storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: options ??
              FileOptions(
                contentType: contentType,
                upsert: false,
              ),
        );

    return storage.from(bucket).getPublicUrl(path);
  }

  Future<void> deleteFile({
    required String bucket,
    required String path,
  }) async {
    await storage.from(bucket).remove([path]);
  }

  String getPublicUrl({
    required String bucket,
    required String path,
  }) {
    return storage.from(bucket).getPublicUrl(path);
  }

  /// =======================================================
  /// REALTIME
  /// =======================================================

  RealtimeChannel createChannel(String channelName) {
    return client.channel(channelName);
  }

  void removeChannel(RealtimeChannel channel) {
    client.removeChannel(channel);
  }

  /// =======================================================
  /// AUTH HELPERS
  /// =======================================================

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    return client.auth.signUp(
      email: email,
      password: password,
      data: metadata,
    );
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  Future<AuthResponse> refreshSession() async {
    return client.auth.refreshSession();
  }

  /// =======================================================
  /// GENERIC SELECT HELPERS
  /// =======================================================

  Future<List<Map<String, dynamic>>> selectList({
    required String table,
    String columns = '*',
  }) async {
    final response =
        await client.from(table).select(columns);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> selectSingle({
    required String table,
    required String column,
    required dynamic value,
    String columns = '*',
  }) async {
    final response = await client
        .from(table)
        .select(columns)
        .eq(column, value)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(response);
  }

  /// =======================================================
  /// INSERT
  /// =======================================================

  Future<dynamic> insert({
    required String table,
    required Map<String, dynamic> data,
  }) async {
    return client.from(table).insert(data);
  }

  /// =======================================================
  /// UPDATE
  /// =======================================================

  Future<dynamic> update({
    required String table,
    required Map<String, dynamic> data,
    required String matchColumn,
    required dynamic matchValue,
  }) async {
    return client
        .from(table)
        .update(data)
        .eq(matchColumn, matchValue);
  }

  /// =======================================================
  /// DELETE
  /// =======================================================

  Future<dynamic> delete({
    required String table,
    required String matchColumn,
    required dynamic matchValue,
  }) async {
    return client
        .from(table)
        .delete()
        .eq(matchColumn, matchValue);
  }
}