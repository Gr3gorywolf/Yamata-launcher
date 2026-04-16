class ArgumentGroup {
  final String name;
  final String key;
  bool singleSelect;
  final List<Argument> arguments;

  ArgumentGroup({
    required this.key,
    required this.name,
    required this.arguments,
    this.singleSelect = false,
  });
}

class Argument {
  final String name;
  final String value;

  Argument(this.name, this.value);
}
