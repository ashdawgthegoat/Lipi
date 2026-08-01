import { ExcalidrawImperativeAPI } from '@excalidraw/excalidraw/types';

/**
 * Export the current scene as an SVG file and trigger a download.
 */
export async function exportSceneToSvg(
  api: ExcalidrawImperativeAPI,
): Promise<void> {
  // Dynamic import to avoid pulling export utils into the main bundle
  // if they're tree-shaken by the bundler.
  const { exportToSvg } = await import('@excalidraw/excalidraw');

  const elements = api.getSceneElements();
  if (elements.length === 0) return;

  const appState = api.getAppState();

  const svgElement = await exportToSvg({
    elements,
    appState: {
      ...appState,
      exportWithDarkMode: false,
      exportBackground: true,
    },
    files: null,
  });

  const serializer = new XMLSerializer();
  const svgString = serializer.serializeToString(svgElement);
  const blob = new Blob([svgString], { type: 'image/svg+xml' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'handwriting.svg';
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}
