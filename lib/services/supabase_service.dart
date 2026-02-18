import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final supabase = Supabase.instance.client;
  
  // COURSES
  Future<List<Map<String, dynamic>>> getCourses() async {
    try {
      final response = await supabase.from('courses').select().order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting courses: $e');
      return [];
    }
  }
  
  Future<void> addCourse(String name, String description, String semester, String color, String icon) async {
    await supabase.from('courses').insert({
      'name': name,
      'description': description,
      'semester': semester,
      'color': color,
      'icon': icon,
    });
  }
  
  Future<void> updateCourse(int id, String name, String description, String semester, String color, String icon) async {
    await supabase.from('courses').update({
      'name': name,
      'description': description,
      'semester': semester,
      'color': color,
      'icon': icon,
    }).eq('id', id);
  }
  
  Future<void> deleteCourse(int id) async {
    await supabase.from('courses').delete().eq('id', id);
  }
  
  // FOLDERS
  Future<List<Map<String, dynamic>>> getRootFolders(int courseId) async {
    try {
      final response = await supabase
          .from('folders')
          .select()
          .eq('course_id', courseId)
          .filter('parent_id', 'is', null)
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting root folders: $e');
      return [];
    }
  }
  
  Future<List<Map<String, dynamic>>> getSubFolders(int parentId) async {
    try {
      final response = await supabase
          .from('folders')
          .select()
          .eq('parent_id', parentId)
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting sub folders: $e');
      return [];
    }
  }
  
  Future<Map<String, dynamic>> getFolder(int folderId) async {
    try {
      final response = await supabase
          .from('folders')
          .select()
          .eq('id', folderId)
          .single();
      return response;
    } catch (e) {
      print('Error getting folder: $e');
      return {};
    }
  }
  
  Future<int> addFolder({
    required int courseId,
    int? parentId,
    required String name,
    String description = '',
    String semester = '',
    String section = '',
  }) async {
    final response = await supabase.from('folders').insert({
      'course_id': courseId,
      'parent_id': parentId,
      'name': name,
      'description': description,
      'semester': semester,
      'section': section,
    }).select();
    
    return response[0]['id'];
  }
  
  // ADD THIS METHOD - Update folder
  Future<void> updateFolder(int id, String name, String description) async {
    await supabase.from('folders').update({
      'name': name,
      'description': description,
    }).eq('id', id);
  }
  
  Future<void> deleteFolder(int id) async {
    await supabase.from('folders').delete().eq('id', id);
  }
  
  // FILES
  Future<List<Map<String, dynamic>>> getFiles(int folderId) async {
    try {
      final response = await supabase
          .from('files')
          .select()
          .eq('folder_id', folderId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting files: $e');
      return [];
    }
  }
  
  Future<void> addFile(int folderId, String name, String url, String type, String size) async {
    await supabase.from('files').insert({
      'folder_id': folderId,
      'name': name,
      'url': url,
      'type': type,
      'size': size,
      'downloads': 0,
    });
  }
  
  Future<void> deleteFile(int id) async {
    await supabase.from('files').delete().eq('id', id);
  }
  
  Future<void> updateFileName(int id, String name) async {
    await supabase.from('files').update({'name': name}).eq('id', id);
  }
  
  // Download file and increment counter (if you have this RPC function)
  Future<void> incrementDownloadCount(int fileId) async {
    try {
      await supabase.rpc('increment_downloads', params: {'file_id': fileId});
    } catch (e) {
      print('Error incrementing download count: $e');
    }
  }
}