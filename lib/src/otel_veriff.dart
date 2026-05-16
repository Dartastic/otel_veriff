// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_veriff_suppression.dart';

const _tracerName = 'dartastic_otel_libs_veriff';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class VeriffResult {
  const VeriffResult({
    this.sessionId,
    this.status,
    this.code,
    this.reason,
    this.attempts,
    this.documentType,
    this.documentCountry,
    this.flowKind,
    this.requestId,
    this.statusCode,
  });

  /// `sessionId`.
  final String? sessionId;

  /// `created` / `started` / `submitted` / `approved` /
  /// `resubmission_requested` / `declined` / `abandoned` / `review`.
  final String? status;

  /// Decision code (e.g. 9101 approved, 9102 resubmission, 9103
  /// declined, 9104 expired).
  final int? code;

  /// `reason` text for declines (`document_invalid`, `face_not_visible`,
  /// `id_expired`, etc.) — keep cardinality bounded.
  final String? reason;

  /// Number of attempts on this session (Veriff bills per session,
  /// but resubmissions affect SLAs).
  final int? attempts;

  /// `PASSPORT` / `ID_CARD` / `DRIVERS_LICENSE` / `RESIDENCE_PERMIT`.
  final String? documentType;

  /// ISO 3166 issuing country of the document.
  final String? documentCountry;

  /// `id_verification` / `aml` / `watchlist` / `database_check` /
  /// `biometric_auth`.
  final String? flowKind;

  /// `X-AUTH-CLIENT` request id (when present).
  final String? requestId;

  final int? statusCode;
}

class VeriffCallResult<T> {
  const VeriffCallResult({required this.value, this.result});
  final T value;
  final VeriffResult? result;
}

/// Wraps a Veriff API call in a CLIENT span. [operation] is one of
/// `sessions.create`, `sessions.get`, `sessions.update`,
/// `sessions.attempts`, `decisions.get`, `attempts.get`,
/// `attempts.images`, `media.get`, `watchlist.search`, `aml.search`,
/// `webhooks.create`.
Future<T> tracedVeriff<T>({
  required String operation,
  required Future<VeriffCallResult<T>> Function() invoke,
}) async {
  if (veriffInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'veriff',
    'rpc.method': operation,
    'veriff.operation': operation,
  };

  final span = _tracer().startSpan(
    'veriff $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.sessionId != null) {
        extras.add(OTel.attributeString(
          'veriff.session.id',
          r.result!.sessionId!,
        ));
      }
      if (r.result!.status != null) {
        extras.add(OTel.attributeString(
          'veriff.status',
          r.result!.status!,
        ));
        if (r.result!.status == 'declined' || r.result!.status == 'abandoned') {
          span.setStatus(
            SpanStatusCode.Error,
            'Veriff session ${r.result!.status}',
          );
        }
      }
      if (r.result!.code != null) {
        extras.add(OTel.attributeInt(
          'veriff.decision.code',
          r.result!.code!,
        ));
      }
      if (r.result!.reason != null) {
        extras.add(OTel.attributeString(
          'veriff.decision.reason',
          r.result!.reason!,
        ));
      }
      if (r.result!.attempts != null) {
        extras.add(OTel.attributeInt(
          'veriff.attempts',
          r.result!.attempts!,
        ));
      }
      if (r.result!.documentType != null) {
        extras.add(OTel.attributeString(
          'veriff.document.type',
          r.result!.documentType!,
        ));
      }
      if (r.result!.documentCountry != null) {
        extras.add(OTel.attributeString(
          'veriff.document.country',
          r.result!.documentCountry!,
        ));
      }
      if (r.result!.flowKind != null) {
        extras.add(OTel.attributeString(
          'veriff.flow.kind',
          r.result!.flowKind!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'veriff.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Veriff HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
