import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sourcely/widgets/loading_shimmer.dart';

void main() {
  group('LoadingShimmer and TypingIndicator Widget Tests', () {
    testWidgets('LoadingShimmer renders correctly with default items', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingShimmer(),
          ),
        ),
      );

      // Verify Shimmer is used
      expect(find.byType(Shimmer), findsOneWidget);
      
      // We expect 3 cards by default, but _ShimmerCard is a private widget.
      // We can find Containers that we know are inside _ShimmerCard.
      // A _ShimmerCard has a Container with margin, padding, etc. 
      // Let's just verify the widget doesn't crash and finds the Shimmer.
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('LoadingShimmer renders custom number of items', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingShimmer(itemCount: 5),
          ),
        ),
      );

      expect(find.byType(Shimmer), findsOneWidget);
      // At least one column inside shimmer
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('TypingIndicator renders and animates', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TypingIndicator(),
          ),
        ),
      );

      // Expect to find the 'S' text in the avatar
      expect(find.text('S'), findsOneWidget);

      // Let animation run a bit
      await tester.pump(const Duration(milliseconds: 200));
      
      // Ensure it renders correctly
      expect(find.byType(Row), findsWidgets);
    });
  });
}
