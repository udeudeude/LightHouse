{{flutter_js}}
{{flutter_build_config}}

const lighthouseBuildVersion = '{{flutter_service_worker_version}}';

for (const build of (_flutter.buildConfig?.builds ?? [])) {
  if (build.mainJsPath) {
    const separator = build.mainJsPath.includes('?') ? '&' : '?';
    build.mainJsPath =
      `${build.mainJsPath}${separator}v=${encodeURIComponent(lighthouseBuildVersion)}`;
  }
}

Promise.resolve(window.lighthousePrepareFreshRuntime)
  .catch(() => {})
  .finally(() => _flutter.loader.load());
