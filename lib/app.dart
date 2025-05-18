import 'package:flutter/material.dart';
import 'screens/home/secure_drop_home_page.dart';

class SecureDropApp extends StatelessWidget {
  const SecureDropApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'SF Pro Display',
      ),
      home: SecureDropHomePage(),
    );
  }
}