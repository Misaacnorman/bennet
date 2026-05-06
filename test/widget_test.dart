import 'package:bennet/presentation/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('project smoke', () {
    expect(2 + 2, 4);
  });

  testWidgets('collapsed sidebar only shows the expand handle', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _testRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.text('Bennet'), findsNothing);
    expect(find.text('Overview'), findsNothing);
    expect(find.byIcon(Icons.insights_outlined), findsNothing);
  });

  testWidgets('expanded sidebar shows navigation destinations', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _testRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    // Collapse notch and the active nav row each show a chevron at route `/`.
    expect(find.byIcon(Icons.chevron_left), findsWidgets);
    expect(find.text('Bennet'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.byIcon(Icons.insights_outlined), findsOneWidget);
  });
}

GoRouter _testRouter() {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const BennetScaffold(title: 'Test', body: Text('Body')),
      ),
    ],
  );
}
