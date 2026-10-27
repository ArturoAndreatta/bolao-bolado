import 'package:bolao_bolado/components/shell/truques_bola.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('todo truque começa e termina na pose de repouso', () {
    // Pose diferente da de repouso nas pontas aparece como salto da bola no
    // começo ou no fim do truque.
    for (final truque in truquesBola) {
      for (final t in [0.0, 1.0]) {
        final pose = truque.pose(t);
        final motivo = '${truque.nome} em t=$t';
        expect(pose.dx, closeTo(0, 0.05), reason: motivo);
        expect(pose.altura, closeTo(0, 0.05), reason: motivo);
        expect(pose.inclinacao, closeTo(0, 0.01), reason: motivo);
        expect(pose.escalaX, closeTo(1, 0.01), reason: motivo);
        expect(pose.escalaY, closeTo(1, 0.01), reason: motivo);
        expect(pose.opacidade, closeTo(1, 0.01), reason: motivo);
        // Voltas inteiras contam como repouso: a bola parece a mesma.
        expect(
          pose.angulo % (2 * 3.141592653589793),
          anyOf(closeTo(0, 0.01), closeTo(2 * 3.141592653589793, 0.01)),
          reason: motivo,
        );
        expect(
          pose.giroY % 3.141592653589793,
          anyOf(closeTo(0, 0.01), closeTo(3.141592653589793, 0.01)),
          reason: motivo,
        );
      }
    }
  });

  test('nenhum truque produz valor inválido no meio', () {
    for (final truque in truquesBola) {
      for (var i = 0; i <= 200; i++) {
        final pose = truque.pose(i / 200);
        for (final v in [
          pose.dx,
          pose.altura,
          pose.angulo,
          pose.escalaX,
          pose.escalaY,
          pose.giroY,
          pose.opacidade,
        ]) {
          expect(v.isFinite, isTrue, reason: truque.nome);
        }
        // Mais alto que isto a bola sai da barra no celular.
        expect(pose.altura, lessThanOrEqualTo(16.5), reason: truque.nome);
      }
    }
  });
}
