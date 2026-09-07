class CustomAssistantConfig {
  const CustomAssistantConfig({
    required this.endpoint,
    required this.apiKey,
    required this.model,
  });

  final String endpoint;
  final String apiKey;
  final String model;

  Map<String, dynamic> toJson() => {
        'endpoint': endpoint,
        'apiKey': apiKey,
        'model': model,
      };

  factory CustomAssistantConfig.fromJson(Map<String, dynamic> json) {
    return CustomAssistantConfig(
      endpoint: json['endpoint'] as String,
      apiKey: json['apiKey'] as String,
      model: json['model'] as String,
    );
  }
}