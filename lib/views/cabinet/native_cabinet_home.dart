import 'package:dropweb/common/common.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cabinet_home_adapter.dart';
import 'cabinet_home_data.dart';
import 'cabinet_view.dart';

class NativeCabinetHome extends StatelessWidget {
  const NativeCabinetHome({super.key});

  Future<void> _openCabinet(BuildContext context) async {
    await BaseNavigator.push(
      context,
      const CabinetWebView(initialPath: '/login'),
    );
  }

  Future<void> _openTopUp(BuildContext context) async {
    await BaseNavigator.push(
      context,
      const CabinetWebView(initialPath: '/balance/top-up'),
    );
  }

  Future<void> _openRenew(BuildContext context) async {
    await BaseNavigator.push(
      context,
      const CabinetWebView(initialPath: '/subscription/purchase'),
    );
  }

  Future<void> _openSupport(BuildContext context) async {
    await BaseNavigator.push(
      context,
      const CabinetWebView(initialPath: '/support'),
    );
  }

  Future<void> _copyReferral(BuildContext context, Uri? link) async {
    final value = link?.toString();
    if (value == null) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Реферальная ссылка скопирована')),
    );
  }

  Future<void> _importSubscription(
    BuildContext context,
    CabinetHomeData? data,
  ) async {
    final url = data?.subscriptionUrl;
    if (url == null) {
      await _openCabinet(context);
      return;
    }

    try {
      await globalState.appController.addProfileFormURL(url.toString());
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Подписка добавлена в Dropweb')),
      );
    } catch (_) {
      if (!context.mounted) return;
      await _openCabinet(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return ValueListenableBuilder<CabinetHomeData?>(
      valueListenable: cabinetHomeAdapter.snapshot,
      builder: (context, data, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(16).copyWith(
          bottom: 120 + bottomInset,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = 12.0;
                    final squareSize = (constraints.maxWidth - gap) / 2;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TariffHeroCard(
                          height: squareSize < 184 ? 184 : squareSize,
                          data: data,
                          onPrimaryPressed: () =>
                              _importSubscription(context, data),
                          onFallbackPressed: () => _openCabinet(context),
                        ),
                        const SizedBox(height: gap),
                        _BentoRow(
                          gap: gap,
                          left: _BalanceCard(
                            size: squareSize,
                            balanceLabel: data?.balanceLabel,
                            onPressed: () => _openTopUp(context),
                          ),
                          right: _DevicesCard(
                            size: squareSize,
                            onPressed: () => _openCabinet(context),
                          ),
                        ),
                        const SizedBox(height: gap),
                        _BentoRow(
                          gap: gap,
                          left: _CabinetActionCard(
                            size: squareSize,
                            icon: Icons.ios_share_rounded,
                            title: 'Рефералы',
                            subtitle: data?.referralLink == null
                                ? 'Ссылка —'
                                : 'Скопировать ссылку',
                            actionLabel: 'Скопировать',
                            onPressed: data?.referralLink == null
                                ? null
                                : () => _copyReferral(
                                      context,
                                      data?.referralLink,
                                    ),
                          ),
                          right: _CabinetActionCard(
                            size: squareSize,
                            icon: Icons.event_repeat_rounded,
                            title: 'Продлить',
                            subtitle: 'Оплата тарифа',
                            actionLabel: 'Продлить',
                            onPressed: () => _openRenew(context),
                          ),
                        ),
                        const SizedBox(height: gap),
                        _BentoRow(
                          gap: gap,
                          left: _CabinetActionCard(
                            size: squareSize,
                            icon: Icons.support_agent_rounded,
                            title: 'Поддержка',
                            subtitle: 'Помощь в кабинете',
                            actionLabel: 'Написать',
                            onPressed: () => _openSupport(context),
                          ),
                          right: _CabinetActionCard(
                            size: squareSize,
                            icon: Icons.open_in_new_rounded,
                            title: 'Открыть кабинет',
                            subtitle: 'Веб-кабинет',
                            actionLabel: 'Открыть',
                            onPressed: () => _openCabinet(context),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BentoRow extends StatelessWidget {
  const _BentoRow({
    required this.gap,
    required this.left,
    required this.right,
  });

  final double gap;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          left,
          SizedBox(width: gap),
          right,
        ],
      );
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.size,
    required this.balanceLabel,
    required this.onPressed,
  });

  final double size;
  final String? balanceLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CommonCard(
          onPressed: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 20,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Баланс',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  balanceLabel ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Пополнить',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _DevicesCard extends StatelessWidget {
  const _DevicesCard({required this.size, required this.onPressed});

  final double size;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CommonCard(
          onPressed: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.devices_other_rounded,
                      size: 20,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Устройства',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Данные появятся позже',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _CabinetActionCard extends StatelessWidget {
  const _CabinetActionCard({
    required this.size,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onPressed,
  });

  final double size;
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CommonCard(
          onPressed: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  onPressed == null ? 'Недоступно' : actionLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: onPressed == null
                        ? context.colorScheme.onSurfaceVariant
                        : context.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _TariffHeroCard extends StatelessWidget {
  const _TariffHeroCard({
    required this.height,
    required this.data,
    required this.onPrimaryPressed,
    required this.onFallbackPressed,
  });

  final double height;
  final CabinetHomeData? data;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onFallbackPressed;

  String get _title => data?.tariffName ?? 'Войдите в кабинет Dropweb';

  String get _cost => data?.tariffCostLabel ?? '—';

  String get _status => data?.statusLabel ?? 'Данные появятся после входа';

  String get _ctaLabel {
    if (data?.subscriptionUrl == null) return 'Открыть кабинет';
    return switch (data?.importState) {
      CabinetImportState.imported => 'Импортировать снова',
      CabinetImportState.ready => 'Подключить в Dropweb',
      _ => 'Открыть кабинет',
    };
  }

  @override
  Widget build(BuildContext context) => CommonCard(
        enterAnimated: true,
        onPressed: onPrimaryPressed,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _ctaLabel,
                      onPressed: onPrimaryPressed,
                      icon: Icon(
                        Icons.bolt_rounded,
                        color: context.colorScheme.primary,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Открыть кабинет',
                      onPressed: onFallbackPressed,
                      icon: Icon(
                        Icons.open_in_new_rounded,
                        color: context.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  _cost,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 20,
                      color: context.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _ctaLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.labelMedium?.copyWith(
                          color: context.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
