import 'physical_point.dart';

enum PyramidSize { small, medium, large }

enum PyramidPose { upright, flat }

enum LightPieceKind { pyramid, wedge, block }

enum WedgeFlatFace { triangle, rectangle }

enum IlluminationPattern { full, wall }

class LightElement {
  const LightElement({
    required this.id,
    required this.size,
    required this.pose,
    required this.position,
    required this.headingDegrees,
    required this.illumination,
    this.kind = LightPieceKind.pyramid,
    this.wedgeFlatFace = WedgeFlatFace.triangle,
  });

  final String id;
  final PyramidSize size;
  final PyramidPose pose;
  final PhysicalPoint position;
  final double headingDegrees;
  final IlluminationPattern illumination;
  final LightPieceKind kind;
  final WedgeFlatFace wedgeFlatFace;

  LightElement copyWith({
    PyramidSize? size,
    PyramidPose? pose,
    PhysicalPoint? position,
    double? headingDegrees,
    IlluminationPattern? illumination,
    LightPieceKind? kind,
    WedgeFlatFace? wedgeFlatFace,
  }) {
    return LightElement(
      id: id,
      size: size ?? this.size,
      pose: pose ?? this.pose,
      position: position ?? this.position,
      headingDegrees: headingDegrees ?? this.headingDegrees,
      illumination: illumination ?? this.illumination,
      kind: kind ?? this.kind,
      wedgeFlatFace: wedgeFlatFace ?? this.wedgeFlatFace,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'size': size.name,
    'pose': pose.name,
    'position': position.toJson(),
    'headingDegrees': headingDegrees,
    'illumination': illumination.name,
    'kind': kind.name,
    'wedgeFlatFace': wedgeFlatFace.name,
  };

  factory LightElement.fromJson(Map<String, Object?> json) => LightElement(
    id: json['id']! as String,
    size: PyramidSize.values.byName(json['size']! as String),
    pose: PyramidPose.values.byName(json['pose']! as String),
    position: PhysicalPoint.fromJson(
      (json['position']! as Map).cast<String, Object?>(),
    ),
    headingDegrees: (json['headingDegrees']! as num).toDouble(),
    illumination: IlluminationPattern.values.byName(
      json['illumination']! as String,
    ),
    kind: LightPieceKind.values.byName((json['kind'] as String?) ?? 'pyramid'),
    wedgeFlatFace: WedgeFlatFace.values.byName(
      (json['wedgeFlatFace'] as String?) ?? 'triangle',
    ),
  );

  @override
  bool operator ==(Object other) =>
      other is LightElement &&
      other.id == id &&
      other.size == size &&
      other.pose == pose &&
      other.position == position &&
      other.headingDegrees == headingDegrees &&
      other.illumination == illumination &&
      other.kind == kind &&
      other.wedgeFlatFace == wedgeFlatFace;

  @override
  int get hashCode =>
      Object.hash(
        id,
        size,
        pose,
        position,
        headingDegrees,
        illumination,
        kind,
        wedgeFlatFace,
      );
}
