import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:gestion_alimentos/providers/auth_provider.dart';

class CocinaView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('Cocina'),
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
        stream: FirebaseFirestore.instance
            .collection('pedidos')
            .where('estado', isEqualTo: 'pendiente')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final pedidos = snapshot.data!.docs;

          return ListView.builder(
            itemCount: pedidos.length,
            itemBuilder: (context, index) {
              final pedido = pedidos[index].data() as Map<String, dynamic>;
              final comandaId = pedido['comandaId'] as String;
              final items = pedido['items'] as List<dynamic>;

              return Card(
                child: ListTile(
                  title: Text('Comanda ID: $comandaId'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: items.map((item) {
                      return Text(
                          '${item['producto']} - Cantidad: ${item['cantidad']} - Precio: \$${item['precio']}');
                    }).toList(),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () async {
                      // Marca el pedido como completado
                      await FirebaseFirestore.instance
                          .collection('pedidos')
                          .doc(pedidos[index].id)
                          .update({
                        'estado': 'completado',
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Pedido marcado como completado')),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
