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
    AppLanguage.spanish => _es[english] ?? english,
    AppLanguage.japanese => _ja[english] ?? english,
  };
}

const _es = <String, String>{
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
