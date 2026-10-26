class TransactionFilter {
  const TransactionFilter({
    this.type = 'all', this.accountId, this.query = '',
    this.start, this.end, this.reconciled,
  });
  final String type, query;
  final String? accountId;
  final DateTime? start, end;
  final bool? reconciled;

  bool get isActive => type != 'all' || accountId != null ||
      query.trim().isNotEmpty || start != null || end != null || reconciled != null;

  TransactionFilter copyWith({
    String? type, String? accountId, String? query,
    DateTime? start, DateTime? end, bool? reconciled,
    bool clearAccount = false, bool clearDates = false,
    bool clearReconciled = false,
  }) => TransactionFilter(
    type: type ?? this.type,
    accountId: clearAccount ? null : accountId ?? this.accountId,
    query: query ?? this.query,
    start: clearDates ? null : start ?? this.start,
    end: clearDates ? null : end ?? this.end,
    reconciled: clearReconciled ? null : reconciled ?? this.reconciled,
  );

  bool matches(Map<String, dynamic> tx) {
    final external = ['credit_card_payment', 'debt_payment', 'receivable_loan'].contains(tx['source']);
    if (reconciled != null && (external || tx['is_reconciled'] != reconciled)) {
      return false;
    }
    if (type != 'all' && tx['transaction_type'] != type) {
      return false;
    }
    if (accountId != null) {
      final originMatches = tx['account_id']?.toString() == accountId;
      final destinationMatches = tx['transaction_type'] == 'transfer' &&
          tx['destination_account_id']?.toString() == accountId;
      if (!originMatches && !destinationMatches) { return false; }
    }
    final text = query.trim().toLowerCase();
    if (text.isNotEmpty) {
      final found = [tx['description'], tx['reference']].any(
              (value) => (value?.toString() ?? '').toLowerCase().contains(text));
      if (!found) { return false; }
    }
    if (start != null || end != null) {
      final date = DateTime.tryParse('${tx['transaction_date']}')?.toLocal();
      if (date == null) { return false; }
      final day = DateTime(date.year, date.month, date.day);
      final from = start;
      final until = end;
      if (from != null &&
          day.isBefore(DateTime(from.year, from.month, from.day))) {
        return false;
      }
      if (until != null &&
          day.isAfter(DateTime(until.year, until.month, until.day))) {
        return false;
      }
    }
    return true;
  }
}