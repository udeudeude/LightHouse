import 'dart:ui';

final pyramidLoveLightningBoltContours = _flattenSvg(_boltPath, 372, 512);
final pyramidLoveLightningAtomContours = _flattenSvg(_atomPath, 474, 512);
final pyramidLoveLightningSplitCircleContours = _flattenSvg(
  '$_splitCircleLeftPath $_splitCircleRightPath',
  529,
  512,
);
final pyramidLoveLightningArrowContours = _flattenSvg(_arrowPath, 512, 512);
final pyramidLoveLightningPyramidsContours = _flattenSvg(
  '$_pyramidsLargePath $_pyramidsSmallPath',
  523,
  512,
);
final pyramidLoveLightningRecycleContours = _flattenSvg(
  '$_recycleTopPath $_recycleBottomPath',
  649,
  512,
);

List<List<Offset>> _flattenSvg(String data, double width, double height) {
  final tokens = RegExp(r'[A-Za-z]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?')
      .allMatches(data)
      .map((match) => match.group(0)!)
      .toList(growable: false);
  final contours = <List<Offset>>[];
  var contour = <Offset>[];
  var index = 0;
  String? command;
  String? previousCommand;
  var current = Offset.zero;
  var start = Offset.zero;
  Offset? previousControl;

  bool isCommand(String token) =>
      token.length == 1 && RegExp(r'[A-Za-z]').hasMatch(token);
  bool hasNumber() => index < tokens.length && !isCommand(tokens[index]);
  double number() => double.parse(tokens[index++]);

  void finishContour() {
    if (contour.isEmpty) return;
    contours.add(contour);
    contour = <Offset>[];
  }

  void add(Offset point) {
    current = point;
    contour.add(point);
  }

  void cubic(Offset p0, Offset p1, Offset p2, Offset p3) {
    const segments = 6;
    for (var segment = 1; segment <= segments; segment += 1) {
      final t = segment / segments;
      final u = 1 - t;
      contour.add(
        Offset(
          u * u * u * p0.dx +
              3 * u * u * t * p1.dx +
              3 * u * t * t * p2.dx +
              t * t * t * p3.dx,
          u * u * u * p0.dy +
              3 * u * u * t * p1.dy +
              3 * u * t * t * p2.dy +
              t * t * t * p3.dy,
        ),
      );
    }
    current = p3;
    previousControl = p2;
  }

  while (index < tokens.length) {
    if (isCommand(tokens[index])) command = tokens[index++];
    final active = command;
    if (active == null) continue;

    switch (active) {
      case 'M':
        if (!hasNumber()) continue;
        finishContour();
        current = Offset(number(), number());
        start = current;
        contour = <Offset>[current];
        previousControl = null;
        previousCommand = 'M';
        command = 'L';
      case 'L':
        if (!hasNumber()) continue;
        add(Offset(number(), number()));
        previousControl = null;
        previousCommand = 'L';
      case 'l':
        if (!hasNumber()) continue;
        add(current + Offset(number(), number()));
        previousControl = null;
        previousCommand = 'l';
      case 'h':
        if (!hasNumber()) continue;
        add(Offset(current.dx + number(), current.dy));
        previousControl = null;
        previousCommand = 'h';
      case 'v':
        if (!hasNumber()) continue;
        add(Offset(current.dx, current.dy + number()));
        previousControl = null;
        previousCommand = 'v';
      case 'c':
        if (!hasNumber()) continue;
        final p0 = current;
        final p1 = current + Offset(number(), number());
        final p2 = current + Offset(number(), number());
        final p3 = current + Offset(number(), number());
        cubic(p0, p1, p2, p3);
        previousCommand = 'c';
      case 's':
        if (!hasNumber()) continue;
        final p0 = current;
        final p1 =
            (previousCommand == 'c' || previousCommand == 's') &&
                previousControl != null
            ? current * 2 - previousControl!
            : current;
        final p2 = current + Offset(number(), number());
        final p3 = current + Offset(number(), number());
        cubic(p0, p1, p2, p3);
        previousCommand = 's';
      case 'z':
      case 'Z':
        if (contour.isNotEmpty && contour.last != start) contour.add(start);
        current = start;
        previousControl = null;
        previousCommand = active;
        finishContour();
        command = null;
      default:
        throw FormatException('Unsupported Pyramid Love SVG command: $active');
    }
  }
  finishContour();

  final sourceScale = 1.22 / (width > height ? width : height);
  return [
    for (final sourceContour in contours)
      [
        for (final point in sourceContour)
          Offset(
            (point.dx - width / 2) * sourceScale,
            (point.dy - height / 2) * sourceScale,
          ),
      ],
  ];
}

// Exact standalone Pyramid Love 3.1 SVG path data for the six Lightning Die
// faces. These names are less obvious than the Lightning*.svg die drawings.
const _boltPath =
    'M30.192 512c4.177 0 8.353-1.258 12.076-4.026l230.966-172.093c7.346-5.485 10.517-15.247 7.749-24.154s-10.818-15.146-19.776-15.146h-37.739l79.606-84.034c5.887-6.19 7.548-15.548 4.428-23.6-3.221-8.051-10.818-13.285-19.171-13.285h-45.287l113.018-119.106c5.887-6.19 7.649-15.549 4.428-23.6s-10.819-13.234-19.171-13.234h-120.163c-5.485 0-10.869 2.264-14.744 6.39l-140.793 148.292c-5.837 6.19-7.598 15.499-4.378 23.6s10.718 13.234 19.171 13.234h72.258l-87.052 91.883c-5.837 6.19-7.598 15.548-4.378 23.6s10.718 13.284 19.172 13.284h51.678l-117.345 135.812c-3.22 3.825-4.63 8.555-4.881 13.385-0.302 5.485 1.056 11.070 4.881 15.498 4.076 4.83 9.662 7.296 15.448 7.296z';

const _atomPath =
    'M325.35 243.572l72.969-76.167c5.964 3.849 12.957 6.234 20.546 6.668 23.582 1.356 43.803-16.643 45.158-40.198 1.382-23.609-16.643-43.83-40.225-45.185-23.555-1.382-43.776 16.643-45.185 40.225-0.569 9.975 2.358 19.353 7.698 26.97l-70.096 73.159c-14.068-17.998-35.129-30.25-59.144-32.581v-92.024c19.651-3.876 34.452-21.142 34.452-41.959 0-23.609-19.163-42.773-42.8-42.773s-42.745 19.163-42.745 42.773c0 20.817 14.827 38.083 34.452 41.959v92.051c-18.025 1.735-34.397 9.081-47.408 20.248l-74.54-73.565c5.502-10.625 3.903-23.989-4.987-32.934-11.059-11.032-28.949-11.032-40.008 0-11.032 11.005-11.032 28.894 0 39.981 9.026 8.999 22.579 10.517 33.286 4.798l74.731 73.754c-11.465 14.556-18.377 32.933-18.377 52.884 0 2.331 0.162 4.662 0.352 6.966l-69.364 3.226c-4.797-19.435-22.769-33.394-43.477-32.418-23.609 1.111-41.824 21.115-40.74 44.697 1.111 23.609 21.142 41.851 44.724 40.74 20.763-0.949 37.352-16.562 40.279-36.376l71.532-3.361c3.822 13.282 10.707 25.209 19.869 34.993l-62.56 59.172c-10.246-5.8-23.365-4.852-32.636 3.416-11.683 10.382-12.686 28.244-2.304 39.899s28.244 12.685 39.899 2.304c9.704-8.647 11.927-22.416 6.451-33.53l63.698-60.202c11.927 8.565 26.13 14.204 41.553 15.694v89.829c-11.547 3.578-19.95 14.312-19.95 27.024 0 15.586 12.685 28.244 28.272 28.244 15.613 0 28.272-12.659 28.272-28.244 0-12.712-8.403-23.447-19.95-27.024v-89.829c13.010-1.247 25.181-5.502 35.834-11.954l88.175 72.562c-3.226 6.017-5.096 12.902-5.096 20.194 0 23.609 19.137 42.773 42.773 42.773 23.609 0 42.773-19.163 42.773-42.773 0-23.636-19.163-42.745-42.773-42.745-10.3 0-19.76 3.632-27.106 9.649l-85.031-69.933c13.336-12.279 22.823-28.705 26.265-47.3l61.557-2.846c4.093 11.358 15.233 19.218 27.919 18.622 15.586-0.678 27.675-13.959 26.916-29.545s-13.959-27.62-29.572-26.889c-12.685 0.596-23.067 9.487-26.048 21.169l-59.361 2.792c-0.108-13.336-3.334-25.886-8.918-37.081z';

const _splitCircleLeftPath =
    'M197.185 20.453c-59.055 16.228-108.027 53.005-141.299 100.921-28.903 41.627-46.044 91.415-46.044 144.516s17.14 102.986 46.044 144.516c20.645 29.623 47.34 54.685 78.787 73.411 19.301 11.523 40.042 21.269 62.56 27.463 1.776 0.576 3.649 0.768 5.618 0.768 4.513 0 9.026-1.488 12.771-4.321 5.233-4.033 8.354-10.226 8.354-16.9v-449.921c0-6.578-3.073-12.867-8.354-16.804-5.281-4.033-12.147-5.329-18.436-3.649z';
const _splitCircleRightPath =
    'M333.731 21.029c-6.385-1.921-13.204-0.576-18.485 3.457-5.329 4.033-8.402 10.226-8.402 16.852v449.104c0 6.577 3.073 12.867 8.45 16.804 3.649 2.928 8.162 4.321 12.675 4.321 1.969 0 3.937-0.288 5.81-0.768 21.75-6.194 41.818-15.748 60.687-27.031 75.475-45.18 124.831-127.136 124.831-217.831-0.096-113.452-76.291-214.085-185.567-244.909z';

const _arrowPath =
    'M30.053 349.020h261.363v87.137c0 8.127 4.962 15.5 12.57 18.666 2.457 1.039 5.056 1.512 7.655 1.512 5.245 0 10.538-2.032 14.413-5.907l170.21-170.304c3.781-3.781 5.907-8.931 5.907-14.318s-2.127-10.537-5.907-14.318l-170.257-170.21c-5.813-5.813-14.555-7.466-22.021-4.442-7.56 3.119-12.57 10.632-12.57 18.713v87.137h-261.363c-11.152 0-20.225 9.025-20.225 20.225v125.791c0 11.247 9.026 20.32 20.225 20.32z';

const _pyramidsLargePath =
    'M511.753 481.775l-177.306-448.099c-3.353-8.431-11.439-14.003-20.512-14.003s-17.257 5.523-20.512 13.954l-177.356 448.148c-0.888 2.219-0.789 4.536-0.888 6.805-0.296 4.832 0.394 9.615 3.156 13.757 4.043 6.065 10.897 9.664 18.194 9.664h354.663c7.298 0 14.151-3.599 18.293-9.664 2.811-4.092 3.452-8.925 3.155-13.707-0.098-2.317-0.049-4.635-0.887-6.853z';
const _pyramidsSmallPath =
    'M168.333 203.488c4.142-5.966 5.030-13.658 2.317-20.512l-59.118-149.251c-3.303-8.48-11.489-14.003-20.511-14.003s-17.159 5.523-20.511 14.003l-40.283 101.671-18.786 47.581c-2.761 6.853-1.923 14.546 2.219 20.512 3.796 5.572 9.96 8.776 16.567 9.22 0.591 0.099 1.134 0.444 1.726 0.444h118.138c7.346 0 14.201-3.6 18.244-9.664z';

const _recycleTopPath =
    'M272.053 203.55c-3.476-8.583-11.788-14.124-21.023-14.124l-62.906 0.108c26.836-46.99 77.574-78.118 133.907-78.118h0.217c25.369 0 49.543 5.921 71.816 17.709 10.919 5.704 23.359 6.899 35.038 3.314 11.625-3.694 21.295-11.626 26.999-22.49 5.649-10.811 6.791-23.196 3.205-34.876-3.586-11.788-11.571-21.349-22.382-27.053-35.147-18.578-74.803-28.357-114.786-28.357h-0.108c-107.072 0.108-201.161 70.132-233.755 169.87h-11.68l-43.894 0.108c-9.235 0-17.492 5.541-21.132 14.016-3.531 8.583-1.575 18.362 4.998 24.935l109.245 109.082c4.291 4.237 9.996 6.682 16.134 6.682 6.030 0 11.897-2.445 16.134-6.682l109.082-109.299c6.464-6.573 8.474-16.352 4.889-24.826z';
const _recycleBottomPath =
    'M522.539 181.387c-8.909-8.909-23.25-8.909-32.268 0l-109.028 109.299c-6.519 6.464-8.529 16.297-4.998 24.826 3.586 8.474 12.005 14.124 21.132 14.124h0.108l65.243-0.108c-24.337 53.346-78.009 90.666-140.372 90.774h-0.108c-30.258 0-59.538-8.8-84.799-25.26-7.66-5.161-16.46-7.606-25.043-7.606-14.939 0-29.607 7.334-38.407 20.697-13.907 21.132-8.040 49.652 13.147 63.558 37.863 24.935 81.92 38.298 127.334 39.656 2.662 0.108 5.215 0.652 7.769 0.652h0.108c1.901 0 3.694-0.543 5.649-0.652 63.558-1.466 123.206-26.401 168.295-71.707 31.073-30.964 52.531-68.991 63.558-110.114l55.899-0.108c9.235 0 17.601-5.649 21.023-14.124 3.586-8.474 1.576-18.361-4.889-24.826l-109.353-109.082z';
