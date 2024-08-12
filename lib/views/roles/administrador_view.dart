import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestion_alimentos/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class AdministradorView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text('Administrador'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              authProvider.cerrarSesion();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final usuarios = snapshot.data!.docs;

          return ListView.builder(
            itemCount: usuarios.length,
            itemBuilder: (context, index) {
              final usuario = usuarios[index];
              final rol = usuario['rol'];
              final correo = usuario['correo'];

              return Card(
                child: ListTile(
                  title: Text('$rol - $correo'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () {
                          _mostrarDialogousuario(context, usuario: usuario);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          _eliminarusuario(usuario.id);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _mostrarDialogousuario(BuildContext context,
      {QueryDocumentSnapshot? usuario}) async {
    final rolController = TextEditingController(text: usuario?.get('rol'));
    final correoController =
        TextEditingController(text: usuario?.get('correo'));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(usuario != null ? 'Editar usuario' : 'Agregar usuario'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: rolController,
                decoration: InputDecoration(labelText: 'Rol'),
              ),
              TextField(
                controller: correoController,
                decoration: InputDecoration(labelText: 'correo'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final datosusuario = {
                  'rol': rolController.text,
                  'correo': correoController.text,
                  'activo': true,
                };

                if (usuario == null) {
                  FirebaseFirestore.instance
                      .collection('usuarios')
                      .add(datosusuario);
                } else {
                  FirebaseFirestore.instance
                      .collection('usuarios')
                      .doc(usuario.id)
                      .update(datosusuario);
                }

                Navigator.of(context).pop();
              },
              child: Text(usuario != null ? 'Actualizar' : 'Agregar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _eliminarusuario(String usuarioId) async {
    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(usuarioId)
        .delete();
  }
}
