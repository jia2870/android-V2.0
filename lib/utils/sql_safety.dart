class SqlSafety {
  static String likeTerm(String raw) {
    return raw
        .replaceAll(RegExp(r'''[%_\\,.\(\)\*:\"']'''), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
