import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gestion_alimentos/providers/auth_provider.dart' as local_auth;
import 'package:gestion_alimentos/views/login_view.dart';
import 'package:gestion_alimentos/views/roles/host_view.dart';
import 'package:gestion_alimentos/views/roles/mesero_view.dart';
import 'package:gestion_alimentos/views/roles/cocina_view.dart';
import 'package:gestion_alimentos/views/roles/corredor_view.dart';
import 'package:gestion_alimentos/views/roles/caja_view.dart';
import 'package:gestion_alimentos/views/roles/administrador_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCN78nGT2Z1tWvebdfaIOkd192jvQMx8fM",
      authDomain: "db-gestion-alimentos.firebaseapp.com",
      projectId: "db-gestion-alimentos",
      storageBucket: "db-gestion-alimentos.appspot.com",
      messagingSenderId: "964960934583",
      appId: "1:964960934583:web:935986a502e70309bb4b32",
      measurementId: "G-8L5KG4JTYF",
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => local_auth.AuthProvider(),
      child: MaterialApp(
        title: 'Administración de Alimentos',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: Consumer<local_auth.AuthProvider>(
          builder: (context, authProvider, _) {
            if (authProvider.usuario == null) {
              return LoginView();
            } else {
              return FutureBuilder<String>(
                future: getUsuarioRol(authProvider.usuario!.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasData) {
                    return _buildRoleView(snapshot.data!);
                  } else {
                    return LoginView();
                  }
                },
              );
            }
          },
        ),
        debugShowCheckedModeBanner: false,
        routes: {
          '/login': (context) => LoginView(),
        },
      ),
    );
  }

  Widget _buildRoleView(String rol) {
    switch (rol) {
      case 'host':
        return HostView();
      case 'mesero':
        return MeseroView();
      case 'cocina':
        return CocinaView();
      case 'corredor':
        return CorredorView();
      case 'caja':
        return CajaView();
      case 'administrador':
        return AdministradorView();
      default:
        return LoginView();
    }
  }

  Future<String> getUsuarioRol(String uid) async {
    try {
      final usuario = FirebaseAuth.instance.currentUser;
      final email = usuario?.email;

      if (email == null) {
        throw Exception('No se encontró el correo electrónico del usuario.');
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('correo', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first['rol'];
      } else {
        throw Exception('No se encontró el usuario en la base de datos.');
      }
    } catch (e) {
      print('Error al obtener el rol del usuario: $e');
      return '';
    }
  }
}
