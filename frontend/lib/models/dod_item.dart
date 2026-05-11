class DoDItem {
  final String text;
  final bool isCompleted;

  DoDItem({required this.text, this.isCompleted = false});

  Map<String, dynamic> toJson() => {
    'text': text,
    'isCompleted': isCompleted,
  };

  factory DoDItem.fromJson(Map<String, dynamic> json) {
    return DoDItem(
      text: json['text'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}
