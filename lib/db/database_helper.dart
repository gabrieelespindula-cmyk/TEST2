import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../utils/password_utils.dart';

/// Camada de acesso ao banco local (SQLite), usada como cache/armazenamento
/// offline-first. Quando há conexão com a nuvem, os Services sincronizam
/// este banco com a API em C# (ver SyncService).
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sabordecasa.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        login TEXT NOT NULL UNIQUE,
        senha TEXT NOT NULL,
        perfil TEXT NOT NULL DEFAULT 'funcionario'
      )
    ''');

    await db.execute('''
      CREATE TABLE produtos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        preco REAL NOT NULL,
        quantidadeEstoque INTEGER NOT NULL DEFAULT 0,
        categoria TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE vendas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT NOT NULL,
        valorTotal REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'Ativa',
        usuarioId INTEGER NOT NULL,
        FOREIGN KEY (usuarioId) REFERENCES usuarios (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE itens_venda (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vendaId INTEGER NOT NULL,
        produtoId INTEGER NOT NULL,
        quantidade INTEGER NOT NULL,
        precoUnitario REAL NOT NULL,
        FOREIGN KEY (vendaId) REFERENCES vendas (id) ON DELETE CASCADE,
        FOREIGN KEY (produtoId) REFERENCES produtos (id)
      )
    ''');

    await _criarTabelaSync(db);
    await _seed(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _criarTabelaSync(db);
    }
  }

  /// Fila de operações pendentes, criadas enquanto o app está offline.
  /// Quando a conectividade com a API voltar, o SyncService lê esta tabela
  /// em ordem e reenvia cada operação para a nuvem.
  Future<void> _criarTabelaSync(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fila_sincronizacao (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo TEXT NOT NULL,        -- ex: 'venda', 'produto', 'estoque'
        operacao TEXT NOT NULL,    -- 'criar' | 'atualizar' | 'excluir'
        payload TEXT NOT NULL,     -- JSON serializado da requisição
        referenciaLocalId INTEGER, -- id local (ex.: venda local) afetado
        criadoEm TEXT NOT NULL,
        tentativas INTEGER NOT NULL DEFAULT 0,
        ultimoErro TEXT
      )
    ''');
  }

  Future<void> _seed(Database db) async {
    // Usuário padrão: admin / admin123 (RF01)
    await db.insert('usuarios', {
      'nome': 'Administrador',
      'login': 'admin',
      'senha': PasswordUtils.hash('admin123'),
      'perfil': 'gerente',
    });

    await db.insert('usuarios', {
      'nome': 'Funcionário Teste',
      'login': 'funcionario',
      'senha': PasswordUtils.hash('123456'),
      'perfil': 'funcionario',
    });

    final produtosIniciais = [
      {'nome': 'Bolo de Chocolate', 'preco': 35.90, 'quantidadeEstoque': 12, 'categoria': 'Bolos'},
      {'nome': 'Pão Caseiro', 'preco': 12.50, 'quantidadeEstoque': 40, 'categoria': 'Pães'},
      {'nome': 'Coxinha de Frango', 'preco': 6.00, 'quantidadeEstoque': 8, 'categoria': 'Salgados'},
      {'nome': 'Brigadeiro Gourmet', 'preco': 3.50, 'quantidadeEstoque': 60, 'categoria': 'Doces'},
      {'nome': 'Torta de Limão', 'preco': 42.00, 'quantidadeEstoque': 5, 'categoria': 'Tortas'},
      {'nome': 'Suco Natural 500ml', 'preco': 9.00, 'quantidadeEstoque': 25, 'categoria': 'Bebidas'},
    ];

    for (final p in produtosIniciais) {
      await db.insert('produtos', p);
    }
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
