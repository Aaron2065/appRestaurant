import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gestion_alimentos/providers/auth_provider.dart';
import 'package:gestion_alimentos/themes/app_theme.dart'; // Importa el archivo del tema

class LoginView extends StatelessWidget {
  final TextEditingController _controladorCorreo = TextEditingController();
  final TextEditingController _controladorContrasenia = TextEditingController();

  void login(BuildContext contexto) async {
    final correo = _controladorCorreo.text;
    final contrasenia = _controladorContrasenia.text;

    try {
      final proveedorAuth = Provider.of<AuthProvider>(contexto, listen: false);
      await proveedorAuth.iniciarSesion(correo, contrasenia);

      if (proveedorAuth.usuario != null) {
        Navigator.pushReplacementNamed(contexto, '/');
      } else {
        mostrarSnackBar(contexto, 'Error de autenticación.');
      }
    } catch (e) {
      mostrarSnackBar(contexto, 'Error de autenticación: $e');
    }
  }

  void mostrarSnackBar(BuildContext contexto, String mensaje) {
    ScaffoldMessenger.of(contexto).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  @override
  Widget build(BuildContext contexto) {
    return MaterialApp(
      theme: AppTheme.themeData,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Iniciar sesion'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  construirCampoTexto(
                    controlador: _controladorCorreo,
                    etiqueta: 'Correo',
                  ),
                  const SizedBox(height: 16.0),
                  construirCampoTexto(
                    controlador: _controladorContrasenia,
                    etiqueta: 'Contraseña',
                    ocultarTexto: true,
                  ),
                  const SizedBox(height: 20.0),
                  SizedBox(
                    width: double.maxFinite,
                    child: ElevatedButton(
                      onPressed: () => login(contexto),
                      child: const Text('Iniciar sesion'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget construirCampoTexto({
    required TextEditingController controlador,
    required String etiqueta,
    bool ocultarTexto = false,
  }) {
    return TextField(
      controller: controlador,
      obscureText: ocultarTexto,
      decoration: InputDecoration(
        labelText: etiqueta,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
