import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // If firebase_options.dart is missing, we show the missing config app
    runApp(const _MissingConfigApp());
    return;
  }

  runApp(const MedGuardApp());
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'MedGuard is not configured for Firebase.\n\n'
              'Please run:\n'
              'flutterfire configure\n\n'
              'to generate firebase_options.dart.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ),
      ),
    );
  }
}

