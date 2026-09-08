/// Prescription and consultation lifecycle status.
///
/// Follows ADR-0008 Section 4.3 and ADR-0006.
enum ConsultationStatus {
  draft,
  active,
  saved,
  closed;

  bool get isEditable => this != ConsultationStatus.closed;
}
