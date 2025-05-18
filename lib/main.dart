import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:secure_drop/app.dart';
import 'firebase_options.dart'; // auto-generated

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SecureDropApp());
}
