import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shared/custom_fields.dart';
import 'package:bolao_bolado/components/shared/skeletons.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/components/shared/header_paginas.dart';
import 'package:bolao_bolado/core/app_radii.dart';
import 'package:bolao_bolado/models/sala.dart';
import 'package:bolao_bolado/router/app_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ConsultarSalas extends StatefulWidget {
  const ConsultarSalas({super.key});

  @override
  State<ConsultarSalas> createState() => _ConsultarSalasState();
}

class _ConsultarSalasState extends State<ConsultarSalas> {
  final FirebaseFirestore _firestore = .instance;
  final TextEditingController _buscaController = .new();

  List<Sala> _salas = [];
  List<Sala> _salasFiltradas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carregarSalas();
    _buscaController.addListener(_filtrar);
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregarSalas() async {
    setState(() => _loading = true);
    final snapshot = await _firestore.collection('Salas').get();
    final salas = snapshot.docs.map((doc) => Sala.fromDoc(doc)).toList();
    setState(() {
      _salas = salas;
      _salasFiltradas = salas;
      _loading = false;
    });
  }

  // Filtro é feito em memória sobre a lista já carregada (sem nova query ao Firestore),
  // pois a base de salas tende a ser pequena e a busca precisa responder a cada tecla digitada.
  void _filtrar() {
    final busca = _buscaController.text.trim().toLowerCase();
    setState(() {
      _salasFiltradas = busca.isEmpty
          ? _salas
          : _salas.where((s) => s.nome.toLowerCase().contains(busca)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final altura = MediaQuery.of(context).size.height;
    // Limita a altura da lista a uma faixa razoável para não estourar em telas pequenas
    // nem ficar desproporcional em telas grandes.
    final alturaLista = (altura * 0.5).clamp(260.0, 500.0);

    return DefaultLayout(
      drawer: AppDrawer(),
      child: Stack(
        children: [
          CustomCard(
            color: Color(0xFFF3F1EF),
            children: [
              HeaderPaginas(
                text: 'Consultar Salas',
                subtitle: 'Veja e acompanhe as salas que você participa',
              ),
              CustomCard(
                isChild: true,
                children: [
                  SizedBox(height: 20),
                  CustomField(
                    hint: 'Buscar por nome',
                    icon: Icons.search,
                    controller: _buscaController,
                    maxWidth: 600,
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    height: alturaLista,
                    child: _ListaSalas(
                      loading: _loading,
                      salas: _salasFiltradas,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Corpo da lista de salas: alterna entre skeleton (carregando), mensagem
// de vazio (sem salas ou busca sem resultado) e a lista real.
class _ListaSalas extends StatelessWidget {
  final bool loading;
  final List<Sala> salas;

  const _ListaSalas({required this.loading, required this.salas});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SingleChildScrollView(child: SkeletonListaSalas());
    }
    if (salas.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma sala encontrada.',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }
    return ListView.builder(
      itemCount: salas.length,
      itemBuilder: (context, index) => _SalaCard(sala: salas[index]),
    );
  }
}

class _SalaCard extends StatelessWidget {
  final Sala sala;
  const _SalaCard({required this.sala});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: AppRadii.circularMd,
        onTap: () => context.go(AppRoutes.salaDetalhes, extra: sala),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Color(0xFFFEFEFE),
            borderRadius: AppRadii.circularMd,
            border: Border.all(color: Color(0xFFDDDDDD), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sala.nome,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    if (sala.descricao.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        sala.descricao,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
