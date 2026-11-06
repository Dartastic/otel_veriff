// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_veriff/otel_veriff.dart';

/// Traces Veriff calls with OpenTelemetry.
///
/// `otel_veriff` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Veriff call in
/// [tracedVeriff]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'veriff-example');

  // Wraps a Veriff API call in a CLIENT span.
  final veriffId = await tracedVeriff<String>(
    operation: 'sessions.create',
    invoke: () async {
      // Make the Veriff call here, then report what it returned.
      const id = 'veriff_8f3a2c';
      return const VeriffCallResult(
          value: id,
          result: VeriffResult(
              sessionId: 'session_8f3a2c',
              status: 'created',
              code: 1,
              reason: 'document_invalid',
              attempts: 1,
              documentType: 'PASSPORT',
              documentCountry: 'example',
              flowKind: 'id_verification',
              requestId: 'request_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedVeriff sessions.create returned $veriffId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutVeriffInstrumentationAsync.
  await runWithoutVeriffInstrumentationAsync(
    () => tracedVeriff<String>(
      operation: 'sessions.create',
      invoke: () async {
        const id = 'veriff_8f3a2c';
        return const VeriffCallResult(
            value: id,
            result: VeriffResult(
                sessionId: 'session_8f3a2c',
                status: 'created',
                code: 1,
                reason: 'document_invalid',
                attempts: 1,
                documentType: 'PASSPORT',
                documentCountry: 'example',
                flowKind: 'id_verification',
                requestId: 'request_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
