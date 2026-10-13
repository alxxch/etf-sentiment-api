import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/etf_provider.dart';
import '../theme/app_colors.dart';

/// Selector horizontal de categorías de mercado con diseño estilo "Píldora" (Chips).
/// Muestra categorías como 'Trending', 'ETFs', 'Stocks' y 'Crypto'.
/// La categoría activa se resalta con borde azul y texto brillante inspirado en la etiqueta ACTIVO,
/// mientras que las inactivas muestran un fondo gris oscuro opaco.
class CategorySelector extends StatelessWidget {
  final List<String>? categories;
  final String? selectedCategory;
  final ValueChanged<String>? onCategorySelected;
  final EdgeInsetsGeometry padding;

  const CategorySelector({
    super.key,
    this.categories,
    this.selectedCategory,
    this.onCategorySelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
  });

  @override
  Widget build(BuildContext context) {
    EtfProvider? provider;
    if (categories == null || selectedCategory == null || onCategorySelected == null) {
      try {
        provider = context.watch<EtfProvider>();
      } catch (_) {}
    }

    final activeCategories = categories ??
        provider?.availableCategories ??
        EtfProvider.categories.keys.toList();
    final activeSelected = selectedCategory ??
        provider?.selectedCategory ??
        (activeCategories.isNotEmpty ? activeCategories.first : EtfProvider.defaultCategory);
    final onSelect = onCategorySelected ??
        ((cat) => provider?.selectCategory(cat));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: activeCategories.map((category) {
          final isSelected = category.toLowerCase() == activeSelected.toLowerCase();
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _CategoryPillChip(
              category: category,
              isSelected: isSelected,
              onTap: () => onSelect(category),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CategoryPillChip extends StatelessWidget {
  final String category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryPillChip({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  IconData _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'trending':
        return Icons.local_fire_department_rounded;
      case 'etfs':
        return Icons.pie_chart_rounded;
      case 'stocks':
        return Icons.show_chart_rounded;
      case 'crypto':
        return Icons.currency_bitcoin_rounded;
      default:
        return Icons.layers_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            // Activa: azul translúcido brillante / Inactiva: gris oscuro opaco
            color: isSelected
                ? AppColors.aiAccent.withValues(alpha: 0.20)
                : AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(
              color: isSelected ? AppColors.aiAccent : AppColors.cardBorder.withValues(alpha: 0.6),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.aiAccent.withValues(alpha: 0.28),
                      blurRadius: 8.0,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getCategoryIcon(category),
                size: 15.0,
                color: isSelected ? AppColors.aiAccent : AppColors.textSecondary,
              ),
              const SizedBox(width: 6.0),
              Text(
                category,
                style: TextStyle(
                  color: isSelected ? AppColors.aiAccent : AppColors.textSecondary,
                  fontSize: 13.0,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: isSelected ? 0.4 : 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
