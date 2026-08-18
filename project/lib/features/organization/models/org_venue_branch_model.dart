/// Model representing a physical campus branch, auditorium, or training venue of an Organization.
class OrgVenueBranchModel {
  final String venueId;
  final String nameEn;
  final String nameAr;
  final String cityEn;
  final String cityAr;
  final double latitude;
  final double longitude;
  final int seatingCapacity;
  final bool isMainHeadquarters;
  final String? roomNumberOrHall;
  final List<String> availableFacilities;
  final String? addressEn;
  final String? addressAr;

  const OrgVenueBranchModel({
    required this.venueId,
    required this.nameEn,
    required this.nameAr,
    required this.cityEn,
    required this.cityAr,
    required this.latitude,
    required this.longitude,
    required this.seatingCapacity,
    this.isMainHeadquarters = false,
    this.roomNumberOrHall,
    this.availableFacilities = const [],
    this.addressEn,
    this.addressAr,
  });

  String getLocalizedName(String languageCode) =>
      languageCode == 'ar' ? nameAr : nameEn;

  String getLocalizedCity(String languageCode) =>
      languageCode == 'ar' ? cityAr : cityEn;

  String getLocalizedAddress(String languageCode) =>
      languageCode == 'ar' ? (addressAr ?? nameAr) : (addressEn ?? nameEn);

  factory OrgVenueBranchModel.fromJson(Map<String, dynamic> json) {
    return OrgVenueBranchModel(
      venueId: json['venue_id'] as String,
      nameEn: json['name_en'] as String,
      nameAr: json['name_ar'] as String,
      cityEn: json['city_en'] as String,
      cityAr: json['city_ar'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      seatingCapacity: json['seating_capacity'] as int? ?? 100,
      isMainHeadquarters: json['is_main_headquarters'] as bool? ?? false,
      roomNumberOrHall: json['room_number_or_hall'] as String?,
      availableFacilities: (json['available_facilities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      addressEn: json['address_en'] as String?,
      addressAr: json['address_ar'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'venue_id': venueId,
      'name_en': nameEn,
      'name_ar': nameAr,
      'city_en': cityEn,
      'city_ar': cityAr,
      'latitude': latitude,
      'longitude': longitude,
      'seating_capacity': seatingCapacity,
      'is_main_headquarters': isMainHeadquarters,
      'room_number_or_hall': roomNumberOrHall,
      'available_facilities': availableFacilities,
      'address_en': addressEn,
      'address_ar': addressAr,
    };
  }

  OrgVenueBranchModel copyWith({
    String? venueId,
    String? nameEn,
    String? nameAr,
    String? cityEn,
    String? cityAr,
    double? latitude,
    double? longitude,
    int? seatingCapacity,
    bool? isMainHeadquarters,
    String? roomNumberOrHall,
    List<String>? availableFacilities,
    String? addressEn,
    String? addressAr,
  }) {
    return OrgVenueBranchModel(
      venueId: venueId ?? this.venueId,
      nameEn: nameEn ?? this.nameEn,
      nameAr: nameAr ?? this.nameAr,
      cityEn: cityEn ?? this.cityEn,
      cityAr: cityAr ?? this.cityAr,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      seatingCapacity: seatingCapacity ?? this.seatingCapacity,
      isMainHeadquarters: isMainHeadquarters ?? this.isMainHeadquarters,
      roomNumberOrHall: roomNumberOrHall ?? this.roomNumberOrHall,
      availableFacilities: availableFacilities ?? this.availableFacilities,
      addressEn: addressEn ?? this.addressEn,
      addressAr: addressAr ?? this.addressAr,
    );
  }
}
