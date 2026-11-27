/// How the app talks to its user. Vietnamese pronouns come in pairs, so we
/// keep both what the app calls the user ([name], e.g. "Bà", "Cô Lan") and
/// what the app calls itself ([self], e.g. "cháu").
class Address {
  /// What to call the user. Empty means the neutral "bạn".
  final String name;

  /// What the app calls itself: 'con', 'cháu', 'em' or 'mình'.
  final String self;

  const Address({this.name = '', this.self = 'mình'});

  static const selfOptions = <String, String>{
    'con': 'Con (gọi bố mẹ)',
    'cháu': 'Cháu (gọi ông bà, cô chú)',
    'em': 'Em (gọi anh chị)',
    'mình': 'Mình (bạn bè, ngang hàng)',
  };

  bool get hasName => name.trim().isNotEmpty;

  /// "Bà" / "bạn" for use mid-sentence.
  String get you => hasName ? name.trim() : 'bạn';

  /// Same, capitalised for the start of a sentence.
  String get You => _cap(you);

  /// The app's own pronoun, capitalised for the start of a sentence.
  String get Me => _cap(self);

  /// Younger speakers end sentences politely with "ạ".
  bool get polite => self == 'con' || self == 'cháu' || self == 'em';

  /// " ạ" or "" to end a sentence.
  String get a => polite ? ' ạ' : '';

  /// "Chào buổi sáng, Bà!" or "Chào buổi sáng!" when no name is set.
  String greet(String greeting) => hasName ? '$greeting, $You!' : '$greeting!';

  /// "Bà ơi, " or "" — used to open notifications.
  String get call => hasName ? '$You ơi, ' : '';

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
