Function(dynamic) callAll(List<Function> callbacks) {
  return (dynamic args) {
    for (var f in callbacks) {
      f(args);
    }
  };
}
