import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/domain/convex_geometry.dart';
import 'package:lighthouse/domain/light_element.dart';
import 'package:lighthouse/domain/physical_point.dart';
import 'package:lighthouse/domain/pyramid_geometry.dart';

void main() {
  const geometry = PyramidGeometryProfile.prototype2025;

  LightElement upright(String id, double x) => LightElement(
    id: id,
    size: PyramidSize.large,
    pose: PyramidPose.upright,
    position: PhysicalPoint(x, 0),
    headingDegrees: 0,
    illumination: IlluminationPattern.full,
  );

  test('separated footprints do not collide', () {
    final a = polygonForElement(upright('a', 0), geometry);
    final b = polygonForElement(upright('b', 40), geometry);
    expect(minimumSeparationVector(a, b), isNull);
  });

  test('overlapping footprints produce a separation vector', () {
    final a = polygonForElement(upright('a', 0), geometry);
    final b = polygonForElement(upright('b', 10), geometry);
    final separation = minimumSeparationVector(a, b);
    expect(separation, isNotNull);
    expect(separation!.xMm, greaterThan(0));
  });
  test('Zendo wedge footprints are right triangle and distinct rectangle', () {
    const triangle = LightElement(
      id: 'wedge-triangle',
      size: PyramidSize.medium,
      pose: PyramidPose.wedgeTriangle,
      position: PhysicalPoint.zero,
      headingDegrees: 0,
      illumination: IlluminationPattern.full,
      kind: LightPieceKind.wedge,
    );
    const rectangle = LightElement(
      id: 'wedge-rectangle',
      size: PyramidSize.medium,
      pose: PyramidPose.wedgeRectangle,
      position: PhysicalPoint.zero,
      headingDegrees: 0,
      illumination: IlluminationPattern.full,
      kind: LightPieceKind.wedge,
    );

    final trianglePolygon = polygonForElement(triangle, geometry);
    final rectanglePolygon = polygonForElement(rectangle, geometry);

    expect(trianglePolygon, hasLength(3));
    expect(rectanglePolygon, hasLength(4));
    expect(
      geometry.footprintLengthMm(rectangle),
      greaterThan(geometry.footprintLengthMm(triangle)),
    );
  });

  test(
    'Zendo block flat footprint is medium-base by medium-height rectangle',
    () {
      const block = LightElement(
        id: 'block',
        size: PyramidSize.medium,
        pose: PyramidPose.blockFlat,
        position: PhysicalPoint.zero,
        headingDegrees: 0,
        illumination: IlluminationPattern.full,
        kind: LightPieceKind.block,
      );
      final polygon = polygonForElement(block, geometry);
      expect(polygon, hasLength(4));
      expect(geometry.footprintLengthMm(block), geometry.mediumFlatLengthMm);
    },
  );
}
