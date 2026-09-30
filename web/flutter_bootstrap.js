{{flutter_js}}
{{flutter_build_config}}

const lighthouseBuildVersion = '39';

for (const build of (_flutter.buildConfig?.builds ?? [])) {
  if (build.mainJsPath) {
    const separator = build.mainJsPath.includes('?') ? '&' : '?';
    build.mainJsPath = `${build.mainJsPath}${separator}v=${lighthouseBuildVersion}`;
  }
}

// iPadOS 15 on older iPads can fail to initialize CanvasKit's WebGL surface.
// Keep the workaround narrow so newer devices retain accelerated rendering.
const isIPad = /iPad/.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
const isSafari15 = /Version\/15\./.test(navigator.userAgent) ||
    /OS 15_/.test(navigator.userAgent);
const useCpuRenderer = isIPad && isSafari15;

_flutter.loader.load({
  config: useCpuRenderer ? { canvasKitForceCpuOnly: true } : {},
});
