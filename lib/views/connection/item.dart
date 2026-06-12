import 'dart:io';

import 'package:dropweb/clash/clash.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/plugins/app.dart';
import 'package:dropweb/providers/config.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class ConnectionItem extends ConsumerWidget {
  const ConnectionItem({
    super.key,
    required this.connection,
    this.onClickKeyword,
    this.trailing,
  });
  final Connection connection;
  final Function(String)? onClickKeyword;
  final Widget? trailing;

  /// Resolved package icons, keyed by process name. The connections list polls
  /// every second, so without this cache every rebuild re-resolves the icon
  /// through the platform channel and the [FutureBuilder] flickers back to its
  /// empty state. A cached future has stable identity, so the FutureBuilder
  /// keeps its snapshot and the icon stays put.
  static final Map<String, Future<ImageProvider?>> _packageIconCache = {};

  /// Resolved destination flags, keyed by destination IP. Same flicker fix as
  /// [_packageIconCache]; it also stops the 1s polling from re-issuing the FFI
  /// lookup for an IP that was already resolved.
  static final Map<String, Future<String?>> _ipCountryCache = {};

  /// Serializes GeoIP lookups so a freshly loaded list of N connections can't
  /// fire N concurrent [ClashCore.getCountryCode] calls at the FFI bridge in a
  /// single frame. Each new lookup chains onto the tail of this future.
  static Future<void> _ipLookupQueue = Future<void>.value();

  static Future<ImageProvider?> _packageIconFor(String process) =>
      _packageIconCache.putIfAbsent(
        process,
        () => app?.getPackageIcon(process) ?? Future<ImageProvider?>.value(),
      );

  static Future<String?> _countryFlagFor(String ip) =>
      _ipCountryCache.putIfAbsent(ip, () {
        final lookup = _ipLookupQueue.then((_) async {
          try {
            final ipInfo = await clashCore.getCountryCode(ip);
            final code = ipInfo?.countryCode;
            if (code == null || code.isEmpty) return null;
            return countryCodeToFlag(code);
          } catch (_) {
            return null;
          }
        });
        _ipLookupQueue = lookup.then((_) {});
        return lookup;
      });

  String _getSourceText(Connection connection) {
    final metadata = connection.metadata;
    if (metadata.process.isEmpty) {
      return connection.start.lastUpdateTimeDesc;
    }
    return "${metadata.process} · ${connection.start.lastUpdateTimeDesc}";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(
      patchClashConfigProvider.select(
        (state) =>
            state.findProcessMode == FindProcessMode.always &&
            Platform.isAndroid,
      ),
    );
    final title = Text(
      connection.desc,
      style: context.textTheme.bodyLarge,
    );
    final subTitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          height: 8,
        ),
        Row(
          children: [
            _DestinationFlag(ip: connection.metadata.destinationIP),
            Expanded(
              child: Text(
                _getSourceText(connection),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _ConnectionTraffic(
              upload: connection.upload,
              download: connection.download,
            ),
          ],
        ),
        const SizedBox(
          height: 8,
        ),
        Wrap(
          runSpacing: 6,
          spacing: 6,
          children: [
            for (final chain in connection.chains)
              CommonChip(
                label: chain,
                onPressed: () {
                  if (onClickKeyword == null) return;
                  onClickKeyword!(chain);
                },
              ),
          ],
        ),
      ],
    );
    return CommonPopupBox(
      targetBuilder: (open) => InkWell(
        child: GestureDetector(
          child: ListItem(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            tileTitleAlignment: ListTileTitleAlignment.titleHeight,
            leading: value
                ? GestureDetector(
                    onTap: () {
                      if (onClickKeyword == null) return;
                      final process = connection.metadata.process;
                      if (process.isEmpty) return;
                      onClickKeyword!(process);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 48,
                      height: 48,
                      child: FutureBuilder<ImageProvider?>(
                        future: _packageIconFor(connection.metadata.process),
                        builder: (_, snapshot) {
                          if (!snapshot.hasData && snapshot.data == null) {
                            return Container();
                          } else {
                            return Image(
                              image: snapshot.data!,
                              gaplessPlayback: true,
                              width: 48,
                              height: 48,
                            );
                          }
                        },
                      ),
                    ),
                  )
                : null,
            title: title,
            subtitle: subTitle,
            trailing: trailing,
          ),
        ),
        onTap: () {},
      ),
      popup: CommonPopupMenu(
        minWidth: 160,
        items: [
          PopupMenuItemData(
            label: "Edit rules",
            onPressed: () {},
          ),
          PopupMenuItemData(
            label: "Set direct",
            onPressed: () {},
          ),
          PopupMenuItemData(
            label: "Block",
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

/// Subtle destination-country flag badge for the metadata line.
///
/// Resolves the country through [ConnectionItem]'s cached + serialized lookup
/// and renders the flag as a Twemoji glyph (the project flag idiom shared with
/// change_server_button / network_detection). Renders nothing while the lookup
/// is pending or when the destination has no resolvable country, so the row
/// height never changes.
class _DestinationFlag extends StatelessWidget {
  const _DestinationFlag({required this.ip});

  final String ip;

  @override
  Widget build(BuildContext context) {
    if (ip.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<String?>(
      future: ConnectionItem._countryFlagFor(ip),
      builder: (_, snapshot) {
        final flag = snapshot.data;
        if (flag == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Text(
            flag,
            style: context.textTheme.bodyMedium?.copyWith(
              fontFamily: FontFamily.twEmoji.value,
              height: 1.0,
            ),
          ),
        );
      },
    );
  }
}

/// Compact per-connection up/down counters for the metadata line.
///
/// Mirrors the dashboard traffic-data idiom (arrow icon + [TrafficValue] text)
/// and stays within the metadata line's height. Renders nothing when the core
/// reports no counters yet.
class _ConnectionTraffic extends StatelessWidget {
  const _ConnectionTraffic({
    required this.upload,
    required this.download,
  });

  final num? upload;
  final num? download;

  @override
  Widget build(BuildContext context) {
    if (upload == null && download == null) return const SizedBox.shrink();
    final style = context.textTheme.bodySmall?.toLighter;
    final color = context.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedArrowUp01,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            TrafficValue(value: upload?.toInt()).show,
            style: style,
          ),
          const SizedBox(width: 6),
          HugeIcon(
            icon: HugeIcons.strokeRoundedArrowDown01,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            TrafficValue(value: download?.toInt()).show,
            style: style,
          ),
        ],
      ),
    );
  }
}
