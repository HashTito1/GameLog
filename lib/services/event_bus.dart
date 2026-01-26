import 'dart:async';

class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();
  static EventBus get instance => _instance;

  final Map<Type, StreamController> _controllers = {};

  Stream<T> on<T>() {
    if (!_controllers.containsKey(T)) {
      _controllers[T] = StreamController<T>.broadcast();
    }
    return _controllers[T]!.stream as Stream<T>;
  }

  void fire<T>(T event) {
    if (_controllers.containsKey(T)) {
      _controllers[T]!.add(event);
    }
  }

  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }

  // Specific event streams for common events
  Stream<RatingSubmittedEvent> get ratingSubmitted => on<RatingSubmittedEvent>();
}

// Event classes
class RatingSubmittedEvent {
  final String gameId;
  final String userId;
  final double rating;
  final String? review;

  RatingSubmittedEvent({
    required this.gameId,
    required this.userId,
    required this.rating,
    this.review,
  });
}

class LibraryUpdatedEvent {
  final String userId;
  
  LibraryUpdatedEvent({required this.userId});
}


