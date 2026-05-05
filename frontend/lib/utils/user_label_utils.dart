class UserLabelUtils {
  static const String unknownUserLabel = 'Unknown User';

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool looksLikeUuid(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return false;
    if (_uuidRegex.hasMatch(v)) return true;

    // Also treat common UUID variants:
    // - 32 hex chars with no dashes
    // - dash-separated hex-like long tokens (without spaces)
    final compact = v.replaceAll('-', '');
    if (compact.length == 32 &&
        RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(compact)) {
      return true;
    }

    if (v.length >= 30 &&
        v.length <= 45 &&
        !v.contains(' ') &&
        v.contains('-') &&
        RegExp(r'^[0-9a-fA-F-]+$').hasMatch(v)) {
      return true;
    }

    return false;
  }

  /// Sanitizes user identifiers for display.
  ///
  /// - If `raw` looks like a UUID, returns `Unknown User` to avoid exposing IDs.
  /// - If `raw` is empty/null:
  ///   - returns `Unknown User` when `emptyIsUnknown` is true
  ///   - otherwise returns an empty string
  static String sanitizeUserLabel(
    String? raw, {
    bool emptyIsUnknown = false,
    String unknownLabel = unknownUserLabel,
  }) {
    final v = raw?.trim() ?? '';
    if (v.isEmpty) return emptyIsUnknown ? unknownLabel : '';
    if (looksLikeUuid(v)) return unknownLabel;
    return raw!.trim();
  }
}
