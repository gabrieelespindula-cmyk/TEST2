# Sabor de Casa — App Flutter (Offline-first + Nuvem)

App mobile em Flutter para o sistema "Sabor de Casa", com **duas camadas de
dados**:

1. **SQLite local** — sempre disponível, funciona sem internet.
2. **API REST em nuvem** (ASP.NET Core + MySQL/PostgreSQL) — usada
   automaticamente quando há conexão, mantendo todos os dispositivos
   sincronizados.

O app decide sozinho qual camada usar a cada operação: se a API estiver
alcançável, os dados vão/voltam da nuvem (e o SQLite local é atualizado como
cache); se não houver internet, tudo continua funcionando localmente, e as
alterações ficam guardadas numa **fila de sincronização** até a conexão
voltar.

## Como executar o app

```bash
cd sabor_de_casa_flutter
flutter pub get
flutter run
```

Na primeira tela de login, toque no ícone de nuvem (canto superior direito)
para configurar o endereço da API. Dica:
- Emulador Android → `http://10.0.2.2:5000` (aponta para o localhost da sua máquina)
- Celular físico na mesma rede → `http://SEU_IP_LOCAL:5000`
- Depois do deploy → a URL pública do servidor

Sem configurar nada, o app funciona 100% no modo offline (SQLite local).

### Login padrão
- **Gerente:** `admin` / `admin123`
- **Funcionário:** `funcionario` / `123456`

## Como subir a API em nuvem (projeto C# original)

O backend é o mesmo projeto ASP.NET Core MVC que você já tem, com uma camada
de **API REST (JSON)** adicionada por cima — veja o arquivo
`API_BACKEND.md` com o passo a passo completo de:
- quais pacotes NuGet instalar
- como configurar MySQL/PostgreSQL na nuvem
- os endpoints da API e como testá-los
- opções gratuitas de hospedagem para projeto de faculdade (Railway, Render, etc.)

## Arquitetura (o que mudou para suportar nuvem + offline)

```
lib/
├── config/app_config.dart       # URL da API, configurável sem recompilar
├── services/
│   ├── api_client.dart          # Chamadas HTTP + token JWT
│   ├── connectivity_service.dart# Detecta se há internet E se a API responde
│   ├── token_storage.dart       # Guarda o token JWT e a sessão
│   ├── sync_queue.dart          # Fila de operações feitas offline
│   ├── sync_service.dart        # Reenvia a fila para a nuvem quando possível
│   ├── session_provider.dart    # Login: tenta nuvem, cai para local
│   ├── produto_service.dart     # CRUD de produtos (nuvem + cache local)
│   ├── venda_service.dart       # Vendas (o caso mais sensível — ver abaixo)
│   ├── usuario_service.dart
│   └── dashboard_service.dart
├── db/database_helper.dart      # Schema SQLite + tabela fila_sincronizacao
├── widgets/
│   ├── connection_banner.dart   # Aviso "modo offline" no topo das telas
│   └── main_scaffold.dart       # Dispara sincronização quando a rede volta
└── screens/config_screen.dart   # Tela para configurar/testar a URL da API
```

## Como funciona a sincronização, na prática

**Leitura** (ex.: listar produtos): tenta a API; se der certo, atualiza o
cache local; se falhar, usa o que já estiver salvo no celular.

**Escrita** (ex.: registrar venda, cadastrar produto): tenta a API
primeiro; se não houver conexão, grava direto no SQLite local **e**
registra a operação na tabela `fila_sincronizacao`. Quando a internet volta
(detectado automaticamente, ou pelo botão "Sincronizar agora" na aba
Perfil), o `SyncService` reenvia cada operação pendente, na ordem em que
foi criada.

**Venda feita offline**: o produto já tem a baixa de estoque aplicada
localmente na hora (a experiência do funcionário não muda nada). Quando o
app sincroniza depois, a venda é recriada na nuvem; se o servidor
confirmar com um ID diferente do ID local provisório, o app atualiza as
referências internas automaticamente (ver `_remapearId` em
`sync_service.dart`).

**Login offline**: se o funcionário já logou com internet pelo menos uma
vez, a senha fica salva localmente (como hash) e o login continua
funcionando sem conexão. Um selo "Modo offline" aparece no topo das telas.

## Limitações e simplificações (documentadas de propósito)

Como é um projeto de faculdade, optei por manter a sincronização **simples
e direta** em vez de um motor de sync genérico:

- **Resolução de conflito:** "o último que sincronizar, vence" — não há
  merge automático se dois dispositivos editarem o mesmo produto offline ao
  mesmo tempo. Para o escopo da disciplina, isso costuma ser aceitável; se
  quiser evoluir, dá pra adicionar um campo `atualizadoEm` e comparar
  timestamps antes de sobrescrever.
- **Tentativas:** uma operação que falhar repetidamente (ex.: erro de
  validação) é descartada da fila após 4 tentativas, para não travar a
  sincronização para sempre.
- **Hash de senha local:** SHA-256 (não BCrypt), só para a verificação
  offline — a nuvem continua usando BCrypt normalmente.

## Requisitos Funcionais (RF) — cobertura

Mesma tabela do projeto original; todos os RFs continuam valendo tanto
online quanto offline, exceto RF10/RF15 (relatórios), que fazem mais
sentido com a nuvem ligada, mas também têm fallback local.
