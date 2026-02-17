import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jtykfopjtirdjwrqqwbk.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0eWtmb3BqdGlyZGp3cnFxd2JrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA5NDExNzksImV4cCI6MjA4NjUxNzE3OX0.ofEYaHO0ADrh6BOkOvqpr4SphPgxb7LGXsVS5LdHnBg',
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'File Uploader',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomeScreen(),
    );
  }
}
