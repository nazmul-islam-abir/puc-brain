import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserRole {
  guest,
  alumni,
}

class SupabaseService {
  final supabase = Supabase.instance.client;
  User? get currentUser => supabase.auth.currentUser;
  UserRole? userRole;
  String? currentUserId; // This will be the ID from users table

  Future<UserRole?> login(String id, String mobile) async {
    try {
      // Check alumni users
      final alumniResponse = await supabase
          .from('alumni_users')
          .select()
          .eq('id', id)
          .eq('mobile', mobile)
          .maybeSingle();

      if (alumniResponse != null) {
        userRole = UserRole.alumni;
        
        // Get or create user in users table
        final userResponse = await supabase
            .from('users')
            .select()
            .eq('user_login_id', id)
            .eq('user_type', 'alumni')
            .maybeSingle();
            
        if (userResponse != null) {
          currentUserId = userResponse['id'];
        } else {
          // Create user if doesn't exist
          final newUser = await supabase
              .from('users')
              .insert({
                'user_type': 'alumni',
                'user_login_id': id,
              })
              .select()
              .single();
          currentUserId = newUser['id'];
        }
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_login_id', id);
        await prefs.setString('role', 'alumni');
        await prefs.setString('user_id', currentUserId ?? '');
        return userRole;
      }

      // Check guest users
      final guestResponse = await supabase
          .from('guest_users')
          .select()
          .eq('id', id)
          .eq('mobile', mobile)
          .maybeSingle();

      if (guestResponse != null) {
        userRole = UserRole.guest;
        
        // Get or create user in users table
        final userResponse = await supabase
            .from('users')
            .select()
            .eq('user_login_id', id)
            .eq('user_type', 'guest')
            .maybeSingle();
            
        if (userResponse != null) {
          currentUserId = userResponse['id'];
        } else {
          // Create user if doesn't exist
          final newUser = await supabase
              .from('users')
              .insert({
                'user_type': 'guest',
                'user_login_id': id,
              })
              .select()
              .single();
          currentUserId = newUser['id'];
        }
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_login_id', id);
        await prefs.setString('role', 'guest');
        await prefs.setString('user_id', currentUserId ?? '');
        return userRole;
      }

    } catch (e) {
      print('Error during login: $e');
    }
    return null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    currentUserId = null;
    userRole = null;
  }

  Future<String?> getCurrentUserId() async {
    if (currentUserId != null) return currentUserId;
    
    final prefs = await SharedPreferences.getInstance();
    currentUserId = prefs.getString('user_id');
    return currentUserId;
  }

  Future<List<Map<String, dynamic>>> getCourses() async {
    try {
      final response = await supabase.from('courses').select().order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting courses: $e');
      return [];
    }
  }

  Future<void> addCourse(String name, String description, String semester,
      String color, String icon) async {
    await supabase.from('courses').insert({
      'name': name,
      'description': description,
      'semester': semester,
      'color': color,
      'icon': icon,
    });
  }

  Future<void> updateCourse(int id, String name, String description,
      String semester, String color, String icon) async {
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
      final response =
          await supabase.from('folders').select().eq('id', folderId).single();
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

  Future<void> updateFolder(int id, String name, String description) async {
    await supabase
        .from('folders')
        .update({
          'name': name,
          'description': description,
        })
        .eq('id', id);
  }

  Future<void> deleteFolder(int id) async {
    await supabase.from('folders').delete().eq('id', id);
  }

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

  Future<void> addFile(
      int folderId, String name, String url, String type, String size) async {
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

  Future<void> incrementDownloadCount(int fileId) async {
    try {
      await supabase.rpc('increment_downloads', params: {'file_id': fileId});
    } catch (e) {
      print('Error incrementing download count: $e');
    }
  }

  // Profile and Chat Functions
  Future<bool> setUsername(String username) async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) return false;

      // Check if username is already taken
      final response = await supabase
          .from('users')
          .select()
          .eq('username', username)
          .maybeSingle();
          
      if (response != null) {
        return false; // Username already taken
      }

      await supabase
          .from('users')
          .update({'username': username})
          .eq('id', userId);
      return true;
    } catch (e) {
      print('Error setting username: $e');
      return false;
    }
  }

  Future<String?> getUsername() async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) return null;
      
      final response = await supabase
          .from('users')
          .select('username')
          .eq('id', userId)
          .maybeSingle();
          
      return response?['username'];
    } catch (e) {
      print('Error getting username: $e');
      return null;
    }
  }

  Future<String?> getUserIdByUsername(String username) async {
    try {
      final response = await supabase
          .from('users')
          .select('id, username, user_type')
          .eq('username', username)
          .maybeSingle();
      return response?['id'];
    } catch (e) {
      print('Error getting user ID by username: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await supabase
          .from('users')
          .select('id, username, user_type')
          .eq('id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  Future<bool> addBuddy(String buddyId) async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) return false;

      // Check if buddy exists
      final buddyResponse = await supabase
          .from('users')
          .select()
          .eq('id', buddyId)
          .maybeSingle();
          
      if (buddyResponse == null) {
        return false;
      }

      // Don't allow adding self as buddy
      if (userId == buddyId) {
        return false;
      }

      // Check if already buddies
      final existingBuddy = await supabase
          .from('buddies')
          .select()
          .eq('user_id', userId)
          .eq('buddy_id', buddyId)
          .maybeSingle();
          
      if (existingBuddy != null) {
        return false; // Already buddies
      }

      // Add buddy relationship (both directions for easier querying)
      await supabase.from('buddies').insert({
        'user_id': userId,
        'buddy_id': buddyId,
      });

      // Also add reverse relationship
      await supabase.from('buddies').insert({
        'user_id': buddyId,
        'buddy_id': userId,
      });

      return true;
    } catch (e) {
      print('Error adding buddy: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getBuddies() async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) return [];

      // Get all buddy IDs for this user
      final response = await supabase
          .from('buddies')
          .select('buddy_id')
          .eq('user_id', userId);

      if (response.isEmpty) return [];

      final buddyIds = response.map((e) => e['buddy_id'] as String).toList();

      // Get full profiles for all buddies
      final buddies = await supabase
          .from('users')
          .select('id, username, user_type')
          .inFilter('id', buddyIds);

      return List<Map<String, dynamic>>.from(buddies);
    } catch (e) {
      print('Error getting buddies: $e');
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> getMessages(String buddyId) {
    final userId = getCurrentUserId();

    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((messages) {
          return messages.where((msg) {
            return (msg['sender_id'] == userId &&
                    msg['receiver_id'] == buddyId) ||
                (msg['sender_id'] == buddyId &&
                    msg['receiver_id'] == userId);
          }).toList();
        });
  }

  Future<void> sendMessage(String buddyId, String content) async {
    final userId = await getCurrentUserId();
    if (userId == null) return;
    
    await supabase.from('messages').insert({
      'sender_id': userId,
      'receiver_id': buddyId,
      'content': content,
      'is_read': false,
    });
  }

  // Posts/Feeds Functions
  Stream<List<Map<String, dynamic>>> getPosts() {
    return supabase
        .from('posts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .asyncMap((posts) async {
          // Fetch usernames for each post
          final postsWithUsernames = await Future.wait(
            posts.map((post) async {
              final userProfile = await getUserProfile(post['user_id']);
              post['username'] = userProfile?['username'] ?? 'Unknown User';
              return post;
            }),
          );
          return postsWithUsernames;
        });
  }

  Future<void> addPost(dynamic content) async {
    final userId = await getCurrentUserId();
    if (userId == null) return;
    
    // Convert content to JSON string if it's a Map
    final contentJson = content is String ? content : jsonEncode(content);
    
    await supabase.from('posts').insert({
      'user_id': userId,
      'content': contentJson,
    });
  }

  Future<void> updatePost(int id, String content) async {
    await supabase.from('posts').update({
      'content': content,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deletePost(int id) async {
    await supabase.from('posts').delete().eq('id', id);
  }
}