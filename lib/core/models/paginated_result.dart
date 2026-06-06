class PaginatedResult<T, C> {
  const PaginatedResult({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<T> items;
  final bool hasMore;
  final C? nextCursor;
}
