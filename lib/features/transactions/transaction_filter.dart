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

  bool matches(Map<String, dynamic> tx) {
    if (reconciled != null &&
        (['credit_card_payment', 'debt_payment'].contains(tx['source']) ||
            tx['is_reconciled'] != reconciled)) return false;
    if (type != 'all' && tx['transaction_type'] != type) return false;
    if (accountId != null && tx['account_id']?.toString() != accountId &&
        !(tx['transaction_type'] == 'transfer' && tx['destination_account_id']?.toString() == accountId)) return false;
    final text = query.trim().toLowerCase();
    if (text.isNotEmpty && ![tx['description'], tx['reference']].any((v) => (v?.toString() ?? '').toLowerCase().contains(text))) return false;
    if (start != null || end != null) {
      final date = DateTime.tryParse('${tx['transaction_date']}')?.toLocal();
      if (date == null) return false;
      final day = DateTime(date.year, date.month, date.day);
      if (start != null && day.isBefore(DateTime(start!.year, start!.month, start!.day))) return false;
      if (end != null && day.isAfter(DateTime(end!.year, end!.month, end!.day))) return false;
    }
    return true;
  }
}
