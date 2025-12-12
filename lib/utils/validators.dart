class Validators {
  // Genel email formatı kontrolü
  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  static String? email(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'E-posta zorunlu';
    if (!_emailRegex.hasMatch(value)) {
      return 'Geçerli bir e-posta adresi gir';
    }
    return null;
  }

  static String? password(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Şifre zorunlu';
    if (value.length < 6) {
      return 'Şifre en az 6 karakter olmalı';
    }
    return null;
  }
}
