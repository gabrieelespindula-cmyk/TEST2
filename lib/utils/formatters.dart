import 'package:intl/intl.dart';

class Formatters {
  static final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final dateShort = DateFormat('dd/MM/yyyy');
  static final dateTime = DateFormat('dd/MM/yyyy HH:mm');

  static String moeda(double valor) => currency.format(valor);
  static String dataCurta(DateTime data) => dateShort.format(data);
  static String dataHora(DateTime data) => dateTime.format(data);
}
