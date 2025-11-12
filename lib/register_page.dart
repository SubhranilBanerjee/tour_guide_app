import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();

  String selectedRole = "tourist";
  bool _isLoading = false; // Added loading state

  @override
  void dispose() {
    // Clean up controllers
    emailController.dispose();
    passwordController.dispose();
    fullNameController.dispose();
    usernameController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    setState(() => _isLoading = true); // Start loading

    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      final fullName = fullNameController.text.trim();
      final username = usernameController.text.trim();

      // Sign Up
      final AuthResponse res =
          await supabase.auth.signUp(email: email, password: password);

      final User? user = res.user ?? supabase.auth.currentUser;

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration failed.')),
          );
        }
        return;
      }

      // Insert/Update Profile
      await supabase.from('profiles').upsert({
        'id': user.id,
        'full_name': fullName,
        'username': username,
        'role': selectedRole,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User registered successfully!')),
        );
        // AuthGate will handle redirect on successful session creation.
      }
    } on AuthException catch (e) {
      // Catch specific Auth errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false); // Stop loading
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register"),
        backgroundColor: const Color(0xff6200ee),
        foregroundColor: Colors.white,
      ),
      // Use a Stack to layer the background and the form content
      body: Stack(
        children: [
          // 1. Background Image Container
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image:
                    AssetImage("assets/login.jpg"), // 👈 Your background image
                fit: BoxFit.cover, // Fills the entire screen
              ),
            ),
          ),

          // 2. Form Content (wrapped in a semi-transparent card container)
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9), // Semi-transparent card
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Create Account",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff6200ee),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Email
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                          labelText: "Email", prefixIcon: Icon(Icons.email)),
                    ),
                    const SizedBox(height: 12),

                    // Password
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                          labelText: "Password", prefixIcon: Icon(Icons.lock)),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),

                    // Full Name
                    TextField(
                      controller: fullNameController,
                      decoration: const InputDecoration(
                          labelText: "Full Name",
                          prefixIcon: Icon(Icons.person)),
                    ),
                    const SizedBox(height: 12),

                    // Username
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                          labelText: "Username",
                          prefixIcon: Icon(Icons.person_pin)),
                    ),
                    const SizedBox(height: 16),

                    // Role Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        labelText: "Role",
                        prefixIcon: Icon(Icons.group),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: "tourist", child: Text("Tourist")),
                        DropdownMenuItem(
                            value: "guide", child: Text("Tour Guide")),
                        DropdownMenuItem(value: "admin", child: Text("Admin")),
                        DropdownMenuItem(
                            value: "instructor",
                            child: Text("Activity Instructor")),
                        DropdownMenuItem(
                            value: "advertiser", child: Text("Advertiser")),
                        // 👇 Add these two new roles
                        DropdownMenuItem(
                            value: "influencer", child: Text("Influencer")),
                        DropdownMenuItem(
                            value: "company", child: Text("Tour Company")),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedRole = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // Register Button (Styled)
                    ElevatedButton(
                      onPressed: _isLoading ? null : register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xff6200ee), // 🔹 button color
                        foregroundColor: Colors.white, // 🔹 text/icon color
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12), // 🔹 rounded corners
                        ),
                        elevation: 4, // 🔹 shadow
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              "Register",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
