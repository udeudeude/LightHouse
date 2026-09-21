import 'dart:math' as math;

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

  test('flat Zendo 2.0 block is a rectangle footprint', () {
    const block = LightElement(
      id: 'block',
      size: PyramidSize.medium,
      pose: PyramidPose.flat,
      position: PhysicalPoint.zero,
      headingDegrees: 0,
      illumination: IlluminationPattern.full,
      kind: LightPieceKind.block,
    );
    final polygon = polygonForElement(block, geometry);
    expect(polygon, hasLength(4));
    final width = polygon[1].xMm - polygon[0].xMm;
    final height = polygon[2].yMm - polygon[1].yMm;
    expect(width.abs(), closeTo(geometry.mediumBaseMm, 0.001));
    expect(height.abs(), closeTo(geometry.mediumFlatLengthMm, 0.001));
  });

  test('flat wedge supports triangular and sloped rectangular footprints', () {
    const triangle = LightElement(
      id: 'wedge-triangle',
      size: PyramidSize.medium,
      pose: PyramidPose.flat,
      position: PhysicalPoint.zero,
      headingDegrees: 0,
      illumination: IlluminationPattern.full,
      kind: LightPieceKind.wedge,
      wedgeFlatFace: WedgeFlatFace.triangle,
    );
    const rectangle = LightElement(
      id: 'wedge-rectangle',
      size: PyramidSize.medium,
      pose: PyramidPose.flat,
      position: PhysicalPoint.zero,
      headingDegrees: 0,
      illumination: IlluminationPattern.full,
      kind: LightPieceKind.wedge,
      wedgeFlatFace: WedgeFlatFace.rectangle,
    );

    final trianglePolygon = polygonForElement(triangle, geometry);
    final rectanglePolygon = polygonForElement(rectangle, geometry);
    expect(trianglePolygon, hasLength(3));
    expect(rectanglePolygon, hasLength(4));

    final expectedSlopedLength = math.sqrt(
      geometry.mediumBaseMm * geometry.mediumBaseMm +
          geometry.mediumFlatLengthMm * geometry.mediumFlatLengthMm,
    );
    final actualLength = rectanglePolygon[2].yMm - rectanglePolygon[1].yMm;
    expect(actualLength.abs(), closeTo(expectedSlopedLength, 0.001));
  });
}
