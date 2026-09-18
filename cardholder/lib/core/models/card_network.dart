enum CardNetwork {
  visa,
  mastercard;

  String get label {
    switch (this) {
      case CardNetwork.visa:
        return 'Visa';
      case CardNetwork.mastercard:
        return 'Mastercard';
    }
  }
}
