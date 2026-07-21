import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/consumer.dart' as models;
import '../services/consumer_repository.dart';

final consumerRepositoryProvider = Provider<ConsumerRepository>((ref) {
  return MockConsumerRepository();
}); 

final consumerListProvider = FutureProvider<List<models.Consumer>>((ref) async {
  final repo = ref.watch(consumerRepositoryProvider);
  return repo.getConsumers();
}); 