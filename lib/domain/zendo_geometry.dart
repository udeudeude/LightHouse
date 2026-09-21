import 'dart:math' as math;

import 'physical_point.dart';
import 'pyramid_geometry.dart';

enum ZendoPieceShape { pyramid, wedge, block }

enum ZendoPieceOrientation {
  upright,
  pyramidFlat,
  wedgeCheesecake,
  wedgeDoorstop,
  blockFlat,
}

double zendoMediumBaseMm(PyramidGeometryProfile geometry) =>
    geometry.mediumBaseMm;

/// The boxed Zendo pieces share the open square base and upright height of a
/// medium Looney pyramid. The medium pyramid's flat triangular footprint gives
/// us the slant height, so the upright height follows from Pythagoras.
double zendoPieceHeightMm(PyramidGeometryProfile geometry) {
  final base = geometry.mediumBaseMm;
  final slant = geometry.mediumFlatLengthMm;
  return math.sqrt(slant * slant - base * base / 4);
}

/// A wedge is an isosceles triangular prism. Its rectangular Doorstop face has
/// the same slant length as a medium pyramid side face.
double zendoWedgeSlantMm(PyramidGeometryProfile geometry) =>
    geometry.mediumFlatLengthMm;

ZendoPieceOrientation defaultZendoOrientation(ZendoPieceShape shape) =>
    ZendoPieceOrientation.upright;

ZendoPieceOrientation nextZendoOrientation(
  ZendoPieceShape shape,
  ZendoPieceOrientation orientation,
) => switch (shape) {
  ZendoPieceShape.pyramid =>
    orientation == ZendoPieceOrientation.upright
        ? ZendoPieceOrientation.pyramidFlat
        : ZendoPieceOrientation.upright,
  ZendoPieceShape.block =>
    orientation == ZendoPieceOrientation.upright
        ? ZendoPieceOrientation.blockFlat
        : ZendoPieceOrientation.upright,
  ZendoPieceShape.wedge => switch (orientation) {
    ZendoPieceOrientation.upright => ZendoPieceOrientation.wedgeCheesecake,
    ZendoPieceOrientation.wedgeCheesecake =>
      ZendoPieceOrientation.wedgeDoorstop,
    _ => ZendoPieceOrientation.upright,
  },
};

List<PhysicalPoint> zendoLocalFootprint(
  ZendoPieceShape shape,
  ZendoPieceOrientation orientation,
  PyramidGeometryProfile geometry,
) {
  final base = zendoMediumBaseMm(geometry);
  final halfBase = base / 2;
  final height = zendoPieceHeightMm(geometry);
  final halfHeight = height / 2;
  final slant = zendoWedgeSlantMm(geometry);
  final halfSlant = slant / 2;

  if (orientation == ZendoPieceOrientation.upright) {
    return [
      PhysicalPoint(-halfBase, -halfBase),
      PhysicalPoint(halfBase, -halfBase),
      PhysicalPoint(halfBase, halfBase),
      PhysicalPoint(-halfBase, halfBase),
    ];
  }

  return switch ((shape, orientation)) {
    (ZendoPieceShape.pyramid, ZendoPieceOrientation.pyramidFlat) => [
      PhysicalPoint(0, -slant / 2),
      PhysicalPoint(halfBase, slant / 2),
      PhysicalPoint(-halfBase, slant / 2),
    ],
    (ZendoPieceShape.block, ZendoPieceOrientation.blockFlat) => [
      PhysicalPoint(-halfBase, -halfHeight),
      PhysicalPoint(halfBase, -halfHeight),
      PhysicalPoint(halfBase, halfHeight),
      PhysicalPoint(-halfBase, halfHeight),
    ],
    (ZendoPieceShape.wedge, ZendoPieceOrientation.wedgeCheesecake) => [
      PhysicalPoint(0, -height / 2),
      PhysicalPoint(halfBase, height / 2),
      PhysicalPoint(-halfBase, height / 2),
    ],
    (ZendoPieceShape.wedge, ZendoPieceOrientation.wedgeDoorstop) => [
      PhysicalPoint(-halfBase, -halfSlant),
      PhysicalPoint(halfBase, -halfSlant),
      PhysicalPoint(halfBase, halfSlant),
      PhysicalPoint(-halfBase, halfSlant),
    ],
    _ => zendoLocalFootprint(
      shape,
      ZendoPieceOrientation.upright,
      geometry,
    ),
  };
}

String zendoOrientationLabel(ZendoPieceOrientation orientation) =>
    switch (orientation) {
      ZendoPieceOrientation.upright => 'Upright',
      ZendoPieceOrientation.pyramidFlat => 'Flat',
      ZendoPieceOrientation.wedgeCheesecake => 'Cheesecake',
      ZendoPieceOrientation.wedgeDoorstop => 'Doorstop',
      ZendoPieceOrientation.blockFlat => 'Flat',
    };
