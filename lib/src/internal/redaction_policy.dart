// Internal only — not exported from the package.
const _redactedKeys = {
  'email',
  'userid',
  'user_id',
  'uid',
  'traits',
  'token',
  'password',
  'secret',
};

String redact(String key, String value) =>
    _redactedKeys.contains(key.toLowerCase()) ? '<redacted>' : value;

Map<String, dynamic> redactMap(Map<String, dynamic> map) =>
    map.map((key, value) => MapEntry(key, redact(key, value.toString())));
