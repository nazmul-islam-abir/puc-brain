import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final supabase = Supabase.instance.client;
  
  // Create table 'files' with columns: id, name, url, type, created_at
  
  Future<void> insertFileRecord(String name, String url, String type) async {
    await supabase.from('files').insert({
      'name': name,
      'url': url,
      'type': type,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
  
  Future<List<Map<String, dynamic>>> getFiles() async {
    final response = await supabase
        .from('files')
        .select()
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }
  
  Future<void> deleteFileRecord(int id) async {
    await supabase.from('files').delete().eq('id', id);
  }
  
  Future<void> updateFileRecord(int id, String name) async {
    await supabase.from('files').update({'name': name}).eq('id', id);
  }
}