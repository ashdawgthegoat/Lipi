import 'patient_folder_item.dart';

export 'patient_folder_item.dart';

/// Backward-compatibility alias for [PatientFolderItem].
///
/// In the literal file-and-folder interaction architecture,
/// folders are literal folder objects sitting directly on the desk surface
/// rather than cards.
typedef PatientFolderCard = PatientFolderItem;
