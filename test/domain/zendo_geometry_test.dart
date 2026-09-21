import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/domain/pyramid_geometry.dart';
import 'package:lighthouse/domain/zendo_geometry.dart';

void main() {
  const geometry = PyramidGeometryProfile.prototype2025;

  test('boxed Zendo pieces share medium base and derived upright height', () {
    expect(zendoMediumBaseMm(geometry), geometry.mediumBaseMm);
    expect(zendoPieceHeightMm(geometry), closeTo(33.485997, 0.001));
    expect(zendoWedgeSlantMm(geometry), geometry.mediumFlatLengthMm);
  });

  test('flat boxed Zendo footprints differ in the expected dimensions', () {
    final pyramid = zendoLocalFootprint(
      ZendoPieceShape.pyramid,
      ZendoPieceOrientation.pyramidFlat,
      geometry,
    );
    final block = zendoLocalFootprint(
      ZendoPieceShape.block,
      ZendoPieceOrientation.blockFlat,
      geometry,
    );
    final cheesecake = zendoLocalFootprint(
      ZendoPieceShape.wedge,
      ZendoPieceOrientation.wedgeCheesecake,
      geometry,
    );
    final doorstop = zendoLocalFootprint(
      ZendoPieceShape.wedge,
      ZendoPieceOrientation.wedgeDoorstop,
      geometry,
    );

    double width(List<dynamic> points) {
      final xs = points.map<double>((p) => p.xMm as double).toList();
      return xs.reduce((a, b) => a > b ? a : b) -
          xs.reduce((a, b) => a < b ? a : b);
    }

    double height(List<dynamic> points) {
      final ys = points.map<double>((p) => p.yMm as double).toList();
      return ys.reduce((a, b) => a > b ? a : b) -
          ys.reduce((a, b) => a < b ? a : b);
    }

    expect(width(pyramid), closeTo(geometry.mediumBaseMm, 0.001));
    expect(height(pyramid), closeTo(geometry.mediumFlatLengthMm, 0.001));

    expect(width(block), closeTo(geometry.mediumBaseMm, 0.001));
    expect(height(block), closeTo(zendoPieceHeightMm(geometry), 0.001));

    expect(width(cheesecake), closeTo(geometry.mediumBaseMm, 0.001));
    expect(height(cheesecake), closeTo(zendoPieceHeightMm(geometry), 0.001));

    expect(width(doorstop), closeTo(geometry.mediumBaseMm, 0.001));
    expect(height(doorstop), closeTo(geometry.mediumFlatLengthMm, 0.001));
  });

  test('wedge cycles upright, cheesecake, doorstop', () {
    var pose = ZendoPieceOrientation.upright;
    pose = nextZendoOrientation(ZendoPieceShape.wedge, pose);
    expect(pose, ZendoPieceOrientation.wedgeCheesecake);
    pose = nextZendoOrientation(ZendoPieceShape.wedge, pose);
    expect(pose, ZendoPieceOrientation.wedgeDoorstop);
    pose = nextZendoOrientation(ZendoPieceShape.wedge, pose);
    expect(pose, ZendoPieceOrientation.upright);
  });
}
