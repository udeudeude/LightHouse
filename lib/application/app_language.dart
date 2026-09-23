import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { english, spanish, japanese }

extension AppLanguageInfo on AppLanguage {
  String get code => switch (this) {
    AppLanguage.english => 'en',
    AppLanguage.spanish => 'es',
    AppLanguage.japanese => 'ja',
  };

  String get selfName => switch (this) {
    AppLanguage.english => 'English',
    AppLanguage.spanish => 'Español',
    AppLanguage.japanese => '日本語',
  };
}

class AppLanguageController {
  AppLanguageController._();

  static const _preferenceKey = 'lighthouse.language.v1';
  static final ValueNotifier<AppLanguage> notifier = ValueNotifier(
    AppLanguage.english,
  );

  static AppLanguage get current => notifier.value;

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final code = preferences.getString(_preferenceKey);
    notifier.value = AppLanguage.values.firstWhere(
      (language) => language.code == code,
      orElse: () => AppLanguage.english,
    );
  }

  static Future<void> set(AppLanguage language) async {
    if (notifier.value == language) return;
    notifier.value = language;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, language.code);
  }
}

String tr(String english) {
  final language = AppLanguageController.current;
  if (language == AppLanguage.english) return english;
  return switch (language) {
    AppLanguage.english => english,
    AppLanguage.spanish => _es[english] ?? _esExtra[english] ?? english,
    AppLanguage.japanese => _ja[english] ?? _jaExtra[english] ?? english,
  };
}

const _es = <String, String>{
  'Desktop / trackpad': 'Escritorio / panel táctil',
  'Android tablet': 'Tableta Android',
  'Android phone': 'Teléfono Android',
  'Touch device': 'Dispositivo táctil',
  'Light Lottery': 'Lotería de luz',
  'Entropy Delete': 'Borrado entrópico',
  'Turn Timer': 'Temporizador de turno',
  'Red Sweep': 'Barrido rojo',
  'Ghost Paths': 'Rastros fantasma',
  'Random Event Zone': 'Zona de evento aleatorio',
  'Breathing': 'Respiración',
  'Nest Cycle': 'Ciclo de nido',
  'Radar': 'Radar',
  'Dice Bubble': 'Burbuja de dados',
  'Side Guns': 'Cañones laterales',
  'Corner Ricochet': 'Rebote de esquina',
  'Hot Potato': 'Patata caliente',
  'Constellation Draw': 'Dibujar constelación',
  'Heartbeat': 'Latido',
  'Triangle Bounce': 'Rebote triangular',
  'Square Chase': 'Persecución cuadrada',
  'Press/release to roll; two-finger drag moves; latch tiles cycle die counts':
      'Pulsa y suelta para lanzar; arrastra con dos dedos para mover; las fichas del cierre cambian la cantidad de dados',
  'Tap or hold/release to roll; two-finger drag moves; latch tiles cycle die counts':
      'Toca o mantén y suelta para lanzar; arrastra con dos dedos para mover; las fichas del cierre cambian la cantidad de dados',
  'Tap or drag from tray; drag stones; double-click to remove':
      'Toca o arrastra desde la bandeja; arrastra las piedras; doble clic para quitar',
  'Tap or drag from tray; drag stones; double-tap to remove':
      'Toca o arrastra desde la bandeja; arrastra las piedras; doble toque para quitar',
  'Thanks for playing with LightHouse!': '¡Gracias por jugar con LightHouse!',
  'Menu': 'Menú', 'File': 'Archivo', 'Edit': 'Editar',
  'Boards': 'Tableros', 'Toys': 'Juguetes', 'Display': 'Pantalla',
  'Remote': 'Remoto', 'Instructions': 'Instrucciones',
  'New': 'Nuevo', 'Open…': 'Abrir…',
  'Restore Previous Autosave…': 'Restaurar autoguardado anterior…',
  'Save': 'Guardar', 'Save a Copy…': 'Guardar una copia…',
  'Rename…': 'Renombrar…',
  'Import Table JSON…': 'Importar JSON de mesa…',
  'Export Table JSON…': 'Exportar JSON de mesa…',
  'Undo': 'Deshacer', 'Redo': 'Rehacer',
  'Rotation Snap': 'Ajuste de rotación', 'Free Rotation': 'Rotación libre',
  'Snap Now': 'Ajustar ahora', 'Game Boards': 'Tableros de juego',
  'Grids': 'Cuadrículas', 'Martian Chess': 'Ajedrez marciano',
  'Snap pieces to board': 'Ajustar piezas al tablero', 'None': 'Ninguno',
  'Checker Shading': 'Sombreado ajedrezado', 'Size': 'Tamaño',
  'Safety Points': 'Puntas seguras', 'Brightness': 'Brillo',
  'Orientation Lock': 'Bloqueo de orientación',
  'Full-screen': 'Pantalla completa',
  'Zendo Off · Normal LightHouse': 'Zendo apagado · LightHouse normal',
  'Zendo Stones': 'Piedras Zendo', 'Classic': 'Clásico',
  'Classic + Zendo 2.0': 'Clásico + Zendo 2.0',
  'Zendo Rule': 'Regla Zendo',
  'Different Zendo Rule': 'Otra regla Zendo',
  'Complex Rules': 'Reglas complejas',
  'Hide Active Rule': 'Ocultar regla activa',
  'Show Active Rule': 'Mostrar regla activa',
  'Easy': 'Fácil', 'Medium': 'Media', 'Hard': 'Difícil',
  'This Device: Table Display': 'Este dispositivo: Pantalla de mesa',
  'This Device: Controller': 'Este dispositivo: Controlador',
  'Pair with 6-Character Code': 'Emparejar con código de 6 caracteres',
  'Pair with QR / Link': 'Emparejar con QR / enlace',
  'Add Another Controller': 'Añadir otro controlador',
  'Show Pairing QR': 'Mostrar QR de emparejamiento',
  'Swap Roles': 'Intercambiar funciones', 'Disconnect': 'Desconectar',
  'Turn Off All Ripples': 'Apagar todas las ondas',
  'Table Display Shape Interaction': 'Interacción con formas en la pantalla de mesa',
  'Table Display Shapes Visible': 'Formas visibles en la pantalla de mesa',
  'Create / resize / delete': 'Crear / redimensionar / eliminar',
  'Double-click': 'Doble clic', 'Double-tap': 'Doble toque',
  'Tip / stand': 'Tumbar / levantar',
  'Drag through the footprint edge': 'Arrastra atravesando el borde de la huella',
  'Full / wall light': 'Luz completa / pared',
  'Draw a loop around an upright footprint': 'Dibuja un bucle alrededor de una huella vertical',
  'Move': 'Mover',
  'Two-finger scroll over a footprint': 'Desplaza con dos dedos sobre una huella',
  'Rotate': 'Rotar', 'Shift + two-finger scroll': 'Mayús + desplazamiento con dos dedos',
  'Move + rotate': 'Mover + rotar',
  'Two-finger drag and twist': 'Arrastra y gira con dos dedos',
  'Rotation snap': 'Ajuste de rotación',
  'Edit > Rotation Snap; Snap Now aligns every shape immediately':
      'Editar > Ajuste de rotación; Ajustar ahora alinea todas las formas inmediatamente',
  'Board snap': 'Ajuste al tablero',
  'Boards > Snap pieces to board': 'Tableros > Ajustar piezas al tablero',
  'Dice bubble': 'Burbuja de dados',
  'Zendo stones': 'Piedras Zendo',
  'Remote ripple': 'Onda remota',
  'On a Controller, hold a shape to start its ripple; hold again to stop it':
      'En un Controlador, mantén una forma para iniciar su onda; mantén de nuevo para detenerla',
  'Toys chooses controls; hold an icon for its name':
      'Juguetes elige controles; mantén un icono para ver su nombre',
  'Close instructions': 'Cerrar instrucciones',
  'Calibrate physical size': 'Calibrar tamaño físico',
  'Ruler': 'Regla', 'Large pyramid': 'Pirámide grande',
  'Cancel': 'Cancelar', 'Use calibration': 'Usar calibración',
  'A Large upright pyramid should fit this square:':
      'Una pirámide grande vertical debe encajar en este cuadrado:',
  'Cross-check: this bar should measure exactly 25 mm:':
      'Comprobación: esta barra debe medir exactamente 25 mm:',
  'Recalibrate': 'Recalibrar', 'Looks right': 'Se ve bien',
  'Dice': 'Dados', 'selected': 'seleccionados',
  'Regular D6': 'D6 normal', 'Lightning die': 'Dado relámpago',
  'Pyramid die': 'Dado pirámide', 'Treehouse die': 'Dado Treehouse',
  'Color die': 'Dado de color', 'Fudge / Fate die': 'Dado Fudge / Fate',
  'Remove one': 'Quitar uno', 'Add one': 'Añadir uno', 'Done': 'Listo',
};

const _ja = <String, String>{
  'Desktop / trackpad': 'デスクトップ / トラックパッド',
  'Android tablet': 'Androidタブレット',
  'Android phone': 'Androidスマートフォン',
  'Touch device': 'タッチ端末',
  'Light Lottery': 'ライト・ロッタリー',
  'Entropy Delete': 'エントロピー削除',
  'Turn Timer': 'ターンタイマー',
  'Red Sweep': 'レッドスイープ',
  'Ghost Paths': 'ゴーストパス',
  'Random Event Zone': 'ランダムイベントゾーン',
  'Breathing': 'ブリージング',
  'Nest Cycle': 'ネストサイクル',
  'Radar': 'レーダー',
  'Dice Bubble': 'ダイスバブル',
  'Side Guns': 'サイドガン',
  'Corner Ricochet': 'コーナー跳弾',
  'Hot Potato': 'ホットポテト',
  'Constellation Draw': '星座描画',
  'Heartbeat': 'ハートビート',
  'Triangle Bounce': 'トライアングルバウンス',
  'Square Chase': 'スクエアチェイス',
  'Press/release to roll; two-finger drag moves; latch tiles cycle die counts':
      '押して離すとロール。2本指ドラッグで移動。ラッチでダイス数を変更',
  'Tap or hold/release to roll; two-finger drag moves; latch tiles cycle die counts':
      'タップまたは長押しして離すとロール。2本指ドラッグで移動。ラッチでダイス数を変更',
  'Tap or drag from tray; drag stones; double-click to remove':
      'トレイからタップまたはドラッグ。ストーンをドラッグ。ダブルクリックで削除',
  'Tap or drag from tray; drag stones; double-tap to remove':
      'トレイからタップまたはドラッグ。ストーンをドラッグ。ダブルタップで削除',
  'Thanks for playing with LightHouse!': 'LightHouseで遊んでくれてありがとう！',
  'Menu': 'メニュー', 'File': 'ファイル', 'Edit': '編集',
  'Boards': 'ボード', 'Toys': 'トイ', 'Display': '表示',
  'Remote': 'リモート', 'Instructions': '説明',
  'New': '新規', 'Open…': '開く…',
  'Restore Previous Autosave…': '前の自動保存を復元…',
  'Save': '保存', 'Save a Copy…': 'コピーを保存…',
  'Rename…': '名前を変更…',
  'Import Table JSON…': 'テーブルJSONを読み込む…',
  'Export Table JSON…': 'テーブルJSONを書き出す…',
  'Undo': '元に戻す', 'Redo': 'やり直す',
  'Rotation Snap': '回転スナップ', 'Free Rotation': '自由回転',
  'Snap Now': '今すぐスナップ', 'Game Boards': 'ゲームボード',
  'Grids': 'グリッド', 'Martian Chess': 'マーシャン・チェス',
  'Snap pieces to board': '駒をボードにスナップ', 'None': 'なし',
  'Checker Shading': '市松模様', 'Size': 'サイズ',
  'Safety Points': '安全な先端', 'Brightness': '明るさ',
  'Orientation Lock': '向きのロック', 'Full-screen': '全画面',
  'Zendo Off · Normal LightHouse': 'Zendoオフ · 通常のLightHouse',
  'Zendo Stones': 'Zendoストーン', 'Classic': 'クラシック',
  'Classic + Zendo 2.0': 'クラシック + Zendo 2.0',
  'Zendo Rule': 'Zendoルール', 'Different Zendo Rule': '別のZendoルール',
  'Complex Rules': '複雑なルール',
  'Hide Active Rule': '現在のルールを隠す',
  'Show Active Rule': '現在のルールを表示',
  'Easy': 'かんたん', 'Medium': 'ふつう', 'Hard': 'むずかしい',
  'This Device: Table Display': 'この端末：テーブル表示',
  'This Device: Controller': 'この端末：コントローラー',
  'Pair with 6-Character Code': '6文字コードでペアリング',
  'Pair with QR / Link': 'QR / リンクでペアリング',
  'Add Another Controller': 'コントローラーを追加',
  'Show Pairing QR': 'ペアリングQRを表示',
  'Swap Roles': '役割を交換', 'Disconnect': '切断',
  'Turn Off All Ripples': 'すべての波紋をオフ',
  'Table Display Shape Interaction': 'テーブル表示で形を操作',
  'Table Display Shapes Visible': 'テーブル表示で形を表示',
  'Create / resize / delete': '作成 / サイズ変更 / 削除',
  'Double-click': 'ダブルクリック', 'Double-tap': 'ダブルタップ',
  'Tip / stand': '倒す / 立てる',
  'Drag through the footprint edge': 'フットプリントの端を越えてドラッグ',
  'Full / wall light': '全面 / 壁面ライト',
  'Draw a loop around an upright footprint': '立っているフットプリントを囲むようにループを描く',
  'Move': '移動', 'Two-finger scroll over a footprint': 'フットプリント上で2本指スクロール',
  'Rotate': '回転', 'Shift + two-finger scroll': 'Shift + 2本指スクロール',
  'Move + rotate': '移動 + 回転',
  'Two-finger drag and twist': '2本指でドラッグしてひねる',
  'Rotation snap': '回転スナップ',
  'Edit > Rotation Snap; Snap Now aligns every shape immediately':
      '編集 > 回転スナップ。「今すぐスナップ」ですべての形をすぐに揃えます',
  'Board snap': 'ボードスナップ',
  'Boards > Snap pieces to board': 'ボード > 駒をボードにスナップ',
  'Dice bubble': 'ダイスバブル', 'Zendo stones': 'Zendoストーン',
  'Remote ripple': 'リモート波紋',
  'On a Controller, hold a shape to start its ripple; hold again to stop it':
      'コントローラーで形を長押しすると波紋が始まり、もう一度長押しすると止まります',
  'Toys chooses controls; hold an icon for its name':
      'トイでコントロールを選択。アイコンを長押しすると名前を表示',
  'Close instructions': '説明を閉じる',
  'Calibrate physical size': '実寸を調整',
  'Ruler': '定規', 'Large pyramid': 'ラージ・ピラミッド',
  'Cancel': 'キャンセル', 'Use calibration': 'この調整を使う',
  'A Large upright pyramid should fit this square:':
      '立てたラージ・ピラミッドがこの四角にぴったり収まるはずです：',
  'Cross-check: this bar should measure exactly 25 mm:':
      '確認：このバーはちょうど25 mmです：',
  'Recalibrate': '再調整', 'Looks right': 'これでOK',
  'Dice': 'ダイス', 'selected': '選択',
  'Regular D6': '通常D6', 'Lightning die': 'ライトニング・ダイス',
  'Pyramid die': 'ピラミッド・ダイス',
  'Treehouse die': 'ツリーハウス・ダイス',
  'Color die': 'カラー・ダイス', 'Fudge / Fate die': 'Fudge / Fateダイス',
  'Remove one': '1個減らす', 'Add one': '1個増やす', 'Done': '完了',
};


const _esExtra = <String, String>{
  'Motion access was not granted.': 'No se concedió acceso al movimiento.',
  'Pairing code copied.': 'Código de emparejamiento copiado.',
  'Pairing link copied.': 'Enlace de emparejamiento copiado.',
  'Copy Code': 'Copiar código',
  'Copy Link': 'Copiar enlace',
  'Hide': 'Ocultar',
  'Pair by Code': 'Emparejar por código',
  'Pair': 'Emparejar',
  'Controller': 'Controlador',
  'Table Display': 'Pantalla de mesa',
  'Disconnect Table Display': 'Desconectar pantalla de mesa',
  'Table Display shape interaction': 'Interacción con formas en la pantalla de mesa',
  'Table Display shapes visible': 'Formas visibles en la pantalla de mesa',
  'Turn off all ripples': 'Apagar todas las ondas',
  'Table name': 'Nombre de la mesa',
  'OK': 'Aceptar',
  'Restore previous autosave?': '¿Restaurar el autoguardado anterior?',
  'Restore': 'Restaurar',
  'Previous autosave restored. Undo can reverse it.': 'Autoguardado anterior restaurado. Deshacer puede revertirlo.',
  'Saved a copy.': 'Copia guardada.',
  'Table saved.': 'Mesa guardada.',
  'No saved tables yet.': 'Aún no hay mesas guardadas.',
  'Delete saved table': 'Eliminar mesa guardada',
  'Table JSON saved.': 'JSON de mesa guardado.',
  'That file is not a LightHouse table.': 'Ese archivo no es una mesa de LightHouse.',
  'Could not read that table file.': 'No se pudo leer ese archivo de mesa.',
  'Could not open Android display settings.': 'No se pudieron abrir los ajustes de pantalla de Android.',
  'Orientation lock': 'Bloqueo de orientación',
  'Display settings': 'Ajustes de pantalla',
  'Browsers cannot control screen brightness. Use the device brightness control.': 'Los navegadores no pueden controlar el brillo de la pantalla. Usa el control de brillo del dispositivo.',
  'Table brightness': 'Brillo de la mesa',
  'iOS does not expose a supported deep link to its Brightness panel; use Control Center for the system setting.': 'iOS no ofrece un enlace compatible al panel de brillo; usa el Centro de control.',
  'Use system': 'Usar sistema',
  'On iPhone or iPad, open this site in Safari, tap Share, then Add to Home Screen. On desktop browsers, use the browser install-app command when offered.': 'En iPhone o iPad, abre este sitio en Safari, toca Compartir y luego Añadir a pantalla de inicio. En navegadores de escritorio, usa la opción de instalar la aplicación cuando aparezca.',
  'Different rule': 'Otra regla',
  'Hide rule': 'Ocultar regla',
  'Place a Large pyramid upright over the filled square. Adjust the slider until its base matches the square exactly.': 'Coloca una pirámide grande de pie sobre el cuadrado relleno. Ajusta el control hasta que la base coincida exactamente.',
  'Hold a ruler to the screen with 0 aligned to the fixed left end. Adjust the slider until the right end reaches exactly 50 mm.': 'Sostén una regla sobre la pantalla con el 0 alineado al extremo izquierdo fijo. Ajusta el control hasta que el extremo derecho llegue exactamente a 50 mm.',
};

const _jaExtra = <String, String>{
  'Motion access was not granted.': 'モーションへのアクセスが許可されませんでした。',
  'Pairing code copied.': 'ペアリングコードをコピーしました。',
  'Pairing link copied.': 'ペアリングリンクをコピーしました。',
  'Copy Code': 'コードをコピー',
  'Copy Link': 'リンクをコピー',
  'Hide': '隠す',
  'Pair by Code': 'コードでペアリング',
  'Pair': 'ペアリング',
  'Controller': 'コントローラー',
  'Table Display': 'テーブル表示',
  'Disconnect Table Display': 'テーブル表示を切断',
  'Table Display shape interaction': 'テーブル表示で形を操作',
  'Table Display shapes visible': 'テーブル表示で形を表示',
  'Turn off all ripples': 'すべての波紋をオフ',
  'Table name': 'テーブル名',
  'OK': 'OK',
  'Restore previous autosave?': '前の自動保存を復元しますか？',
  'Restore': '復元',
  'Previous autosave restored. Undo can reverse it.': '前の自動保存を復元しました。「元に戻す」で取り消せます。',
  'Saved a copy.': 'コピーを保存しました。',
  'Table saved.': 'テーブルを保存しました。',
  'No saved tables yet.': '保存されたテーブルはまだありません。',
  'Delete saved table': '保存したテーブルを削除',
  'Table JSON saved.': 'テーブルJSONを保存しました。',
  'That file is not a LightHouse table.': 'そのファイルはLightHouseのテーブルではありません。',
  'Could not read that table file.': 'テーブルファイルを読み込めませんでした。',
  'Could not open Android display settings.': 'Androidの画面設定を開けませんでした。',
  'Orientation lock': '向きのロック',
  'Display settings': '画面設定',
  'Browsers cannot control screen brightness. Use the device brightness control.': 'ブラウザから画面の明るさは変更できません。端末の明るさ設定を使ってください。',
  'Table brightness': 'テーブルの明るさ',
  'iOS does not expose a supported deep link to its Brightness panel; use Control Center for the system setting.': 'iOSでは明るさ設定への対応リンクがありません。コントロールセンターを使ってください。',
  'Use system': 'システム設定を使う',
  'On iPhone or iPad, open this site in Safari, tap Share, then Add to Home Screen. On desktop browsers, use the browser install-app command when offered.': 'iPhoneまたはiPadではSafariでこのサイトを開き、共有から「ホーム画面に追加」を選びます。デスクトップでは、表示された場合にブラウザのアプリをインストールする機能を使います。',
  'Different rule': '別のルール',
  'Hide rule': 'ルールを隠す',
  'Place a Large pyramid upright over the filled square. Adjust the slider until its base matches the square exactly.': 'ラージ・ピラミッドを立てて塗りつぶした四角に重ね、底面が正確に一致するまでスライダーを調整します。',
  'Hold a ruler to the screen with 0 aligned to the fixed left end. Adjust the slider until the right end reaches exactly 50 mm.': '定規の0を固定された左端に合わせ、右端がちょうど50 mmになるまでスライダーを調整します。',
};
