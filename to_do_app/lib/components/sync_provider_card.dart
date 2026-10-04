import 'package:flutter/material.dart';
import 'package:to_do_app/components/app_toggle.dart';
import 'package:to_do_app/components/last_synced_label.dart';
import 'package:to_do_app/themes/app_colors.dart';

import 'package:to_do_app/components/brand_logo.dart';

/// One calendar provider on the Calendar Sync page (Device / Google /
/// Outlook). Layout, type and colours follow the Figma "Sync Tile".
class SyncProviderCard extends StatelessWidget {
  final String name;
  final BrandIcon brandIcon;
  final Color brandColor;
  final String status;
  final String description;
  final bool connected;
  final bool loading;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onManage;

  const SyncProviderCard({
    super.key,
    required this.name,
    required this.brandIcon,
    required this.brandColor,
    required this.status,
    required this.description,
    required this.connected,
    required this.loading,
    required this.onToggle,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: connected ? brandColor.withValues(alpha: 0.5) : colors.outline,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                BrandLogo(brandIcon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          color: connected ? brandColor : colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: colors.outline),
          // Description
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                description,
                style: TextStyle(fontSize: 13, color: colors.muted),
              ),
            ),
          ),
          // Enable sync
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Enable sync',
                    style: TextStyle(fontSize: 16, color: onSurface),
                  ),
                ),
                if (loading) ...[
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.appColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                AppToggle(
                  value: connected,
                  onChanged: loading ? null : onToggle,
                ),
              ],
            ),
          ),
          // Manage footer (only when connected)
          if (connected) ...[
            Divider(height: 1, thickness: 1, color: colors.outline),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
              child: Row(
                children: [
                  const Expanded(child: LastSyncedLabel()),
                  TextButton.icon(
                    onPressed: loading ? null : onManage,
                    style: TextButton.styleFrom(
                      foregroundColor: context.appColors.accent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Manage'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
