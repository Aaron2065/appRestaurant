import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestion_alimentos/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class CajaView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caja'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authProvider.cerrarSesion();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ventas')
            .where('estatus', isEqualTo: 'en proceso')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final ventas = snapshot.data!.docs;

          return ListView.builder(
            itemCount: ventas.length,
            itemBuilder: (context, index) {
              final venta = ventas[index];
              final numeroMesa = venta['numeroMesa'];
              final nombreCliente = venta['nombreCliente'];
              final total = venta['total'];

              return Card(
                child: ListTile(
                  title: Text('Mesa $numeroMesa - $nombreCliente'),
                  subtitle: Text('Total: \$${total.toStringAsFixed(2)}'),
                  trailing: ElevatedButton(
                    onPressed: () => finalizarVenta(context, venta),
                    child: Text('Cobrar'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Método para finalizar la venta y actualizar el estado
  Future<void> finalizarVenta(
      BuildContext context, QueryDocumentSnapshot venta) async {
    try {
      // Actualizar el estatus de la venta a "realizada"
      await FirebaseFirestore.instance
          .collection('ventas')
          .doc(venta.id)
          .update({'estatus': 'realizada'});

      // Obtener el número de mesa para actualizar su estado
      final numeroMesa = venta['numeroMesa'];

      // Buscar la mesa correspondiente y actualizar su estado a "sucia"
      final mesaSnapshot = await FirebaseFirestore.instance
          .collection('mesas')
          .where('numero', isEqualTo: numeroMesa)
          .limit(1)
          .get();

      if (mesaSnapshot.docs.isNotEmpty) {
        final mesaId = mesaSnapshot.docs.first.id;

        await FirebaseFirestore.instance
            .collection('mesas')
            .doc(mesaId)
            .update({
          'estado': 'limpieza',
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Venta finalizada y mesa marcada como "limpieza"')),
        );
      }
    } catch (e) {
      print('Error al finalizar la venta: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al finalizar la venta')),
      );
    }
  }
}
