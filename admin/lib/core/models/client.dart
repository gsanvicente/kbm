class Client {
  final String id;
  final String name;
  final String? parentClientId;

  const Client({required this.id, required this.name, this.parentClientId});
}
