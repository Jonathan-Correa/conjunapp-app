import 'api_client.dart';

/// Operaciones de dominio del residente sobre la API.
class ResidentApi {
  final ApiClient _client;

  ResidentApi(this._client);

  Future<List<Map<String, dynamic>>> listInvoices({bool onlyOpen = false}) async {
    final q = onlyOpen ? '?only_open=true' : '';
    final items = await _client.getList('/invoices$q');
    return items.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> payInvoice({
    required String invoiceId,
    required num amount,
    String method = 'PSE',
  }) async {
    final result = await _client.post('/payments', body: {
      'invoice_id': invoiceId,
      'amount': amount,
      'method': method,
      'gateway_reference': 'WEB-${DateTime.now().millisecondsSinceEpoch}',
    });
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> listCommonAreas() async {
    final items = await _client.getList('/common-areas');
    return items.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getCommonArea(String areaId) async {
    final result = await _client.get('/common-areas/$areaId');
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> getAvailability({
    required String areaId,
    required DateTime date,
    int? durationMinutes,
    String? excludeReservationId,
  }) async {
    final day = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final q = StringBuffer('/common-areas/$areaId/availability?date=$day');
    if (durationMinutes != null) q.write('&duration_minutes=$durationMinutes');
    if (excludeReservationId != null) q.write('&exclude_reservation_id=$excludeReservationId');
    final result = await _client.get(q.toString());
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> listReservations() async {
    final items = await _client.getList('/reservations');
    return items.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createReservation({
    required String residentId,
    required String commonAreaId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    final result = await _client.post('/reservations', body: {
      'resident_id': residentId,
      'common_area_id': commonAreaId,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
    });
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> cancelReservation(String reservationId) async {
    final result = await _client.patch('/reservations/$reservationId/cancel');
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> rescheduleReservation({
    required String reservationId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    final result = await _client.patch('/reservations/$reservationId/reschedule', body: {
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
    });
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> getReservationReceipt(String reservationId) async {
    final result = await _client.get('/reservations/$reservationId/receipt');
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> listVisitors() async {
    final items = await _client.getList('/visitors');
    return items.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createVisitor({
    required String residentId,
    required String visitorName,
    String? documentNumber,
    String? vehiclePlate,
    required DateTime validFrom,
    required DateTime validUntil,
  }) async {
    final result = await _client.post('/visitors', body: {
      'resident_id': residentId,
      'visitor_name': visitorName,
      'document_number': documentNumber,
      'vehicle_plate': vehiclePlate,
      'valid_from': validFrom.toUtc().toIso8601String(),
      'valid_until': validUntil.toUtc().toIso8601String(),
    });
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> listAnnouncements() async {
    final items = await _client.getList('/announcements');
    return items.cast<Map<String, dynamic>>();
  }
}
