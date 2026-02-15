import 'package:flutter/material.dart';
import '../services/service_provider.dart';
import '../theme/matte_theme.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ServiceProvider.of(context).store;

    return Container(
      color: MatteColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Offline',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: MatteColors.textPrimary,
              ),
            ),
          ),
          Container(
            height: 0.5,
            color: MatteColors.borderSubtle,
            margin: const EdgeInsets.only(top: 8),
          ),

          Expanded(
            child: ListenableBuilder(
              listenable: store,
              builder: (context, _) {
                final downloads = store.downloads;
                if (downloads.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.download_rounded,
                          size: 40,
                          color: MatteColors.borderSubtle,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'No downloads yet',
                          style: TextStyle(
                            color: MatteColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Search for music and tap ⬇ to download',
                          style: TextStyle(
                            color: MatteColors.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final done = downloads.where((d) => d.status == 2).length;
                final active = downloads.where((d) => d.status == 1).length;
                final queued = downloads.where((d) => d.status == 0).length;
                final failed = downloads.where((d) => d.status == 3).length;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          if (done > 0)
                            _Badge(
                              count: done,
                              label: 'Done',
                              color: MatteColors.success,
                            ),
                          if (done > 0) const SizedBox(width: 5),
                          if (active > 0)
                            _Badge(
                              count: active,
                              label: 'Active',
                              color: MatteColors.accent,
                            ),
                          if (active > 0) const SizedBox(width: 5),
                          if (queued > 0)
                            _Badge(
                              count: queued,
                              label: 'Queue',
                              color: MatteColors.textTertiary,
                            ),
                          if (queued > 0) const SizedBox(width: 5),
                          if (failed > 0)
                            _Badge(
                              count: failed,
                              label: 'Failed',
                              color: MatteColors.error,
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        itemCount: downloads.length,
                        itemBuilder: (context, index) {
                          final d = downloads[index];
                          return _DownloadTile(dl: d);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _Badge({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  final DownloadData dl;
  const _DownloadTile({required this.dl});

  @override
  Widget build(BuildContext context) {
    final statusIcon = switch (dl.status) {
      0 => Icons.hourglass_empty_rounded,
      1 => Icons.downloading_rounded,
      2 => Icons.check_circle_rounded,
      3 => Icons.error_rounded,
      _ => Icons.help_outline_rounded,
    };
    final statusColor = switch (dl.status) {
      0 => MatteColors.textTertiary,
      1 => MatteColors.accent,
      2 => MatteColors.success,
      3 => MatteColors.error,
      _ => MatteColors.textMuted,
    };
    final statusLabel = switch (dl.status) {
      0 => 'Queued',
      1 => '${(dl.progress * 100).toStringAsFixed(0)}%',
      2 => 'Done',
      3 => 'Failed',
      _ => '',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(
        children: [
          Icon(statusIcon, size: 18, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dl.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MatteColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                if (dl.status == 1)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: dl.progress,
                      minHeight: 3,
                      backgroundColor: MatteColors.bgCard,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  )
                else
                  Text(
                    '${dl.artist} · $statusLabel',
                    style: TextStyle(fontSize: 10, color: statusColor),
                  ),
              ],
            ),
          ),
          if (dl.filePath != null && dl.status == 2)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '✓',
                style: TextStyle(fontSize: 11, color: statusColor),
              ),
            ),
        ],
      ),
    );
  }
}
