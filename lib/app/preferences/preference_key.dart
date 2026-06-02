final class PreferenceKey<T extends Object> {
  const PreferenceKey(this.name, {this.defaultValue});

  final String name;
  final T? defaultValue;
}
