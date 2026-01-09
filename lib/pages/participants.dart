import 'package:bolao_bolado/components/back_screen_button.dart';
import 'package:bolao_bolado/components/gradient_decoration.dart';
import 'package:bolao_bolado/components/participants_table.dart';
import 'package:bolao_bolado/models/bet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:bolao_bolado/components/footer.dart';
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

    return Container(
      decoration: GradientDecoration.backgroundGradient(),
      child: Scaffold(
        bottomNavigationBar: Footer(),
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            padding: EdgeInsets.fromLTRB(0, 20, 0, 0),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 520),
                child: Stack(
                  children: [
                    Card(
                      elevation: 20,
                      color: Color(0xFFFEFEFE),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Logo(),
                          SizedBox(height: 20),
                          SizedBox(
                            height: heightTable,
                            child: _loading
                                ? Center(child: CircularProgressIndicator())
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
                    BackScreenButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
