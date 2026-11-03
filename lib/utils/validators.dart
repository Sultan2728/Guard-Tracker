/// Form validation helpers for registration/login. Each returns an error
/// message in Russian, or null when the value is valid.

/// Canonical form of a Kazakhstan/Russia phone number: 11 digits starting
/// with 7 (so "+7 707 123 45 67", "8 707 123 45 67" and "707 123 45 67"
/// are all the same account). Returns null if it can't be a valid number.
String? canonicalPhone(String raw) {
  var d = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.length == 11 && d.startsWith('8')) d = '7${d.substring(1)}';
  if (d.length == 10) d = '7$d';
  if (d.length == 11 && d.startsWith('7')) return d;
  return null;
}

String? validateName(String v) {
  final s = v.trim();
  if (s.isEmpty) return 'Введите имя и фамилию.';
  if (s.length < 2) return 'Имя слишком короткое.';
  if (s.length > 60) return 'Имя слишком длинное.';
  if (!RegExp(r"^[A-Za-zА-Яа-яЁёӘәҒғҚқҢңӨөҰұҮүҺһІі\s\-']+$").hasMatch(s)) {
    return 'Имя может содержать только буквы, пробел и дефис.';
  }
  return null;
}

String? validatePhone(String v) {
  if (v.trim().isEmpty) return 'Введите номер телефона.';
  if (canonicalPhone(v) == null) {
    return 'Неверный номер. Пример: +7 707 123 45 67';
  }
  return null;
}

String? validatePassword(String v) {
  if (v.isEmpty) return 'Введите пароль.';
  if (v.length < 6) return 'Пароль — минимум 6 символов.';
  if (v.length > 64) return 'Пароль слишком длинный.';
  if (v.contains(' ')) return 'Пароль не должен содержать пробелы.';
  if (!RegExp(r'[A-Za-zА-Яа-я]').hasMatch(v) || !RegExp(r'[0-9]').hasMatch(v)) {
    return 'Пароль должен содержать и буквы, и цифры.';
  }
  return null;
}

String? validateCustomRole(String v) {
  final s = v.trim();
  if (s.isEmpty) return 'Укажите должность.';
  if (s.length < 3) return 'Должность слишком короткая.';
  if (s.length > 30) return 'Должность слишком длинная.';
  return null;
}
