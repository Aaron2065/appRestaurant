import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestion_alimentos/providers/auth_provider.dart';

class MeseroView extends StatefulWidget {
  @override
  _MeseroViewState createState() => _MeseroViewState();
}

class _MeseroViewState extends State<MeseroView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<int> _mesasAsignadas = [];
  String? _comandaId;
  final Map<String, dynamic> _pedido = {};

  static const Map<String, Color> _estadoColores = {
    'libre': Colors.green,
    'asignada': Colors.orange,
    'pedido': Colors.blue,
    'comiendo': Colors.red,
    'limpieza': Colors.grey,
  };

  static const Map<String, List<String>> _productosPorCategoria = {
    'Comida': [
      'Empanada de queso con chorizo',
      'Empanada hawaiana',
      'Empanada de pepperoni',
      'Baguette de pollo',
      'Orden de nachos',
    ],
    'Postres': ['Brownie con helado', 'Crepas'],
    'Bebidas': [
      'Piñada',
      'Malteadas',
      'Frappés',
      'Limonada',
      'Refrescos',
    ],
  };

  @override
  void initState() {
    super.initState();
    _obtenerMesasAsignadas();
  }

  void _obtenerMesasAsignadas() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.usuario?.uid;

    if (uid != null) {
      final snapshot = await _firestore
          .collection('meseros')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        setState(() {
          _mesasAsignadas = List<int>.from(doc['mesas']);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('Mesero'),
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
        stream: _mesasAsignadas.isEmpty
            ? null
            : _firestore
                .collection('mesas')
                .where('numero', whereIn: _mesasAsignadas)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final mesas = snapshot.data!.docs;

          return ListView.builder(
            itemCount: mesas.length,
            itemBuilder: (context, index) {
              final mesa = mesas[index].data() as Map<String, dynamic>;
              final numero = mesa['numero'] as int;
              final estado = mesa['estado'] as String;

              return StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('pedidos')
                    .where('comandaId', isEqualTo: mesa['comandaId'])
                    .where('estado', isEqualTo: 'completado')
                    .snapshots(),
                builder: (context, pedidoSnapshot) {
                  bool mostrarBoton = pedidoSnapshot.hasData &&
                      pedidoSnapshot.data!.docs.isNotEmpty;

                  return ListTile(
                    title: Text('Mesa $numero'),
                    subtitle: Text('Estado: $estado'),
                    tileColor: _estadoColores[estado] ?? Colors.white,
                    trailing: mostrarBoton
                        ? IconButton(
                            icon: Icon(Icons.fastfood),
                            onPressed: () {
                              _cambiarEstadoMesa(numero);
                            },
                          )
                        : null,
                    onTap: () {
                      if (['asignada', 'pedido', 'comiendo'].contains(estado)) {
                        setState(() {
                          _comandaId = mesa['comandaId'] as String?;
                        });
                        _mostrarDialogoPedido(context, numero);
                      }
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _cambiarEstadoMesa(int numeroMesa) async {
    try {
      final pedidosSnapshot = await _firestore
          .collection('pedidos')
          .where('comandaId', isEqualTo: _comandaId)
          .get();

      double precioFinalTotal = 0.0;
      final List<Map<String, dynamic>> itemsParaMesa = [];

      for (var pedidoDoc in pedidosSnapshot.docs) {
        final pedidoData = pedidoDoc.data();
        final items =
            List<Map<String, dynamic>>.from(pedidoData['items'] ?? []);
        precioFinalTotal += pedidoData['precioFinal'] ?? 0.0;
        itemsParaMesa.addAll(items);

        await _firestore.collection('pedidos').doc(pedidoDoc.id).delete();
      }

      await _firestore.collection('mesas').doc(numeroMesa.toString()).update({
        'pedidos': itemsParaMesa,
        'precioFinal': precioFinalTotal,
        'estado': 'comiendo',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Estado de la mesa cambiado a "comiendo"')),
      );
    } catch (e) {
      print('Error al cambiar el estado de la mesa: $e');
    }
  }

  void _mostrarDialogoPedido(BuildContext context, int numeroMesa) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Tomar Pedido - Mesa $numeroMesa'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _productosPorCategoria.entries.map((entry) {
                    return _crearListaDeProductos(
                        entry.key, entry.value, setState);
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _mostrarDialogoConfirmacion(context, numeroMesa);
                  },
                  child: Text('Enviar Pedido'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _mostrarDialogoConfirmacion(BuildContext context, int numeroMesa) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirmar Pedido'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _pedido.entries.map((entry) {
              final producto = entry.key;
              final cantidad = entry.value['cantidad'];
              final opciones = entry.value['opciones'];
              final precio = entry.value['precio'];
              return Text(
                  '$producto - Cantidad: $cantidad - Precio: \$${precio.toStringAsFixed(2)}');
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _enviarPedido(numeroMesa);
                Navigator.of(context).pop();
              },
              child: Text('Aceptar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  Widget _crearListaDeProductos(String categoria, List<String> productos,
      void Function(void Function()) setState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: productos.map((producto) {
        int cantidad =
            _pedido.containsKey(producto) ? _pedido[producto]['cantidad'] : 1;
        double precioUnitario = _obtenerPrecioProducto(producto);
        return Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                  title: Text(
                      '$producto - \$${precioUnitario.toStringAsFixed(2)}'),
                  value: _pedido.containsKey(producto),
                  onChanged: (bool? valor) {
                    setState(() {
                      if (valor == true) {
                        if (_productoTieneOpciones(producto)) {
                          _mostrarDialogoDeOpciones(context, producto,
                              (opcionesSeleccionadas) {
                            setState(() {
                              _pedido[producto] = {
                                'cantidad': cantidad,
                                'opciones': opcionesSeleccionadas,
                                'precio': cantidad * precioUnitario
                              };
                            });
                          });
                        } else {
                          _pedido[producto] = {
                            'cantidad': cantidad,
                            'opciones': {},
                            'precio': cantidad * precioUnitario
                          };
                        }
                      } else {
                        _pedido.remove(producto);
                      }
                    });
                  }),
            ),
            if (_pedido.containsKey(producto))
              IconButton(
                icon: Icon(Icons.remove),
                onPressed: () {
                  setState(() {
                    if (cantidad > 1) {
                      cantidad--;
                      _pedido[producto]['cantidad'] = cantidad;
                      _pedido[producto]['precio'] = cantidad * precioUnitario;
                    }
                  });
                },
              ),
            if (_pedido.containsKey(producto)) Text(cantidad.toString()),
            if (_pedido.containsKey(producto))
              IconButton(
                icon: Icon(Icons.add),
                onPressed: () {
                  setState(() {
                    cantidad++;
                    _pedido[producto]['cantidad'] = cantidad;
                    _pedido[producto]['precio'] = cantidad * precioUnitario;
                  });
                },
              ),
          ],
        );
      }).toList(),
    );
  }

  void _enviarPedido(int numeroMesa) async {
    if (_comandaId == null || _pedido.isEmpty) return;

    try {
      final pedidoExistente = await _firestore
          .collection('pedidos')
          .where('comandaId', isEqualTo: _comandaId)
          .limit(1)
          .get();

      double nuevoPrecioFinal = _pedido.entries.fold(0.0, (total, entry) {
        return total + entry.value['precio'];
      });

      if (pedidoExistente.docs.isNotEmpty) {
        final docId = pedidoExistente.docs.first.id;
        final pedidoExistenteData = pedidoExistente.docs.first.data();
        final itemsActuales =
            List<Map<String, dynamic>>.from(pedidoExistenteData['items']);

        double precioFinalExistente = pedidoExistenteData['precioFinal'] ?? 0.0;

        _pedido.forEach((producto, opciones) {
          itemsActuales.add({
            'producto': producto,
            'cantidad': opciones['cantidad'],
            'opciones': opciones['opciones'],
            'precio': opciones['precio'],
          });
        });

        double precioFinalActualizado = precioFinalExistente + nuevoPrecioFinal;

        await _firestore.collection('pedidos').doc(docId).update({
          'items': itemsActuales,
          'precioFinal': precioFinalActualizado,
        });

        await _firestore.collection('pedidos').doc(docId).update({
          'estado': 'pendiente',
        });
      } else {
        await _firestore.collection('pedidos').add({
          'comandaId': _comandaId,
          'estado': 'pendiente',
          'items': _pedido.entries.map((entry) {
            return {
              'producto': entry.key,
              'cantidad': entry.value['cantidad'],
              'opciones': entry.value['opciones'],
              'precio': entry.value['precio'],
            };
          }).toList(),
          'precioFinal': nuevoPrecioFinal,
          'fecha': DateTime.now().toIso8601String(),
        });
      }

      await _firestore.collection('mesas').doc(numeroMesa.toString()).update({
        'estado': 'pedido',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pedido enviado con éxito')),
      );
    } catch (e) {
      print('Error al enviar el pedido: $e');
    }
  }

  double _obtenerPrecioProducto(String producto) {
    switch (producto) {
      case 'Piñada':
      case 'Malteadas':
      case 'Frappe de oreo':
        return 60.0;
      case 'Frappe de moka':
        return 55.0;
      case 'Limonada':
        return 35.0;
      case 'Refrescos':
        return 25.0;
      case 'Empanada de queso con chorizo':
      case 'Empanada hawaiana':
      case 'Empanada de pepperoni':
      case 'Orden de nachos':
        return 45.0;
      case 'Baguette de pollo':
        return 65.0;
      case 'Brownie con helado':
        return 35.0;
      case 'Crepas':
        return 50.0;
      default:
        return 55;
    }
  }

  bool _productoTieneOpciones(String producto) {
    return ['Baguette de pollo', 'Crepas', 'Malteadas', 'Frappés', 'Refrescos']
        .contains(producto);
  }

  void _mostrarDialogoDeOpciones(BuildContext context, String producto,
      Function(Map<String, dynamic>) onOpcionesSeleccionadas) {
    final opciones = _obtenerOpcionesPorProducto(producto);
    final seleccionadas = <String, dynamic>{};

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Opciones para $producto'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: opciones.keys.map((opcion) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(opcion),
                        Column(
                          children: opciones[opcion]!.map<Widget>((elemento) {
                            return CheckboxListTile(
                              title: Text(elemento),
                              value: seleccionadas[opcion] == elemento,
                              onChanged: (valor) {
                                setState(() {
                                  if (valor == true) {
                                    seleccionadas[opcion] = elemento;
                                  } else {
                                    if (seleccionadas[opcion] == elemento) {
                                      seleccionadas.remove(opcion);
                                    }
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    onOpcionesSeleccionadas(
                        Map<String, dynamic>.from(seleccionadas));
                    Navigator.of(context).pop();
                  },
                  child: Text('Aceptar'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Map<String, List<String>> _obtenerOpcionesPorProducto(String producto) {
    switch (producto) {
      case 'Baguette de pollo':
        return {
          'Aderezos': ['Mayonesa', 'Chipotle', 'César'],
        };
      case 'Crepas':
        return {
          'Base': ['Nutella', 'Lechera'],
          'Fruta': ['Plátano', 'Fresa', 'Philadelphia'],
        };
      case 'Malteadas':
        return {
          'Sabor': ['Fresa', 'Vainilla', 'Chocolate'],
          'Tipo de leche': ['Entera', 'Deslactosada'],
          'Extras': ['Chocolate líquido', 'Crema batida'],
        };
      case 'Frappés':
        return {
          'Sabor': ['Moka', 'Café', 'Oreo'],
          'Tipo de leche': ['Entera', 'Deslactosada'],
          'Extras': ['Chocolate líquido', 'Crema batida'],
        };
      case 'Refrescos':
        return {
          'Sabor': ['Coca Cola', 'Coca Cola Light', 'Manzana', 'Sprite'],
        };
      default:
        return {};
    }
  }
}
