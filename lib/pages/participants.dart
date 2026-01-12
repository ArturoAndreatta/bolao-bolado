import 'package:bolao_bolado/components/Default/default_layout.dart';
import 'package:bolao_bolado/components/back_screen_button.dart';
import 'package:bolao_bolado/components/participants_table.dart';
import 'package:bolao_bolado/models/bet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:bolao_bolado/components/logo.dart';

class Participants extends StatefulWidget {
  const Participants({super.key});

  @override
  State<Participants> createState() => _ParticipantsState();
}

class _ParticipantsState extends State<Participants> {
  FirebaseFirestore firestore = .instance;
  List<Map<String, dynamic>> _rowsData = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final dataBets = await getBets();
    setState(() {
      _rowsData = dataBets;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final heightTable = (height * 0.45).clamp(260.0, 420.0);
    const widthNome = 140.0;
    const widthValor = 70.0;
    const widthCotas = 60.0;
    const widthPremio = 90.0;

    return DefaultLayout(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 572),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Stack(
            children: [
              Card(
                elevation: 20,
                color: Color(0xFFFEFEFE),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Logo(),
                      SizedBox(height: 20),
                      SizedBox(
                        height: heightTable,
                        child: _loading
                            ? Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 5,
                                  color: Color(0xFF7CC8B5),
                                ),
                              )
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: ParticipantsTable(
                                    loading: _loading,
                                    heightTable: heightTable,
                                    widthNome: widthNome,
                                    widthValor: widthValor,
                                    widthCotas: widthCotas,
                                    widthPremio: widthPremio,
                                    rowsData: _rowsData,
                                  ),
                                ),
                              ),
                      ),
                      SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
              BackScreenButton(),
            ],
          ),
        ),
      ),
    );
  }
}
