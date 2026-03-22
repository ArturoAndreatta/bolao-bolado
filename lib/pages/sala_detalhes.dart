import 'package:bolao_bolado/components/shell/default_layout.dart';
import 'package:bolao_bolado/components/shared/back_screen_button.dart';
import 'package:bolao_bolado/components/shared/custom_card.dart';
import 'package:bolao_bolado/components/shell/drawer.dart';
import 'package:bolao_bolado/models/sala.dart';
import 'package:bolao_bolado/widgets/participants_table.dart';
import 'package:bolao_bolado/models/bet.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SalaDetalhes extends StatefulWidget {
  final Sala sala;
  const SalaDetalhes({super.key, required this.sala});

  @override
  State<SalaDetalhes> createState() => _SalaDetalhesState();
}

class _SalaDetalhesState extends State<SalaDetalhes> {
  List<Map<String, dynamic>> _apostas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carregarApostas();
  }

  Future<void> _carregarApostas() async {
    setState(() => _loading = true);
    final data = await getBets();
    setState(() {
      _apostas = data;
      _loading = false;
    });
  }

  void _mostrarInfoSala() {
    final sala = widget.sala;
    final formatoData = sala.dataHora != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(sala.dataHora!)
        : '—';
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFFFEFEFE),
        surfaceTintColor: Colors.transparent,
        elevation: 18,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        contentPadding: EdgeInsets.fromLTRB(20, 20, 20, 16),
        title: Text(
          sala.nome,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sala.descricao.isNotEmpty) ...[
              Text(
                sala.descricao,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              SizedBox(height: 12),
            ],
            _infoLinha(
              Icons.confirmation_number_outlined,
              'Sorteio',
              sala.sorteio ?? '—',
            ),
            _infoLinha(Icons.calendar_today, 'Data/Hora', formatoData),
            _infoLinha(
              Icons.attach_money,
              'Prêmio',
              formatoMoeda.format(sala.premio),
            ),
            if (sala.valorMaximo != null)
              _infoLinha(
                Icons.attach_money,
                'Valor máx. aposta',
                formatoMoeda.format(sala.valorMaximo!),
              ),
            _infoLinha(Icons.key, 'Chave PIX', sala.chavePix),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget _infoLinha(IconData icon, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
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
      drawer: AppDrawer(),
      child: Stack(
        children: [
          CustomCard(
            children: [
              SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.sala.nome,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _mostrarInfoSala,
                      icon: Icon(Icons.info_outline),
                      color: Colors.grey,
                      tooltip: 'Informações da sala',
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
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
                            rowsData: _apostas,
                          ),
                        ),
                      ),
              ),
              SizedBox(height: 30),
            ],
          ),
          BackScreenButton(),
        ],
      ),
    );
  }
}
