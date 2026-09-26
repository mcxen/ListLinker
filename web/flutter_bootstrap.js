{{flutter_js}}
{{flutter_build_config}}

const progress = document.querySelector('.progress-container');
const bar = document.querySelector('.progress-bar');
window.addEventListener('flutter-first-frame', () => progress.remove(), { once: true });
const setProgress = (value) => {
  bar.style.width = `${value}%`;
  progress.setAttribute('aria-valuenow', String(value));
};

setProgress(20);

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    setProgress(50);
    const appRunner = await engineInitializer.initializeEngine();
    setProgress(80);
    await appRunner.runApp();
  },
});
