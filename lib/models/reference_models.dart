class AircraftType {
  final int id;
  final String code;
  final String name;
  final String? image;
  final bool active;

  const AircraftType({
    required this.id,
    required this.code,
    required this.name,
    this.image,
    this.active = true,
  });

  factory AircraftType.fromJson(Map<String, dynamic> j) => AircraftType(
    id: j['id'] as int,
    code: j['code'] as String,
    name: j['name'] as String,
    image: j['image'] as String?,
    active: j['active'] as bool? ?? true,
  );
}

class OrgUnit {
  final int id;
  final String code;
  final String name;

  const OrgUnit({required this.id, required this.code, required this.name});

  factory OrgUnit.fromJson(Map<String, dynamic> j) => OrgUnit(
    id: j['id'] as int,
    code: j['code'] as String,
    name: j['name'] as String,
  );
}

class FlightType {
  final int id;
  final String code;
  final String name;
  final List<String> maintainsCapacities;
  final String? requiredCapability;
  final int sortOrder;

  const FlightType({
    required this.id,
    required this.code,
    required this.name,
    this.maintainsCapacities = const [],
    this.requiredCapability,
    this.sortOrder = 0,
  });

  factory FlightType.fromJson(Map<String, dynamic> j) => FlightType(
    id: j['id'] as int,
    code: j['code'] as String,
    name: j['name'] as String,
    maintainsCapacities: List<String>.from(j['maintains'] as List? ?? []),
    requiredCapability: j['required_capability'] as String?,
    sortOrder: j['sort_order'] as int? ?? 0,
  );
}

class CapabilityType {
  final int id;
  final String code;
  final String name;
  final bool isBase;
  final int sortOrder;

  const CapabilityType({
    required this.id,
    required this.code,
    required this.name,
    this.isBase = false,
    this.sortOrder = 0,
  });

  factory CapabilityType.fromJson(Map<String, dynamic> j) => CapabilityType(
    id: j['id'] as int,
    code: j['code'] as String,
    name: j['name'] as String,
    isBase: j['is_base'] as bool? ?? false,
    sortOrder: j['sort_order'] as int? ?? 0,
  );
}
