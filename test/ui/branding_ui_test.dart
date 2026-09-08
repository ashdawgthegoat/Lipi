import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lipi/presentation/widgets/lipi_logo.dart';
import 'package:lipi/presentation/widgets/quill_icon.dart';

void main() {
  testWidgets('LipiLogo renders soft fountain pen brand at multiple sizes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              LipiLogo(size: 24, borderRadius: 6),
              LipiLogo(size: 32, borderRadius: 8),
              LipiLogo(size: 64, borderRadius: 12),
              QuillIcon(size: 24), // Backward compatibility verification
            ],
          ),
        ),
      ),
    );

    expect(find.byType(LipiLogo), findsNWidgets(4));
    expect(find.byType(Image), findsNWidgets(4));
  });
}
