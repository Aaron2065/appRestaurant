import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestion_alimentos/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class HostView extends StatelessWidget {
  @override
  Widget build(BuildContext contexto) {
    final proveedorAuth = Provider.of<AuthProvider>(contexto, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesero'),
        actions: <Widget>[
          botonCerrarSesion(proveedorAuth, contexto),
        ],
      ),
      body: cuerpo(),
    );
  }

  Widget botonCerrarSesion(AuthProvider proveedorAuth, BuildContext contexto) {
    return IconButton(
      icon: const Icon(Icons.logout),
      onPressed: () {
        proveedorAuth.cerrarSesion();
        Navigator.of(contexto).pushReplacementNamed('/login');
      },
    );
  }

  Widget cuerpo() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('mesas')
          .orderBy('numero')
          .snapshots(),
      builder: (contexto, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final mesas = snapshot.data!.docs;

        return grid(mesas, contexto);
      },
    );
  }

  Widget grid(List<QueryDocumentSnapshot> mesas, BuildContext contexto) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1,
      ),
      itemCount: mesas.length,
      itemBuilder: (contexto, index) {
        final mesa = mesas[index];
        final numeroMesa = mesa['numero'];
        final estado = mesa['estado'];

        return iconoMesa(mesa, numeroMesa, estado, contexto);
      },
    );
  }

  Widget iconoMesa(QueryDocumentSnapshot mesa, int numeroMesa, String estado,
      BuildContext contexto) {
    return GestureDetector(
      onTap: () => tapMesa(contexto, mesa),
      child: Container(
        margin: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: colorPorEstado(estado),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(
            Icons.table_chart,
            color: Colors.white,
            size: 50.0, // Tamaño del ícono
          ),
        ),
      ),
    );
  }

  void tapMesa(BuildContext contexto, QueryDocumentSnapshot mesa) {
    final estado = mesa['estado'];

    if (estado == 'libre') {
      asignarMesa(contexto, mesa.id);
    } else if (estado == 'comiendo') {
      pedirCuenta(contexto, mesa);
    }
  }

  void pedirCuenta(BuildContext contexto, QueryDocumentSnapshot mesa) {
    showDialog(
      context: contexto,
      builder: (contexto) {
        return AlertDialog(
          title: const Text('Pedir la cuenta'),
          content: const Text('¿Desea pedir la cuenta?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(contexto).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => nombreCliente(contexto, mesa),
              child: const Text('Sí'),
            ),
          ],
        );
      },
    );
  }

  Future<void> nombreCliente(
      BuildContext contexto, QueryDocumentSnapshot mesa) async {
    final TextEditingController controladorNombre = TextEditingController();

    await showDialog(
      context: contexto,
      builder: (contexto) {
        return AlertDialog(
          title: const Text('Confirmar Cliente'),
          content: TextField(
            controller: controladorNombre,
            decoration: const InputDecoration(labelText: 'Nombre del Cliente'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(contexto).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                final nombreCliente = controladorNombre.text;
                if (nombreCliente == mesa['nombreCliente']) {
                  await procesarVenta(contexto, mesa);
                  Navigator.of(contexto).pop();
                } else {
                  ScaffoldMessenger.of(contexto).showSnackBar(
                    const SnackBar(content: Text('Nombre incorrecto')),
                  );
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> procesarVenta(
      BuildContext contexto, QueryDocumentSnapshot mesa) async {
    try {
      final datosMesa = mesa.data() as Map<String, dynamic>;

      final Map<String, dynamic> datosVenta = {
        'numeroMesa': mesa['numero'],
        'estatus': 'en proceso',
        'nombreCliente': datosMesa['nombreCliente'],
        'timestamp': FieldValue.serverTimestamp(),
        'total': datosMesa['precioFinal'] ?? 0.0,
        'detalles': (datosMesa['pedidos'] as List<dynamic>).map((pedido) {
          return {
            'producto': pedido['producto'],
            'cantidad': pedido['cantidad'],
            'precio': pedido['precio'],
          };
        }).toList(),
      };

      await FirebaseFirestore.instance.collection('ventas').add(datosVenta);

      await FirebaseFirestore.instance.collection('mesas').doc(mesa.id).update({
        'estado': 'cobrando',
        'pedidos': [],
        'precioFinal': FieldValue.delete(),
        'nombreCliente': '',
      });

      ScaffoldMessenger.of(contexto).showSnackBar(
        const SnackBar(
            content: Text('Venta procesada y mesa marcada como "cobrando"')),
      );
    } catch (e) {
      print('Error al procesar la venta: $e');
      ScaffoldMessenger.of(contexto).showSnackBar(
        const SnackBar(content: Text('Error al procesar la venta')),
      );
    }
  }

  void asignarMesa(BuildContext contexto, String idMesa) async {
    final TextEditingController controladorNombre = TextEditingController();

    showDialog(
      context: contexto,
      builder: (contexto) {
        return AlertDialog(
          title: const Text('Asignar mesa'),
          content: TextField(
            controller: controladorNombre,
            decoration: const InputDecoration(labelText: 'Nombre del cliente'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(contexto).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                final nombreCliente = controladorNombre.text;
                if (nombreCliente.isNotEmpty) {
                  final proximoComandaId = await comandaId();
                  if (proximoComandaId != null) {
                    await FirebaseFirestore.instance
                        .collection('mesas')
                        .doc(idMesa)
                        .update({
                      'estado': 'asignada',
                      'nombreCliente': nombreCliente,
                      'comandaId': proximoComandaId.toString(),
                    });

                    Navigator.of(contexto).pop();
                  } else {
                    ScaffoldMessenger.of(contexto).showSnackBar(
                      const SnackBar(
                          content: Text('No hay comandaId disponible')),
                    );
                  }
                }
              },
              child: const Text('Asignar'),
            ),
          ],
        );
      },
    );
  }

  Future<int?> comandaId() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('mesas')
        .where('comandaId', isNotEqualTo: '')
        .get();

    final idsOcupados = snapshot.docs
        .map((doc) => int.tryParse(doc['comandaId']) ?? 0)
        .toList();

    for (int i = 1; i <= 20; i++) {
      if (!idsOcupados.contains(i)) {
        return i;
      }
    }

    return null;
  }

  Color colorPorEstado(String estado) {
    switch (estado) {
      case 'libre':
        return Colors.green;
      case 'asignada':
        return Colors.orange;
      case 'pedido':
        return Colors.blue;
      case 'comiendo':
        return Colors.red;
      case 'cobrando':
        return Colors.purple;
      case 'limpieza':
        return Colors.grey;
      default:
        return Colors.green;
    }
  }
}
