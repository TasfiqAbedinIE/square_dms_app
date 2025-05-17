import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:square_dms_trial/pages/homeScreen.dart';
import 'package:square_dms_trial/globals.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final idController = TextEditingController();
  final passwordController = TextEditingController();

  final supabase = Supabase.instance.client;
  String error = "";

  bool _obscurePassword = true;

  Future<void> login() async {
    final id = idController.text.trim();
    final password = passwordController.text;

    if (id.isEmpty || password.isEmpty) {
      setState(() => error = "Please enter both ID and password.");
      return;
    }

    final response =
        await supabase
            .from('USERS')
            .select('authority')
            .eq('org_id', id)
            .eq('password', password)
            .maybeSingle();

    if (response != null) {
      userAuthority = response["authority"] as String;
      userID = id;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userID', id);
      await prefs.setString('authority', userAuthority!);

      isLoggedIn = true;

      // Login successful
      setState(() => error = "");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DashboardScreen()),
      );
    } else {
      setState(() => error = "Invalid ID or password.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.only(top: 100),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/logIn.png',
                      width: 250,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                    Text(
                      "SQUARE DMS",
                      style: GoogleFonts.lexend(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromARGB(255, 94, 43, 255),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Container(
                // height: 200,
                margin: EdgeInsets.all(10),
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(30, 94, 43, 255),
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: Column(
                  children: [
                    TextField(
                      maxLength: 8,
                      controller: idController,
                      decoration: InputDecoration(
                        labelText: "User ID",
                        labelStyle: GoogleFonts.lexend(color: Colors.black),
                      ),
                    ),
                    TextField(
                      controller: passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: "Password",
                        labelStyle: GoogleFonts.lexend(color: Colors.black),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: login,
                      child: const Text("Login"),
                    ),
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(error, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 80),
              Text("Version - 1.0.0", style: GoogleFonts.lexend()),
              SizedBox(height: 10),
              Text(
                "Developed By - IE & Workstudy Department",
                style: GoogleFonts.lexend(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
