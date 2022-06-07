import 'dart:async';

import 'package:flutter_hooks/flutter_hooks.dart';

void useEventStream<T>(
  Stream<T> stream, {
  required Function(T?) onEvent,
  bool active = true,
}) {
  final subscription = useState<StreamSubscription<T>?>(null);

  useEffect(() {
    if (active) {
      subscription.value = stream.listen(onEvent);
    } else {
      subscription.value?.cancel();
    }
  }, [active]);

  useEffect(() {
    return () {
      subscription.value?.cancel();
    };
  }, []);
}
