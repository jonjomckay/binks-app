extension Iterables<E> on Iterable<E> {
  Iterable<E> distinctBy(Object? getCompareValue(E e)) {
    var result = <E>[];
    this.forEach((element) {
      if (!result.any((x) => getCompareValue(x) == getCompareValue(element)))
        result.add(element);
    });

    return result;
  }

  Map<K, List<E>> groupBy<K>(K Function(E) keyFunction) => fold(
      <K, List<E>>{},
          (Map<K, List<E>> map, E element) =>
      map..putIfAbsent(keyFunction(element), () => <E>[]).add(element));
}

extension ListSorted<T> on Iterable<T> {
  Iterable<T> sorted(int compare(T a, T b)) => [...this]..sort(compare);
}