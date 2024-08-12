import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestion_alimentos/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class CorredorView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('Corredor - Mesas Asignadas'),
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('corredores')
            .doc(authProvider.usuario?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final corredorData = snapshot.data!.data() as Map<String, dynamic>;
          final mesasAsignadas = corredorData['mesas'];

          return ListView.builder(
            itemCount: mesasAsignadas.length,
            itemBuilder: (context, index) {
              final numeroMesa = mesasAsignadas[index];

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('mesas')
                    .where('numero', isEqualTo: numeroMesa)
                    .where('estado', isEqualTo: 'limpieza')
                    .snapshots(),
                builder: (context, mesaSnapshot) {
                  if (!mesaSnapshot.hasData ||
                      mesaSnapshot.data!.docs.isEmpty) {
                    return SizedBox.shrink();
                  }

                  final mesaData = mesaSnapshot.data!.docs.first.data()
                      as Map<String, dynamic>;
                  final mesaId = mesaSnapshot.data!.docs.first.id;

                  return Card(
                    child: ListTile(
                      title: Text('Mesa ${mesaData['numero']}'),
                      subtitle: Text('Estado: ${mesaData['estado']}'),
                      trailing: ElevatedButton(
                        onPressed: () => limpiarMesa(context, mesaId),
                        child: Text('Marcar como Libre'),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> limpiarMesa(BuildContext context, String mesaId) async {
    try {
      await FirebaseFirestore.instance.collection('mesas').doc(mesaId).update({
        'estado': 'libre',
        'comandaId': '',
        'nombreCliente': '',
        'pedidos': [],
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesa marcada como libre')),
      );
    } catch (e) {
      print('Error al limpiar la mesa: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al limpiar la mesa')),
      );
    }
  }
}
