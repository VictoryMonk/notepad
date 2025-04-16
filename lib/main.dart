import 'package:flutter/material.dart';
import 'main_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NoteKeep',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF181C20),
        cardColor: const Color(0xFF23272B),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF181C20),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.blueGrey[200],
          foregroundColor: Colors.black,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF23272B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          hintStyle: TextStyle(color: Colors.grey[400]),
        ),
      ),
      home: const MainPage(),
    );
  }//i love boobies
}