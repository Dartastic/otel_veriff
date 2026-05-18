// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_veriff/otel_veriff.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_veriff-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('decisions.get records code + reason + attempts', () async {
    await tracedVeriff<String>(
      operation: 'decisions.get',
      invoke: () async => const VeriffCallResult(
        value: 'ok',
        result: VeriffResult(
          sessionId: 's-1',
          status: 'approved',
          code: 9101,
          attempts: 1,
          documentType: 'DRIVERS_LICENSE',
          documentCountry: 'GB',
          flowKind: 'id_verification',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('veriff decisions.get')!);
    expect(a['veriff.session.id'], 's-1');
    expect(a['veriff.decision.code'], 9101);
    expect(a['veriff.attempts'], 1);
    expect(a['veriff.document.type'], 'DRIVERS_LICENSE');
    expect(a['veriff.document.country'], 'GB');
  });

  test('declined sets span error', () async {
    await tracedVeriff<String>(
      operation: 'sessions.get',
      invoke: () async => const VeriffCallResult(
        value: 'ok',
        result: VeriffResult(
          status: 'declined',
          code: 9103,
          reason: 'document_invalid',
        ),
      ),
    );
    final s = spans.findSpanByName('veriff sessions.get')!;
    expect(s.status, SpanStatusCode.Error);
    final a = attrsOf(s);
    expect(a['veriff.decision.reason'], 'document_invalid');
  });

  test('suppression skips spans', () async {
    await runWithoutVeriffInstrumentationAsync(() async {
      await tracedVeriff<String>(
        operation: 'sessions.create',
        invoke: () async => const VeriffCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('veriff '), isEmpty);
  });
}
