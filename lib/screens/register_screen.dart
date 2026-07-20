import 'package:flutter/material.dart';

import '../core/network_info.dart';
import '../main.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;
  String error = '';

  void _showRegisterError(String message) {
    setState(() => error = message);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ============================================================================
  // REGISTER
  // ============================================================================
  Future<void> register() async {
    FocusScope.of(context).unfocus();

    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword =
    confirmPasswordController.text.trim();

    // ============================================================================
    // VALIDATION
    // ============================================================================
    if (email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() {
        error = "Preenche todos os campos";
      });

      return;
    }

    if (!email.contains("@")) {
      setState(() {
        error = "Email inválido";
      });

      return;
    }

    if (password.length < 6) {
      setState(() {
        error = "Password demasiado curta";
      });

      return;
    }

    if (password != confirmPassword) {
      setState(() {
        error = "As passwords não coincidem";
      });

      return;
    }

    // ============================================================================
    // LOADING
    // ============================================================================
    setState(() {
      isLoading = true;
      error = '';
    });

    try {
      final registered = await authService.register(
        email: email,
        password: password,
      );

      if (!registered) {
        _showRegisterError(
          'Não foi possível criar conta. Email já registado ou erro no servidor.',
        );
        return;
      }

      final loggedIn = await authService.login(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (loggedIn) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const HomePage(),
          ),
          (route) => false,
        );
      } else {
        _showRegisterError('Conta criada mas login falhou. Tenta entrar manualmente.');
      }
    } on NoInternetException {
      _showRegisterError(
        'Sem ligação ou timeout. Verifica a rede e tenta novamente.',
      );
    } catch (e) {
      _showRegisterError('Erro ao criar conta. Tenta novamente.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ============================================================================
  // INPUT DESIGN
  // ============================================================================
  InputDecoration inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,

      labelText: label,

      prefixIcon: Icon(icon),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Color(0xFFFF7043),
          width: 2,
        ),
      ),

      contentPadding: const EdgeInsets.all(20),
    );
  }

  // ============================================================================
  // UI
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F3),

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,

              children: [
                const Icon(
                  Icons.person_add,
                  size: 90,
                  color: Color(0xFFFF7043),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Criar Conta",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  "Começa já a guardar receitas favoritas 🔥",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 40),

                // EMAIL
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,

                  decoration: inputDecoration(
                    label: "Email",
                    icon: Icons.email,
                  ),
                ),

                const SizedBox(height: 20),

                // PASSWORD
                TextField(
                  controller: passwordController,
                  obscureText: true,

                  decoration: inputDecoration(
                    label: "Password",
                    icon: Icons.lock,
                  ),
                ),

                const SizedBox(height: 20),

                // CONFIRM PASSWORD
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,

                  decoration: inputDecoration(
                    label: "Confirmar password",
                    icon: Icons.lock_outline,
                  ),
                ),

                const SizedBox(height: 30),

                // BUTTON
                ElevatedButton(
                  onPressed: isLoading ? null : register,

                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(
                      double.infinity,
                      55,
                    ),
                  ),

                  child: isLoading
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    "Criar Conta",
                    style: TextStyle(fontSize: 18),
                  ),
                ),

                // ERROR
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 20),

                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.red,
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                // LOGIN REDIRECT
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Já tens conta?"),

                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                            const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text("Entrar"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
