/// Connection protocol
enum ConnectionProtocol {
  ssh,
  mosh,
}

/// Connection configuration
class ConnectionConfig {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;
  final String? passphrase;
  final String? startupCommand;
  final bool useDefaultKeys;
  final ConnectionProtocol protocol;

  const ConnectionConfig({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    this.password,
    this.privateKey,
    this.passphrase,
    this.startupCommand,
    this.useDefaultKeys = true,
    this.protocol = ConnectionProtocol.ssh,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'username': username,
        'privateKey': privateKey,
        'passphrase': passphrase,
        'startupCommand': startupCommand,
        'useDefaultKeys': useDefaultKeys,
        'protocol': protocol.name,
      };

  factory ConnectionConfig.fromJson(Map<String, dynamic> json) {
    return ConnectionConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int? ?? 22,
      username: json['username'] as String,
      privateKey: json['privateKey'] as String?,
      passphrase: json['passphrase'] as String?,
      startupCommand: json['startupCommand'] as String?,
      useDefaultKeys: json['useDefaultKeys'] as bool? ?? true,
      protocol: ConnectionProtocol.values.firstWhere(
        (p) => p.name == json['protocol'],
        orElse: () => ConnectionProtocol.ssh,
      ),
    );
  }

  ConnectionConfig copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    String? password,
    String? privateKey,
    String? passphrase,
    String? startupCommand,
    bool? useDefaultKeys,
    ConnectionProtocol? protocol,
  }) {
    return ConnectionConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      privateKey: privateKey ?? this.privateKey,
      passphrase: passphrase ?? this.passphrase,
      startupCommand: startupCommand ?? this.startupCommand,
      useDefaultKeys: useDefaultKeys ?? this.useDefaultKeys,
      protocol: protocol ?? this.protocol,
    );
  }
}

/// Session state for terminal connections
enum SessionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Popular AI CLI commands with descriptions
class AiCliCommand {
  final String command;
  final String name;
  final String description;

  const AiCliCommand({
    required this.command,
    required this.name,
    required this.description,
  });

  static const List<AiCliCommand> suggestions = [
    AiCliCommand(
      command: 'claude',
      name: 'Claude Code',
      description: 'Anthropic Claude AI coding assistant',
    ),
    AiCliCommand(
      command: 'claude --dangerously-skip-permissions',
      name: 'Claude Code (auto)',
      description: 'Claude Code with auto-approve permissions',
    ),
    AiCliCommand(
      command: 'aider',
      name: 'Aider',
      description: 'AI pair programming in terminal',
    ),
    AiCliCommand(
      command: 'aider --model claude-3-5-sonnet',
      name: 'Aider (Claude)',
      description: 'Aider with Claude Sonnet model',
    ),
    AiCliCommand(
      command: 'gemini',
      name: 'Gemini CLI',
      description: 'Google Gemini AI agent',
    ),
    AiCliCommand(
      command: 'codex',
      name: 'Codex CLI',
      description: 'OpenAI Codex coding agent',
    ),
    AiCliCommand(
      command: 'aichat',
      name: 'AIChat',
      description: 'Multi-LLM CLI (OpenAI, Claude, Gemini, Ollama)',
    ),
    AiCliCommand(
      command: 'gpt',
      name: 'GPT CLI',
      description: 'ChatGPT command line interface',
    ),
    AiCliCommand(
      command: 'gh copilot',
      name: 'GitHub Copilot',
      description: 'GitHub Copilot in terminal',
    ),
  ];
}
