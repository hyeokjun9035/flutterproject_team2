class PlaceResult {
  final String name;
  final String address;
  final double lat; // y
  final double lng; // x
  final double? distanceM;

  PlaceResult({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.distanceM,
  });
}