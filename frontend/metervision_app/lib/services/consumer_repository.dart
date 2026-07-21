import '../models/consumer.dart';

abstract class ConsumerRepository {
  Future<List<Consumer>> getConsumers();
}

class MockConsumerRepository implements ConsumerRepository {
  @override
  Future<List<Consumer>> getConsumers() async {
    await Future.delayed(const Duration(milliseconds: 250));
    return const [
      Consumer(
        id: 'c1',
        consumerNo: 'PSPCL-100234',
        name: 'Rajinder Singh',
        address: 'House No. 45, Model Town, Ludhiana',
      ),
      Consumer(
        id: 'c2',
        consumerNo: 'PSPCL-100567',
        name: 'Baljeet Kaur',
        address: 'Street No. 8, Civil Lines, Patiala',
      ),
      Consumer(
        id: 'c3',
        consumerNo: 'PSPCL-100891',
        name: 'Harpreet Singh Sidhu',
        address: 'Plot 12, Industrial Area Phase 2, Amritsar',
      ),
    ];
  }
} 