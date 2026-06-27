import 'ai_request.dart';

/// Contract that every AI provider must implement.
///
/// The infrastructure layer (Request Manager, Provider Router) interacts
/// exclusively through this interface, making it trivial to add new
/// providers (OpenAI, Anthropic, Ollama, etc.) without changing any
/// pipeline or routing code.
abstract class AiProvider {
  /// Short machine-readable identifier, e.g. `'gemini'`, `'groq'`.
  String get id;

  /// Human-readable display name, e.g. `'Google Gemini'`.
  String get name;

  /// The specific model string sent to the API, e.g. `'gemini-2.5-flash'`.
  String get model;

  /// Maximum context window in tokens.
  int get maxContextTokens;

  /// Lower number = higher preference when multiple providers are available.
  int get priority;

  /// Whether this provider natively supports JSON-mode with a response schema.
  /// If `false`, the infrastructure will use prompt-based JSON instructions.
  bool get supportsJsonMode;

  /// Generate text from a prompt.
  ///
  /// Implementations MUST throw [AiException] with the correct [AiErrorType]
  /// so the retry / fallback logic can act appropriately.
  Future<AiResponse> generate(AiRequest request);

  /// Verify that the given API key is valid by making a minimal test request.
  /// Returns `true` if the key works.
  Future<bool> validateApiKey(String apiKey);

  /// Quick connectivity check. Returns `true` if the provider is reachable.
  Future<bool> healthCheck();
}
