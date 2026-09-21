# Changelog

## Unreleased
- Expanded ZENDO support: optically normalized Pyramid Love toy icons; Pyramid Die pips moved to the triangle bases; physically derived medium pyramid/wedge/block footprints with direct move/rotate/orientation controls; a main ZENDO menu for choosing pyramid, boxed, or combined piece sets; glare on placed marking stones; a sourced BoardGameGeek community secret-rule library with hide/show controls; controller-only secret-rule display during Remote sessions; and Remote synchronization for boxed footprints.
- Polished Dice Bubble readability and hidden-companion behavior: larger standard pips, larger diagonal Treehouse labels, vector Fate plus/minus marks, source-informed selector artwork, and a more spider-like eight-legged skitter with articulated gait; the spider stays hidden while the selector drawer is open. Adjusted Nest Cycle, Zendo Stones, and Triangle Bounce icon optical sizing between the Toys menu and on-screen controls.
- Refined Pyramid Love toy artwork and Dice Bubble behavior: Nest Cycle now uses Nest.svg, Zendo Stones uses ComponentZendoMarkers.svg, and Triangle Bounce uses EastQueen.svg; Pyramid Die marks use the measured tall isosceles pyramid profile; Treehouse Die labels are larger and diagonal; added a Fudge/Fate die (+,+,-,-,blank,blank); die selector tiles now cycle counts within the three-die capacity; and an empty Dice Bubble contains a white spider that skitters when activated.
- Integrated Pyramid Love 3.1 reference artwork: The Wheel now follows the supplied source topology with 30 source-derived snap regions; Pyramid, Color, and Lightning dice use the supplied Arcade symbol conventions; Lightning and Treehouse dice are black; and supported board menus use source-informed component marks. Added the supplied Pyramid Love license and attribution without bundling the font binary.
- Expanded Remote to support multiple controllers sharing one board-authoritative Board Display; added controller controls for Board Unit shape interaction, shape visibility, and persistent normal/dim/off ripple marking; scaled Dice Bubble, Zendo Stones, and guns to the controlled display; improved gun synchronization; changed the Dice Bubble latch to solid light gray; and replaced physical-die selector duplicates with one selector per die kind that can add 0–3 copies within the three-die bubble limit.
- Refactored Remote application messaging behind a transport boundary, moved pairing secrets from URL query parameters into the URL fragment while retaining legacy-link compatibility, and made the internet relay disconnect after a direct WebRTC link is established and reconnect automatically if that direct link fails.
- Fixed Remote controller geometry so display dimensions are recovered from hello/state traffic, the controlled screen appears as a visible letterboxed rectangle, and Dice Bubble/Zendo overlays stay inside that same remote frame.
- Added two-device Remote sessions: either device can be the Board Display or Controller, pairing uses a QR/link, controller coordinates scale to the display board, transient toy effects plus Dice Bubble and Zendo Stone state are mirrored to the display, roles can be swapped without re-pairing, WebRTC is preferred for direct transport, and encrypted relay messaging provides pairing/fallback.
- Added **File → Restore Previous Autosave…** so the automatically retained recovery snapshot can be restored deliberately; restoration is undoable.
- Made continuous toy timing use actual elapsed time, cached Red Sweep footprint bounds between board changes, and indexed immutable board-state lookups to reduce repeated work.
- Removed the obsolete alternate board-screen implementation and normalized the active board screen/file naming.
- Removed the iPhone/iPad web rotation-compensation workaround and its orientation polling/bridge code.
- Reduced runtime overhead by debouncing and serializing board saves, coalescing touch transforms to display frames, pausing sensors and toy animation while backgrounded, throttling motion sampling, adding cheap collision broad-phase checks, tightening painter invalidation, and isolating continuous toy animation from the rest of the interface.
- Refined Safety Tips, dice bubble, Zendo stones, menus, Launchpad 23, Sandships, Petal Battle, and World War 5 labels.

- Refined flat-pyramid rendering, live constellation anchors, radar trails, side guns, and concise device instructions.
- Rebuilt the dice toy as a movable Pop-O-Matic-style bubble with up to three selectable Pyramid Arcade dice and research-informed damped rolling.
- Added independent movable Zendo marking/guessing stones.
- Redesigned credits with an Art Deco lighthouse mark, explicit orientation recalibration control, and the LightHouse haiku.
- Added Sandships and Martian Backgammon boards, turned World War 5 sideways, tightened Petal Battle, and corrected Wheel snapping for flat pyramids.
- Expanded Toys into a full opt-in tray: Light Lottery, Entropy Delete, Ghost Paths, Random Event Zone, Turn Timer, Breathing, Nest Cycle, Radar, Red Sweep, D6, Side Guns, Corner Ricochet, Hot Potato, Constellation Draw, Heartbeat, Triangle Bounce, and Square Chase. Each toy has a persistent menu visibility toggle and its own board icon.
- Reworked iPhone/iPad web face-down credits to use a direct browser Device Motion bridge with gravity data after permission is granted; the face-up Z-axis sign is learned from stable samples, credits appear only while face-down, and vanish when face-up.
- Moved rotation-snap degree ticks flush against the inside edge of the hollow menu circle.
- Changed Light Lottery to a completely regular 120 ms flashing cadence while randomizing which single footprint flashes on each beat and randomizing the total run time before the winner is selected.
- Added a Toys submenu with persistent on/off visibility controls for Light Lottery and Entropy Delete; each enabled toy has its own tappable board icon.
- Refined board menus into Board > File and Board > Underlays, with Mac-like file ordering.
- Added The Wheel, Looney Ludo four-board start, and Launchpad 23 underlays plus optional grid snapping.
- Added exact rotation controls and persistent rotation snap increments, reflected by tick marks in the menu circle.
- Moved the menu and device-specific instructions to the lower left.
- Removed the user-facing Structure menu while retaining structure semantics internally.

## 0.3.1 - 2026-09-09

Physical interaction refinement from hands-on testing.

### Changed

- collision pushing now resolves continuously while dragging so contact is visible
- wall-only illumination is preserved when a footprint is tipped and stood again
- tipping now uses an exact inside-square to outside-square line rather than an interaction halo
- standing now uses point-to-base travel within the actual flat triangle
- replaced scribble illumination switching with tolerant encirclement detection around an upright footprint
- overlapping different-size wall-only upright footprints automatically align as a nest, anchored to the largest member
- removed the separate snap, ruler, board-title, undo, and redo controls from the board surface
- replaced the ellipsis control with a thin hollow-circle menu control
- reorganized commands into Board, Edit, Structure, Display, Transfer, and About submenus
- locked the active board to one exact display orientation
- added a face-down device gesture that reveals credits on supported native devices

### Tested

- added regression tests for preserved wall illumination, live collision pushing, and automatic wall-only nesting

## 0.3.0 - 2026-09-08

Major LightHouse 2 development milestone.

### Added

- physical millimeter-native board model
- automatic iPhone calibration and Android reported-DPI calibration
- ruler and Large-pyramid manual calibration
- quick calibration verification
- full/wall illumination for upright footprints
- touch tipping, standing, scribble switching, translation, and rotation
- desktop mouse translation and Shift-drag rotation
- stack/nest structure model and grouped transforms
- convex polygon collision separation for pushing
- undo/redo for semantic board operations
- autosave with recovery backup
- named board library and JSON clipboard import/export
- native brightness control, screen wake lock, haptics, safe-board insets, and orientation handling
- installable PWA metadata and GitHub Pages deployment
- CI formatting, analysis, tests, and unsigned iOS build validation

### Changed

- replaced the React / TypeScript / AI Studio prototype architecture with Flutter / Dart
- replaced pixel-domain positions and gesture thresholds with physical millimeters
- replaced rendered square/triangle domain objects with light footprints and physical pose
- upgraded the board document format from version 1 to version 2; version 1 documents migrate automatically

## 0.2.0

Initial clean-sheet Flutter rewrite foundation.

## 0.1.0
