import '../core/constants.dart';

/// Mirrors `app.models.consumer.ConsumerResponse` exactly.
///
/// Backend fields (all present below):
///   id, consumer_number, account_number, consumer_name, address,
///   meter_number, meter_type, subdivision?, feeder?, cycle?
///
/// `consumer_number` was added to ConsumerResponse in the current backend
/// revision. It is the PSPCL-facing identifier (`PSPCL-C-0001`) and is UNIQUE
/// NOT NULL in the `consumers` table, whereas `account_number` (`ACC-10001`)
/// is nullable at the database level even though the response model types it
/// as a required string.
class Consumer {
  final String id;

  /// PSPCL consumer number, e.g. `PSPCL-C-0001`. Unique, never null.
  final String consumerNumber;

  /// Billing account number, e.g. `ACC-10001`.
  final String accountNumber;

  final String consumerName;
  final String address;
  final String meterNumber;
  final MeterType? meterType;
  final String? subdivision;
  final String? feeder;
  final String? cycle;

  const Consumer({
    required this.id,
    required this.consumerNumber,
    required this.accountNumber,
    required this.consumerName,
    required this.address,
    this.meterNumber = '',
    this.meterType,
    this.subdivision,
    this.feeder,
    this.cycle,
  });

  // ----- Display aliases used by the existing screens -----

  /// Alias for [consumerName].
  String get name => consumerName;

  /// Alias for [accountNumber].
  String get consumerNo => accountNumber;

  /// What the officer should see to identify the consumer in a list.
  /// Falls back to the account number if the consumer number is missing.
  String get displayReference =>
      consumerNumber.isNotEmpty ? consumerNumber : accountNumber;

  // ----- Serialisation -----

  factory Consumer.fromJson(Map<String, dynamic> json) {
    return Consumer(
      id: json['id']?.toString() ?? '',
      consumerNumber: json['consumer_number']?.toString() ?? '',
      accountNumber: json['account_number']?.toString() ?? '',
      consumerName: json['consumer_name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      meterNumber: json['meter_number']?.toString() ?? '',
      meterType: MeterTypeX.fromWire(json['meter_type']?.toString()),
      subdivision: json['subdivision']?.toString(),
      feeder: json['feeder']?.toString(),
      cycle: json['cycle']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'consumer_number': consumerNumber,
      'account_number': accountNumber,
      'consumer_name': consumerName,
      'address': address,
      'meter_number': meterNumber,
      'meter_type': meterType?.wireValue,
      'subdivision': subdivision,
      'feeder': feeder,
      'cycle': cycle,
    };
  }

  Consumer copyWith({
    String? id,
    String? consumerNumber,
    String? accountNumber,
    String? consumerName,
    String? address,
    String? meterNumber,
    MeterType? meterType,
    String? subdivision,
    String? feeder,
    String? cycle,
  }) {
    return Consumer(
      id: id ?? this.id,
      consumerNumber: consumerNumber ?? this.consumerNumber,
      accountNumber: accountNumber ?? this.accountNumber,
      consumerName: consumerName ?? this.consumerName,
      address: address ?? this.address,
      meterNumber: meterNumber ?? this.meterNumber,
      meterType: meterType ?? this.meterType,
      subdivision: subdivision ?? this.subdivision,
      feeder: feeder ?? this.feeder,
      cycle: cycle ?? this.cycle,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Consumer && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
