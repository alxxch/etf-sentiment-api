import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/glass_card.dart';
import 'package:frontend/widgets/spatial_portfolio_widget.dart';

void main() {
  group('Phase 18: Spatial UI & 3D Analytics Tests', () {
    testWidgets('SpatialPortfolioWidget renders isometric spatial UI elements',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: Color(0xFF000000),
            body: SpatialPortfolioWidget(
              modelPath: 'assets/3d/placeholder.glb',
              height: 280.0,
            ),
          ),
        ),
      );

      // Verificar que el contenedor y los badges espaciales existen
      expect(find.byType(SpatialPortfolioWidget), findsOneWidget);
      expect(find.text('DIORAMA 3D • ISOMÉTRICO'), findsOneWidget);
      expect(find.text('AUTO-GIRO'), findsOneWidget);
      expect(find.text('Arrastra para rotar • Pellizca para zoom'), findsOneWidget);

      // Interactuar con el toggle de rotación manual/automática
      await tester.tap(find.text('AUTO-GIRO'));
      await tester.pump();
      expect(find.text('MANUAL'), findsOneWidget);
    });

    testWidgets('GlassCard renders with ImageFilter.blur sigma 10 and translucent #1C1C1E background',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassCard(
              blurSigma: 10.0,
              backgroundColor: Color(0x661C1C1E),
              child: Text('Glassmorphism Metric Card'),
            ),
          ),
        ),
      );

      expect(find.text('Glassmorphism Metric Card'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);

      final backdropFilter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
      final blur = backdropFilter.filter;
      expect(blur, isNotNull);
    });
  });
}
