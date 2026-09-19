enum RemoteRippleLevel {
  dim,
  normal;

  int get wireValue => this == RemoteRippleLevel.normal ? 2 : 1;

  static RemoteRippleLevel? fromWireValue(Object? raw) => switch (raw) {
    2 => RemoteRippleLevel.normal,
    1 => RemoteRippleLevel.dim,
    _ => null,
  };
}

class RemoteBoardControlState {
  const RemoteBoardControlState({
    this.displayInteractionsEnabled = false,
    this.displayShapesVisible = true,
    this.rippleLevels = const {},
  });

  final bool displayInteractionsEnabled;
  final bool displayShapesVisible;
  final Map<String, RemoteRippleLevel> rippleLevels;

  RemoteBoardControlState copyWith({
    bool? displayInteractionsEnabled,
    bool? displayShapesVisible,
    Map<String, RemoteRippleLevel>? rippleLevels,
  }) => RemoteBoardControlState(
    displayInteractionsEnabled:
        displayInteractionsEnabled ?? this.displayInteractionsEnabled,
    displayShapesVisible: displayShapesVisible ?? this.displayShapesVisible,
    rippleLevels: rippleLevels ?? this.rippleLevels,
  );

  RemoteBoardControlState cycleRipple(String elementId) {
    final next = Map<String, RemoteRippleLevel>.from(rippleLevels);
    final current = next[elementId];
    if (current == null) {
      next[elementId] = RemoteRippleLevel.normal;
    } else if (current == RemoteRippleLevel.normal) {
      next[elementId] = RemoteRippleLevel.dim;
    } else {
      next.remove(elementId);
    }
    return copyWith(rippleLevels: Map.unmodifiable(next));
  }

  RemoteBoardControlState clearRipples() =>
      copyWith(rippleLevels: const <String, RemoteRippleLevel>{});

  RemoteBoardControlState retainElementIds(Set<String> ids) {
    if (rippleLevels.keys.every(ids.contains)) return this;
    return copyWith(
      rippleLevels: Map.unmodifiable({
        for (final entry in rippleLevels.entries)
          if (ids.contains(entry.key)) entry.key: entry.value,
      }),
    );
  }

  Map<String, Object?> toJson() => {
    'displayInteractionsEnabled': displayInteractionsEnabled,
    'displayShapesVisible': displayShapesVisible,
    'rippleLevels': {
      for (final entry in rippleLevels.entries)
        entry.key: entry.value.wireValue,
    },
  };

  static RemoteBoardControlState fromJson(Object? raw) {
    if (raw is! Map) return const RemoteBoardControlState();
    final map = raw.cast<Object?, Object?>();
    final ripples = <String, RemoteRippleLevel>{};
    final rawRipples = map['rippleLevels'];
    if (rawRipples is Map) {
      for (final entry in rawRipples.entries) {
        if (entry.key is! String) continue;
        final level = RemoteRippleLevel.fromWireValue(entry.value);
        if (level != null) ripples[entry.key as String] = level;
      }
    }
    return RemoteBoardControlState(
      displayInteractionsEnabled: map['displayInteractionsEnabled'] == true,
      displayShapesVisible: map['displayShapesVisible'] != false,
      rippleLevels: Map.unmodifiable(ripples),
    );
  }
}
