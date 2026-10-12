import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/broker_account.dart';
import '../providers/banking_provider.dart';
import '../providers/portfolio_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/notifications_panel.dart';

class BankingScreen extends StatefulWidget {
  const BankingScreen({super.key});

  @override
  State<BankingScreen> createState() => _BankingScreenState();
}

class _BankingScreenState extends State<BankingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BankingProvider>().loadAccounts();
      }
    });
  }

  void _showLinkAccountDialog(BuildContext context) {
    final brokerController = TextEditingController(text: 'Trade Republic');
    final refController = TextEditingController(text: 'TR-ES-${DateTime.now().millisecondsSinceEpoch % 1000000}');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: const Row(
          children: [
            Icon(Icons.account_balance_rounded, color: AppColors.aiAccent, size: 22.0),
            SizedBox(width: 8.0),
            Text(
              'Conectar Broker',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18.0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Entidad Financiera',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
            ),
            const SizedBox(height: 4.0),
            TextField(
              controller: brokerController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12.0),
            const Text(
              'Referencia de Cuenta',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
            ),
            const SizedBox(height: 4.0),
            TextField(
              controller: refController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final bName = brokerController.text.trim();
              final aRef = refController.text.trim();
              if (bName.isNotEmpty && aRef.isNotEmpty) {
                Navigator.of(dialogCtx).pop();
                final res = await context.read<BankingProvider>().linkAccount(
                      brokerName: bName,
                      accountReference: aRef,
                    );
                if (res != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Cuenta de $bName vinculada con éxito.'),
                      backgroundColor: AppColors.bullish,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.aiAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            ),
            child: const Text('Vincular'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BankingProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, provider),
                Expanded(
                  child: _buildBody(context, provider),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, BankingProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OPEN BANKING & BROKERS',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 2.0),
              Text(
                'Cuentas',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.aiAccent),
                tooltip: 'Vincular Broker',
                onPressed: () => _showLinkAccountDialog(context),
              ),
              const NotificationBellButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, BankingProvider provider) {
    if (provider.isLoading && provider.accounts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.aiAccent),
        ),
      );
    }

    if (provider.accounts.isEmpty) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      color: AppColors.aiAccent,
      backgroundColor: AppColors.cardSurface,
      onRefresh: () => provider.loadAccounts(force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 32.0),
        children: [
          // Banner informativo de sincronización e idempotencia
          _buildInfoBanner(),

          const SizedBox(height: 16.0),

          // Tarjetas de brokers conectados
          ...provider.accounts.map((acc) => _buildBrokerCard(context, acc, provider)),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.6)),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, color: AppColors.bullish, size: 22.0),
          SizedBox(width: 12.0),
          Expanded(
            child: Text(
              'Conectividad Open Banking con validación de idempotencia (external_tx_id): las resincronizaciones nunca duplicarán tu saldo.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.0,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18.0),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Icon(
                Icons.account_balance_outlined,
                color: AppColors.aiAccent,
                size: 40.0,
              ),
            ),
            const SizedBox(height: 16.0),
            const Text(
              'No tienes brokers conectados',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18.0,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8.0),
            const Text(
              'Vincula tu cuenta de Trade Republic para importar tus transacciones y mantener tu cartera sincronizada de forma segura.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.0,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20.0),
            ElevatedButton.icon(
              onPressed: () => _showLinkAccountDialog(context),
              icon: const Icon(Icons.link_rounded),
              label: const Text('Conectar Trade Republic'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.aiAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrokerCard(
    BuildContext context,
    BrokerAccount account,
    BankingProvider provider,
  ) {
    final isSyncing = provider.isSyncing(account.id);

    Color statusColor;
    Color statusBg;
    String statusText;

    if (account.isSynced) {
      statusColor = AppColors.bullish;
      statusBg = AppColors.bullishSoft;
      statusText = 'SINCRONIZADO';
    } else if (account.isError) {
      statusColor = AppColors.bearish;
      statusBg = AppColors.bearishSoft;
      statusText = 'ERROR';
    } else {
      statusColor = AppColors.gold;
      statusBg = AppColors.goldSoft;
      statusText = 'PENDIENTE';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14.0),
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: account.isSynced
              ? AppColors.cardBorder
              : statusColor.withValues(alpha: 0.4),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10.0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila del Broker y estado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40.0,
                    height: 40.0,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: const Center(
                      child: Text(
                        'TR',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15.0,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.brokerName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17.0,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        'Ref: ${account.accountReference}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14.0),

          // Última sincronización
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Última sincronización: ${_formatDate(account.lastSyncedAt)}',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11.5,
                ),
              ),
              const Icon(Icons.check_circle_outline, color: AppColors.textTertiary, size: 14.0),
            ],
          ),

          const SizedBox(height: 14.0),

          // Botón de Sincronizar Ahora
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isSyncing
                  ? null
                  : () async {
                      final portfolioProvider = context.read<PortfolioProvider>();
                      final result = await provider.syncAccount(
                        account.id,
                        portfolioProvider: portfolioProvider,
                      );
                      if (result != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${account.brokerName}: ${result['message']}',
                            ),
                            backgroundColor: AppColors.bullish,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.aiAccent,
                side: const BorderSide(color: AppColors.aiAccent, width: 1.0),
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              child: isSyncing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 14.0,
                          height: 14.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.aiAccent),
                          ),
                        ),
                        SizedBox(width: 8.0),
                        Text(
                          'Sincronizando transacciones...',
                          style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sync_rounded, size: 16.0),
                        SizedBox(width: 6.0),
                        Text(
                          'Sincronizar Ahora',
                          style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Pendiente';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'Hace ${diff.inHours} h';
    } else {
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }
}
