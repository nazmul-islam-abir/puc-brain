import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'services/upload_service.dart';
import 'screens/courses_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");
    
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
  } catch (e) {
    print('Error initializing: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => UploadService(),
      child: MaterialApp(
        title: 'StudyHub',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Poppins',
          brightness: Brightness.dark,
          colorScheme: const ColorScheme.dark(
            primary: Colors.purple,
            secondary: Colors.blue,
            surface: Color(0xFF1A1F2E),
          ),
        ),
        home: const CoursesScreen(),
      ),
    );
  }
}