import 'package:flutter/foundation.dart';

/// Aviso global de "os dados mudaram". Os serviços chamam [bump] depois de
/// gravar algo (venda, cancelamento, estoque, produto, sincronização) e as
/// telas abertas escutam [versao] para recarregar sozinhas, sem o usuário
/// precisar puxar a tela para baixo.
class DataNotifier {
  static final ValueNotifier<int> versao = ValueNotifier<int>(0);
  static void bump() => versao.value++;
}
