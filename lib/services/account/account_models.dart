/// Пара токенов кабинета. Access живёт только в памяти, refresh — в
/// защищённом хранилище.
class AccountTokens {
  const AccountTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    this.email,
  });

  factory AccountTokens.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return AccountTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 0,
      email: user is Map ? user['email'] as String? : null,
    );
  }

  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  /// Есть только в ответе verify (`user.email`).
  final String? email;
}

class CodeRequestResult {
  const CodeRequestResult({required this.resendAfter, required this.expiresIn});

  factory CodeRequestResult.fromJson(Map<String, dynamic> json) =>
      CodeRequestResult(
        resendAfter: (json['resend_after'] as num?)?.toInt() ?? 0,
        expiresIn: (json['expires_in'] as num?)?.toInt() ?? 0,
      );

  final int resendAfter;
  final int expiresIn;
}

/// Сводка подписки для экрана аккаунта.
class AccountSubscription {
  const AccountSubscription({
    required this.hasSubscription,
    required this.isActive,
    required this.daysLeft,
    this.url,
  });

  factory AccountSubscription.fromJson(Map<String, dynamic> json) {
    final sub = json['subscription'];
    final map = sub is Map<String, dynamic> ? sub : const <String, dynamic>{};
    final url = (map['subscription_url'] as String?)?.trim();
    return AccountSubscription(
      hasSubscription: json['has_subscription'] == true && sub is Map,
      isActive: map['is_active'] == true,
      daysLeft: (map['days_left'] as num?)?.toInt() ?? 0,
      url: url == null || url.isEmpty ? null : url,
    );
  }

  final bool hasSubscription;
  final bool isActive;
  final int daysLeft;
  final String? url;

  @override
  bool operator ==(Object other) =>
      other is AccountSubscription &&
      other.hasSubscription == hasSubscription &&
      other.isActive == isActive &&
      other.daysLeft == daysLeft &&
      other.url == url;

  @override
  int get hashCode => Object.hash(hasSubscription, isActive, daysLeft, url);
}

class AccountHandoff {
  const AccountHandoff({required this.token, required this.expiresIn});

  factory AccountHandoff.fromJson(Map<String, dynamic> json) => AccountHandoff(
        token: json['token'] as String,
        expiresIn: (json['expires_in'] as num?)?.toInt() ?? 0,
      );

  final String token;
  final int expiresIn;
}

/// Результат `syncSubscription()`: что стало с VPN-профилем подписки.
enum SubscriptionSyncResult { imported, alreadyPresent, noSubscription }
