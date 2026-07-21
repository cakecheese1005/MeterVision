/// Mirrors the `consumers` table in the backend schema.
class Consumer {
  final String id;
  final String consumerNo;
  final String name;
  final String address;

  const Consumer({
    required this.id,
    required this.consumerNo,
    required this.name,
    required this.address,
  });
}
