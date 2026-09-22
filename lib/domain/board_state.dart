import 'board_underlay.dart';
import 'light_element.dart';
import 'light_structure.dart';

class BoardState {
  BoardState({
    List<LightElement> elements = const [],
    List<LightStructure> structures = const [],
    this.title = 'Untitled Table',
    this.underlay = BoardUnderlay.none,
    Map<String, Object?> tableData = const {},
  }) : elements = List.unmodifiable(elements),
       structures = List.unmodifiable(structures),
       tableData = Map<String, Object?>.unmodifiable(tableData) {
    _elementsById = Map<String, LightElement>.unmodifiable(
      _indexElements(this.elements),
    );
    _structureByElementId = Map<String, LightStructure>.unmodifiable(
      _indexStructures(this.structures),
    );
  }

  static BoardState empty({String title = 'Untitled Table'}) =>
      BoardState(title: title);

  final List<LightElement> elements;
  final List<LightStructure> structures;
  final String title;
  final BoardUnderlay underlay;
  final Map<String, Object?> tableData;

  late final Map<String, LightElement> _elementsById;
  late final Map<String, LightStructure> _structureByElementId;

  static Map<String, LightElement> _indexElements(
    Iterable<LightElement> elements,
  ) {
    final result = <String, LightElement>{};
    for (final element in elements) {
      result.putIfAbsent(element.id, () => element);
    }
    return result;
  }

  static Map<String, LightStructure> _indexStructures(
    Iterable<LightStructure> structures,
  ) {
    final result = <String, LightStructure>{};
    for (final structure in structures) {
      for (final id in structure.memberIds) {
        result.putIfAbsent(id, () => structure);
      }
    }
    return result;
  }

  LightElement? elementById(String id) => _elementsById[id];

  LightStructure? structureForElement(String id) => _structureByElementId[id];

  BoardState copyWith({
    List<LightElement>? elements,
    List<LightStructure>? structures,
    String? title,
    BoardUnderlay? underlay,
    Map<String, Object?>? tableData,
  }) => BoardState(
    elements: elements ?? this.elements,
    structures: structures ?? this.structures,
    title: title ?? this.title,
    underlay: underlay ?? this.underlay,
    tableData: tableData ?? this.tableData,
  );

  BoardState add(LightElement element) =>
      copyWith(elements: [...elements, element]);

  BoardState remove(String id) {
    final nextStructures = <LightStructure>[];
    for (final structure in structures) {
      final members = structure.memberIds
          .where((member) => member != id)
          .toList();
      if (members.length >= 2) {
        nextStructures.add(structure.copyWith(memberIds: members));
      }
    }
    return copyWith(
      elements: elements.where((element) => element.id != id).toList(),
      structures: nextStructures,
    );
  }

  BoardState replace(LightElement replacement) => copyWith(
    elements: [
      for (final element in elements)
        if (element.id == replacement.id) replacement else element,
    ],
  );

  BoardState replaceMany(Iterable<LightElement> replacements) {
    final byId = {for (final element in replacements) element.id: element};
    return copyWith(
      elements: [for (final element in elements) byId[element.id] ?? element],
    );
  }

  BoardState upsertStructure(LightStructure replacement) => copyWith(
    structures: [
      for (final structure in structures)
        if (structure.id == replacement.id) replacement else structure,
      if (!structures.any((structure) => structure.id == replacement.id))
        replacement,
    ],
  );

  BoardState removeStructure(String id) => copyWith(
    structures: structures.where((structure) => structure.id != id).toList(),
  );

  Map<String, Object> toJson() => {
    'format': 'lighthouse-board',
    'version': 4,
    'title': title,
    'underlay': underlay.name,
    'tableData': tableData,
    'elements': elements.map((element) => element.toJson()).toList(),
    'structures': structures.map((structure) => structure.toJson()).toList(),
  };

  factory BoardState.fromJson(Map<String, Object?> json) {
    if (json['format'] != 'lighthouse-board') {
      throw const FormatException('Unsupported LightHouse board document.');
    }

    final version = json['version'];
    if (version != 1 && version != 2 && version != 3 && version != 4) {
      throw const FormatException('Unsupported LightHouse board version.');
    }

    final rawElements = json['elements']! as List;
    final elements = rawElements
        .map(
          (entry) =>
              LightElement.fromJson((entry as Map).cast<String, Object?>()),
        )
        .toList();
    final elementIds = {for (final element in elements) element.id};

    if (version == 1) {
      return BoardState(elements: elements);
    }

    final rawStructures = (json['structures'] as List?) ?? const [];
    return BoardState(
      title: (json['title'] as String?) ?? 'Untitled Table',
      underlay: version == 3 || version == 4
          ? BoardUnderlay.fromName(json['underlay'])
          : BoardUnderlay.none,
      tableData: version == 4 && json['tableData'] is Map
          ? (json['tableData'] as Map).cast<String, Object?>()
          : const {},
      elements: elements,
      structures: rawStructures
          .map(
            (entry) =>
                LightStructure.fromJson((entry as Map).cast<String, Object?>()),
          )
          .where((structure) => structure.memberIds.every(elementIds.contains))
          .toList(),
    );
  }
}
