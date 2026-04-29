import 'package:flutter/material.dart';
import 'package:myapp/services/supabase_service.dart';

class AddBuddyScreen extends StatefulWidget {
  const AddBuddyScreen({super.key});

  @override
  State<AddBuddyScreen> createState() => _AddBuddyScreenState();
}

class _AddBuddyScreenState extends State<AddBuddyScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _buddyUsernameController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _foundUser;
  bool _isAdding = false;

  void _searchUser() async {
    if (_buddyUsernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a username')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _foundUser = null;
    });

    final userId = await _supabaseService.getUserIdByUsername(
      _buddyUsernameController.text.trim()
    );

    if (userId != null) {
      final userProfile = await _supabaseService.getUserProfile(userId);
      setState(() {
        _foundUser = userProfile;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not found'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addBuddy() async {
    if (_foundUser == null) return;

    setState(() => _isAdding = true);
    final success = await _supabaseService.addBuddy(_foundUser!['id']);
    setState(() => _isAdding = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_foundUser!['username']} added as buddy'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add buddy. Already added or error occurred.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Buddy'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B0E1A), Color(0xFF1A1F2E)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Icon
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C5CBF), Color(0xFF4F8EF7)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Add Friends by Username',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Enter the username of the person you want to connect with',
                style: TextStyle(
                  color: Color(0xFF7A7A9A),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              // Search field
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1928),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2A2840)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _buddyUsernameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Enter username',
                          hintStyle: TextStyle(color: Color(0xFF7A7A9A)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onSubmitted: (_) => _searchUser(),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(4),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _searchUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C5CBF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          minimumSize: const Size(70, 40),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Search'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Found user
              if (_foundUser != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1928),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2A2840)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7C5CBF), Color(0xFF4F8EF7)],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                _foundUser!['username'][0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _foundUser!['username'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'User Type: ${_foundUser!['user_type']}',
                                  style: const TextStyle(
                                    color: Color(0xFF7A7A9A),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isAdding ? null : _addBuddy,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C5CBF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isAdding
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Add Buddy'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}