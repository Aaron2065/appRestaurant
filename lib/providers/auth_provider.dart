import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _usuario;
  User? get usuario => _usuario;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _usuario = user;
      print('Usuario autenticado: $_usuario');
      notifyListeners();
    });
  }

  Future<void> iniciarSesion(String correo, String contrasenia) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: correo,
        password: contrasenia,
      );
    } catch (e) {
      throw e;
    }
  }

  Future<void> cerrarSesion() async {
    await _auth.signOut();
  }
}
