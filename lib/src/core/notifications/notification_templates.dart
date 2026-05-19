/// Applies `{placeholder}` tokens in admin-configured notification templates.
String applyNotificationTemplate({
  required String template,
  required Map<String, String> values,
  required String fallback,
}) {
  final trimmed = template.trim();
  if (trimmed.isEmpty) {
    return fallback;
  }
  var result = trimmed;
  for (final entry in values.entries) {
    result = result.replaceAll('{${entry.key}}', entry.value);
  }
  return result;
}
