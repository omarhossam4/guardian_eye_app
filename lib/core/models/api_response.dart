class ApiResponse<T> {
  const ApiResponse({
    required this.data,
    this.message,
    this.meta,
  });

  final T data;
  final String? message;
  final Map<String, dynamic>? meta;
}
