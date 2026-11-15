import 'package:animated_reorderable_list/animated_reorderable_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'AnimatedReorderableGridView reorders 3rd item to 0 when dragged before 1st item',
    (tester) async {
      var items = <String>['A', 'B', 'C', 'D'];
      (int, int)? reordered;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(40),
              child: AnimatedReorderableGridView<String>(
                items: items,
                shrinkWrap: true,
                sliverGridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.5,
                    ),
                isSameItem: (a, b) => a == b,
                longPressDraggable: true,
                onReorder: (oldIndex, newIndex) {
                  reordered = (oldIndex, newIndex);
                  final moved = items.removeAt(oldIndex);
                  items.insert(newIndex, moved);
                },
                itemBuilder: (context, index) {
                  final id = items[index];
                  return KeyedWidget(
                    key: ValueKey(id),
                    child: Container(
                      alignment: Alignment.center,
                      color: Colors.blue,
                      child: Text(id),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final thirdCenter = tester.getCenter(find.text('C'));
      final firstTopLeft = tester.getTopLeft(find.text('A'));
      final initialAPos = tester.getTopLeft(find.text('A'));
      final initialBPos = tester.getTopLeft(find.text('B'));

      // Drag 3rd item past the top-left edge ("before" 1st item).
      final gesture = await tester.startGesture(thirdCenter);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(firstTopLeft - const Offset(16, 16));
      await tester.pump(const Duration(milliseconds: 32));

      // Verify A & B are smoothly in transit rather than teleporting instantly.
      final midAPos = tester.getTopLeft(find.text('A'));
      expect(midAPos.dx, greaterThan(initialAPos.dx));
      expect(midAPos.dx, lessThan(initialBPos.dx));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(reordered, equals((2, 0)));
      expect(items, equals(['C', 'A', 'B', 'D']));
    },
  );
}
