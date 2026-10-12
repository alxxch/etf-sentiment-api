import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification_item.dart';
import '../providers/notification_provider.dart';
import '../theme/app_colors.dart';

/// Modal estilo Apple Finance para visualizar y gestionar las alertas del sistema
void showNotificationsPanel(BuildContext context) {
  // Asegurar carga fresca de notificaciones al abrir
  context.read<NotificationProvider>().loadNotifications(force: true);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const NotificationsPanel(),
  );
}

class NotificationsPanel extends StatelessWidget {
  const NotificationsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
        border: Border(
          top: BorderSide(color: AppColors.cardBorder, width: 0.8),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barra de arrastre estilo iOS
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10.0, bottom: 8.0),
                width: 38.0,
                height: 4.5,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),

            // Header del panel
            _buildHeader(context),

            const Divider(color: AppColors.cardBorder, height: 1.0),

            // Lista de notificaciones
            Expanded(
              child: Consumer<NotificationProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading && provider.notifications.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.aiAccent),
                      ),
                    );
                  }

                  if (provider.notifications.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 24.0),
                    itemCount: provider.notifications.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10.0),
                    itemBuilder: (context, index) {
                      final item = provider.notifications[index];
                      return _buildNotificationCard(context, item, provider);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 8.0, 16.0, 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PROACTIVE NOTIFICATIONS',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Row(
                    children: [
                      const Text(
                        'Alertas y Avisos',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20.0,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      if (provider.unreadCount > 0) ...[
                        const SizedBox(width: 8.0),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7.0, vertical: 2.0),
                          decoration: BoxDecoration(
                            color: AppColors.bearish,
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: Text(
                            '${provider.unreadCount} nuevas',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (provider.hasUnread)
                TextButton(
                  onPressed: () => provider.markAllAsRead(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.aiAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10.0, vertical: 6.0),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text(
                    'Leer todas',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                color: AppColors.textSecondary,
                size: 36.0,
              ),
            ),
            const SizedBox(height: 16.0),
            const Text(
              'No tienes alertas pendientes',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16.0,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6.0),
            const Text(
              'El sistema te notificará automáticamente cuando detecte descompensaciones en tu cartera u oportunidades de mercado.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    NotificationItem item,
    NotificationProvider provider,
  ) {
    Color iconColor;
    Color iconBg;
    IconData iconData;

    if (item.isDrift) {
      iconColor = AppColors.gold;
      iconBg = AppColors.goldSoft;
      iconData = Icons.balance_rounded;
    } else if (item.isOpportunity) {
      iconColor = AppColors.bullish;
      iconBg = AppColors.bullishSoft;
      iconData = Icons.trending_down_rounded;
    } else {
      iconColor = AppColors.aiAccent;
      iconBg = AppColors.aiAccentSoft;
      iconData = Icons.info_outline_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: item.isRead
            ? AppColors.surfaceSecondary.withValues(alpha: 0.5)
            : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: item.isRead
              ? AppColors.cardBorder.withValues(alpha: 0.5)
              : iconColor.withValues(alpha: 0.4),
          width: item.isRead ? 0.6 : 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.0),
          onTap: item.isRead ? null : () => provider.markAsRead(item.id),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icono temático con badge
                Container(
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, color: iconColor, size: 20.0),
                ),
                const SizedBox(width: 12.0),

                // Contenido
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14.0,
                                fontWeight: item.isRead
                                    ? FontWeight.w600
                                    : FontWeight.w800,
                              ),
                            ),
                          ),
                          if (!item.isRead)
                            Container(
                              margin: const EdgeInsets.only(left: 6.0),
                              width: 8.0,
                              height: 8.0,
                              decoration: const BoxDecoration(
                                color: AppColors.bearish,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        item.message,
                        style: TextStyle(
                          color: item.isRead
                              ? AppColors.textSecondary
                              : AppColors.textPrimary.withValues(alpha: 0.9),
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDate(item.timestamp),
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11.0,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (!item.isRead)
                            Text(
                              'Toca para marcar leída',
                              style: TextStyle(
                                color: iconColor.withValues(alpha: 0.8),
                                fontSize: 11.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Reciente';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return 'Hace ${diff.inHours}h';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }
}

/// Botón con campana y badge rojo reactivo para usar en AppBars
class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(
                provider.hasUnread
                    ? Icons.notifications_rounded
                    : Icons.notifications_none_rounded,
                color: provider.hasUnread
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                size: 22.0,
              ),
              tooltip: 'Alertas y notificaciones',
              onPressed: () => showNotificationsPanel(context),
            ),
            if (provider.hasUnread)
              Positioned(
                top: 8.0,
                right: 8.0,
                child: Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: const BoxDecoration(
                    color: AppColors.bearish,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16.0,
                    minHeight: 16.0,
                  ),
                  child: Text(
                    provider.unreadCount > 9 ? '9+' : '${provider.unreadCount}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.0,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
