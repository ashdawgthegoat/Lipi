import { useState, useEffect, useCallback, useRef, useMemo } from 'react';
import { Excalidraw, exportToSvg, exportToBlob } from '@excalidraw/excalidraw';
import '@excalidraw/excalidraw/index.css';
import type { ExcalidrawImperativeAPI } from '@excalidraw/excalidraw/types';

interface PageInfo {
  width: number;
  height: number;
  unit: string;
}

interface DoctorInfo {
  name: string;
  clinic: string;
  qualifications: string;
  regNumber: string;
  templateImage?: string;
}

interface PatientInfo {
  name: string;
  age: number | string;
  gender: string;
  city: string;
}

interface InitData {
  page?: PageInfo;
  doctor?: DoctorInfo;
  patient?: PatientInfo;
  consultationId?: string;
  date?: string;
  elements?: any[];
  debugMode?: 'standard' | 'testA' | 'testB';
}

function generateSyntheticTestImage(): string {
  const canvas = document.createElement('canvas');
  canvas.width = 1200;
  canvas.height = 1600;
  const ctx = canvas.getContext('2d');
  if (!ctx) return '';

  // High-contrast yellow background
  ctx.fillStyle = '#FFF59D';
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  // Thick contrasting border
  ctx.lineWidth = 24;
  ctx.strokeStyle = '#D32F2F';
  ctx.strokeRect(12, 12, canvas.width - 24, canvas.height - 24);

  // Large header box
  ctx.fillStyle = '#C62828';
  ctx.fillRect(40, 40, canvas.width - 80, 180);
  ctx.fillStyle = '#FFFFFF';
  ctx.font = 'bold 70px sans-serif';
  ctx.textAlign = 'center';
  ctx.fillText('LIPI TEMPLATE TEST', canvas.width / 2, 155);

  // Subtitles
  ctx.fillStyle = '#1A237E';
  ctx.font = 'bold 44px sans-serif';
  ctx.fillText('SYNTHETIC OFFLINE DATA URL', canvas.width / 2, 450);

  ctx.fillStyle = '#263238';
  ctx.font = '32px sans-serif';
  ctx.fillText('Android WebView Direct Image Rendering', canvas.width / 2, 560);
  ctx.fillText('Pass 1B Acceptance Validation', canvas.width / 2, 640);

  // Ruled test lines
  ctx.strokeStyle = '#90A4AE';
  ctx.lineWidth = 4;
  for (let y = 800; y <= 1400; y += 100) {
    ctx.beginPath();
    ctx.moveTo(100, y);
    ctx.lineTo(canvas.width - 100, y);
    ctx.stroke();
  }

  ctx.fillStyle = '#2E7D32';
  ctx.font = 'bold 36px monospace';
  ctx.fillText('PASS 1B ACCEPTANCE VALIDATION', canvas.width / 2, 1520);

  return canvas.toDataURL('image/png');
}

function logImageDiagnostics(
  img: HTMLImageElement | null,
  context: string,
  postToFlutter: (msg: any) => void
) {
  const sendLog = (line: string) => {
    const full = `[Lipi][TemplateDebug] [${context}] ${line}`;
    console.log(full);
    postToFlutter({ type: 'TEMPLATE_DEBUG', message: full });
  };

  if (!img) {
    sendLog('Image element does NOT exist in DOM');
    return;
  }

  const rect = img.getBoundingClientRect();
  const parent = img.parentElement;
  const parentRect = parent ? parent.getBoundingClientRect() : null;
  const computed = window.getComputedStyle(img);

  sendLog(`element_exists=true, id="${img.id || 'none'}", class="${img.className || 'none'}"`);
  sendLog(`src_length=${img.src.length}, src_prefix="${img.src.substring(0, 60)}"`);
  sendLog(`naturalWidth=${img.naturalWidth}, naturalHeight=${img.naturalHeight}`);
  sendLog(`complete=${img.complete}`);
  sendLog(`rendered_width=${img.offsetWidth}, rendered_height=${img.offsetHeight}`);
  sendLog(`bounding_rect={top: ${rect.top.toFixed(1)}, left: ${rect.left.toFixed(1)}, width: ${rect.width.toFixed(1)}, height: ${rect.height.toFixed(1)}}`);
  sendLog(`computed_styles={visibility: "${computed.visibility}", opacity: "${computed.opacity}", zIndex: "${computed.zIndex}", display: "${computed.display}"}`);

  if (parent && parentRect) {
    const pComputed = window.getComputedStyle(parent);
    sendLog(`parent={tag: "${parent.tagName}", class: "${parent.className}", rect: ${parentRect.width.toFixed(1)}x${parentRect.height.toFixed(1)}, display: "${pComputed.display}", overflow: "${pComputed.overflow}", zIndex: "${pComputed.zIndex}"}`);
  }
}

export function App() {
  const [debugMode, setDebugMode] = useState<'standard' | 'testA' | 'testB'>('standard');
  const syntheticImageSrc = useMemo(() => generateSyntheticTestImage(), []);
  const [api, setApi] = useState<ExcalidrawImperativeAPI | null>(null);
  const [activeTool, setActiveTool] = useState<'pen' | 'eraser' | 'hand'>('pen');
  const [strokeColor, setStrokeColor] = useState<string>('#000000');
  const [strokeWidth, setStrokeWidth] = useState<number>(1);
  const [currentZoom, setCurrentZoom] = useState<number>(1.0);

  // Buffered elements to load once Excalidraw API is ready (Fix B)
  const pendingElementsRef = useRef<any[] | null>(null);

  // References for viewport and sheet transform synchronization
  const sheetContainerRef = useRef<HTMLDivElement | null>(null);
  const viewportRef = useRef<HTMLDivElement | null>(null);
  const currentTransformRef = useRef({ scrollX: 0, scrollY: 0, zoom: 1.0 });

  const [pageInfo, setPageInfo] = useState<PageInfo>({
    width: 180,
    height: 260,
    unit: 'mm',
  });

  const [doctorInfo, setDoctorInfo] = useState<DoctorInfo>({
    name: 'Dr. Aarti Sharma, MD',
    clinic: 'City Health Clinic',
    qualifications: 'MBBS, MD (General Medicine)',
    regNumber: 'MCI-45892',
  });

  const [patientInfo, setPatientInfo] = useState<PatientInfo>({
    name: 'Ravi Kumar',
    age: 42,
    gender: 'Male',
    city: 'Pune',
  });

  const [consultationId, setConsultationId] = useState<string>('c-s4-preview');
  const [consultationDate, setConsultationDate] = useState<string>(
    new Date().toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
  );

  const apiRef = useRef<ExcalidrawImperativeAPI | null>(null);
  apiRef.current = api;

  // Direct GPU transform update on the DOM sheet container for 120Hz/144Hz synchronization
  const updateSheetTransform = useCallback((scrollX: number, scrollY: number, zoomValue: number) => {
    currentTransformRef.current = { scrollX, scrollY, zoom: zoomValue };
    if (sheetContainerRef.current) {
      sheetContainerRef.current.style.transform = `translate(${scrollX * zoomValue}px, ${scrollY * zoomValue}px) scale(${zoomValue})`;
    }
  }, []);

  // Compute page dimensions in px based on mm (1mm ~= 3.78 px)
  const pxWidth = Math.round((pageInfo.width || 180) * 3.78);
  const pxHeight = Math.round((pageInfo.height || 260) * 3.78);

  // Center finite prescription sheet in viewport
  const centerPrescriptionPage = useCallback(
    (apiInstance: ExcalidrawImperativeAPI, widthMm?: number, heightMm?: number) => {
      const w = Math.round((widthMm || pageInfo.width || 180) * 3.78);
      const h = Math.round((heightMm || pageInfo.height || 260) * 3.78);
      const vWidth = viewportRef.current?.clientWidth || window.innerWidth;
      const vHeight = viewportRef.current?.clientHeight || window.innerHeight - 48;

      const margin = 24;
      const scaleX = (vWidth - margin * 2) / w;
      const scaleY = (vHeight - margin * 2) / h;
      const fitZoom = Math.min(scaleX, scaleY);
      const targetZoom = Math.max(0.4, Math.min(1.0, Math.round(fitZoom * 100) / 100));

      const initialScrollX = (vWidth / targetZoom - w) / 2;
      const initialScrollY = Math.max(16 / targetZoom, 20);

      apiInstance.updateScene({
        appState: {
          viewBackgroundColor: 'transparent',
          zoom: { value: targetZoom as any },
          scrollX: initialScrollX,
          scrollY: initialScrollY,
        },
      });
      updateSheetTransform(initialScrollX, initialScrollY, targetZoom);
      setCurrentZoom(targetZoom);
    },
    [pageInfo.width, pageInfo.height, updateSheetTransform],
  );

  // Bridge messenger to Flutter
  const postToFlutter = useCallback((message: any) => {
    const payload = typeof message === 'string' ? message : JSON.stringify(message);
    // 1. Flutter Android WebView JavaScriptChannel
    if ((window as any).LipiChannel?.postMessage) {
      try {
        (window as any).LipiChannel.postMessage(payload);
      } catch (err) {
        console.error('LipiChannel error:', err);
      }
    }
    // 2. Window postMessage (for web/iframe)
    if (window.parent && window.parent !== window) {
      window.parent.postMessage(payload, '*');
    }
  }, []);

  const handleApi = useCallback(
    (excalidrawApi: ExcalidrawImperativeAPI) => {
      setApi(excalidrawApi);
      apiRef.current = excalidrawApi;

      // Center sheet on initialization
      centerPrescriptionPage(excalidrawApi);

      // Flush elements buffered before the API was ready (Fix B)
      if (pendingElementsRef.current !== null) {
        const elements = pendingElementsRef.current;
        pendingElementsRef.current = null;
        // Defer by one frame so Excalidraw finishes mounting
        requestAnimationFrame(() => {
          excalidrawApi.updateScene({
            elements,
            appState: { viewBackgroundColor: 'transparent' },
          });
        });
      }
    },
    [centerPrescriptionPage],
  );

  // Synchronize sheet transform with Excalidraw camera on scroll/pan/zoom
  const handleScrollChange = useCallback(
    (scrollX: number, scrollY: number, zoom: { value: number }) => {
      updateSheetTransform(scrollX, scrollY, zoom.value);
      const rounded = Math.round(zoom.value * 100) / 100;
      setCurrentZoom((prev) => (Math.abs(prev - rounded) > 0.01 ? rounded : prev));
    },
    [updateSheetTransform],
  );

  // Configure Excalidraw UI
  const initialData = useMemo(
    () => ({
      appState: {
        activeTool: { type: 'freedraw' as const, customType: null, lastActiveTool: null, locked: true },
        currentItemStrokeColor: '#000000',
        currentItemStrokeWidth: 1,
        viewBackgroundColor: 'transparent',
      },
    }),
    [],
  );

  const uiOptions = useMemo(
    () => ({
      canvasActions: {
        changeViewBackgroundColor: false,
        clearCanvas: false,
        loadScene: false,
        saveToActiveFile: false,
        toggleTheme: false,
        saveAsImage: false,
        export: false as const,
      },
      welcomeScreen: false,
    }),
    [],
  );

  // Switch to pen
  const setPenMode = useCallback(() => {
    setActiveTool('pen');
    if (apiRef.current) {
      apiRef.current.updateScene({
        appState: {
          activeTool: { type: 'freedraw', customType: null, lastActiveTool: null, locked: true },
          currentItemStrokeColor: strokeColor,
          currentItemStrokeWidth: strokeWidth,
        },
      });
    }
  }, [strokeColor, strokeWidth]);

  // Switch to eraser
  const setEraserMode = useCallback(() => {
    setActiveTool('eraser');
    if (apiRef.current) {
      apiRef.current.updateScene({
        appState: {
          activeTool: { type: 'eraser', customType: null, lastActiveTool: null, locked: true },
        },
      });
    }
  }, []);

  // Switch to hand/pan tool
  const setHandMode = useCallback(() => {
    setActiveTool('hand');
    if (apiRef.current) {
      apiRef.current.updateScene({
        appState: {
          activeTool: { type: 'hand', customType: null, lastActiveTool: null, locked: true },
        },
      });
    }
  }, []);

  // Step zoom (+ / -) centered at viewport
  const handleZoomStep = useCallback(
    (delta: number) => {
      if (!apiRef.current || !viewportRef.current) return;
      const appState = apiRef.current.getAppState();
      const currentZ = appState.zoom.value;
      const nextZ = Math.max(0.3, Math.min(3.0, Math.round((currentZ + delta) * 100) / 100));
      if (Math.abs(nextZ - currentZ) < 0.01) return;

      const rect = viewportRef.current.getBoundingClientRect();
      const vWidth = rect.width || window.innerWidth;
      const vHeight = rect.height || window.innerHeight - 48;
      const centerX = vWidth / 2;
      const centerY = vHeight / 2;

      const sceneCenterX = centerX / currentZ - appState.scrollX;
      const sceneCenterY = centerY / currentZ - appState.scrollY;
      const newScrollX = centerX / nextZ - sceneCenterX;
      const newScrollY = centerY / nextZ - sceneCenterY;

      apiRef.current.updateScene({
        appState: {
          zoom: { value: nextZ as any },
          scrollX: newScrollX,
          scrollY: newScrollY,
        },
      });
      updateSheetTransform(newScrollX, newScrollY, nextZ);
      setCurrentZoom(nextZ);
    },
    [updateSheetTransform],
  );

  // Fit whole prescription sheet into viewport
  const handleFitPage = useCallback(() => {
    if (!apiRef.current || !viewportRef.current) return;
    const rect = viewportRef.current.getBoundingClientRect();
    const vWidth = rect.width || window.innerWidth;
    const vHeight = rect.height || window.innerHeight - 48;

    const margin = 24;
    const scaleX = (vWidth - margin * 2) / pxWidth;
    const scaleY = (vHeight - margin * 2) / pxHeight;
    const fitZoom = Math.max(0.3, Math.min(2.0, Math.min(scaleX, scaleY)));
    const normalizedZoom = Math.round(fitZoom * 100) / 100;

    const centeredScrollX = (vWidth / normalizedZoom - pxWidth) / 2;
    const centeredScrollY = Math.max(16 / normalizedZoom, (vHeight / normalizedZoom - pxHeight) / 2);

    apiRef.current.updateScene({
      appState: {
        zoom: { value: normalizedZoom as any },
        scrollX: centeredScrollX,
        scrollY: centeredScrollY,
      },
    });
    updateSheetTransform(centeredScrollX, centeredScrollY, normalizedZoom);
    setCurrentZoom(normalizedZoom);
  }, [pxWidth, pxHeight, updateSheetTransform]);

  // Reset zoom to 1.0 (100%)
  const handleResetZoom = useCallback(() => {
    if (!apiRef.current || !viewportRef.current) return;
    const rect = viewportRef.current.getBoundingClientRect();
    const vWidth = rect.width || window.innerWidth;

    const zoom = 1.0;
    const centeredScrollX = (vWidth / zoom - pxWidth) / 2;
    const centeredScrollY = 24 / zoom;

    apiRef.current.updateScene({
      appState: {
        zoom: { value: zoom as any },
        scrollX: centeredScrollX,
        scrollY: centeredScrollY,
      },
    });
    updateSheetTransform(centeredScrollX, centeredScrollY, zoom);
    setCurrentZoom(1.0);
  }, [pxWidth, updateSheetTransform]);

  // Change color
  const handleColorChange = useCallback((color: string) => {
    setStrokeColor(color);
    setActiveTool('pen');
    if (apiRef.current) {
      apiRef.current.updateScene({
        appState: {
          activeTool: { type: 'freedraw', customType: null, lastActiveTool: null, locked: true },
          currentItemStrokeColor: color,
        },
      });
    }
  }, []);

  // Change stroke width
  const handleWidthChange = useCallback((width: number) => {
    setStrokeWidth(width);
    setActiveTool('pen');
    if (apiRef.current) {
      apiRef.current.updateScene({
        appState: {
          activeTool: { type: 'freedraw', customType: null, lastActiveTool: null, locked: true },
          currentItemStrokeWidth: width,
        },
      });
    }
  }, []);

  // Undo / Redo
  const handleUndo = useCallback(() => {
    if (apiRef.current) {
      (apiRef.current as any).history?.undo();
    }
  }, []);

  const handleRedo = useCallback(() => {
    if (apiRef.current) {
      (apiRef.current as any).history?.redo();
    }
  }, []);

  const handleClear = useCallback(() => {
    if (apiRef.current) {
      apiRef.current.updateScene({ elements: [] });
    }
  }, []);

  // Expose global methods for Flutter interaction
  useEffect(() => {
    (window as any).initPrescription = (data: InitData) => {
      console.log('[Lipi][Template] initPrescription invoked');
      console.log('[Lipi][Template] Page:', JSON.stringify(data.page));
      console.log('[Lipi][Template] Doctor:', data.doctor?.name, '| Clinic:', data.doctor?.clinic);
      
      const tmpl = data.doctor?.templateImage;
      if (tmpl) {
        console.log('[Lipi][Template] Custom templateImage detected: type=' + typeof tmpl + ', length=' + tmpl.length + ', prefix=' + tmpl.substring(0, 50));
      } else {
        console.log('[Lipi][Template] No custom templateImage provided; standard clinic letterhead will render.');
      }

      if (data.page) {
        setPageInfo(data.page);
        if (apiRef.current) {
          centerPrescriptionPage(apiRef.current, data.page.width, data.page.height);
        }
      }
      if (data.doctor) setDoctorInfo(data.doctor);
      if (data.patient) setPatientInfo(data.patient);
      if (data.consultationId) setConsultationId(data.consultationId);
      if (data.date) setConsultationDate(data.date);

      if (apiRef.current) {
        apiRef.current.updateScene({
          appState: { viewBackgroundColor: 'transparent' },
          ...(data.elements && data.elements.length > 0 ? { elements: data.elements } : {}),
        });
        console.log('[Lipi][Template] Excalidraw scene updated with transparent background');
      } else if (data.elements && data.elements.length > 0) {
        pendingElementsRef.current = data.elements;
      }

      if (data.debugMode) {
        console.log('[Lipi][TemplateDebug] Setting debugMode from initData:', data.debugMode);
        setDebugMode(data.debugMode);
      }

      postToFlutter({
        type: 'INITIALIZED',
        hasTemplateImage: !!tmpl,
        doctorName: data.doctor?.name,
      });
      return true;
    };

    (window as any).setTemplateDebugMode = (mode: string) => {
      console.log('[Lipi][TemplateDebug] setTemplateDebugMode called with:', mode);
      setDebugMode(mode as any);
      return true;
    };

    (window as any).getPrescriptionElements = () => {
      if (!apiRef.current) return '[]';
      const elements = apiRef.current.getSceneElements();
      return JSON.stringify(elements);
    };

    (window as any).loadPrescriptionElements = (elementsJsonOrArray: any) => {
      if (!apiRef.current) return false;
      const elements = typeof elementsJsonOrArray === 'string'
        ? JSON.parse(elementsJsonOrArray)
        : elementsJsonOrArray;
      apiRef.current.updateScene({
        elements,
        appState: { viewBackgroundColor: 'transparent' },
      });
      return true;
    };

    // Automated test / validation inspection of unified coordinate transform state
    (window as any).getPrescriptionViewportState = () => {
      if (!apiRef.current) return null;
      const appState = apiRef.current.getAppState();
      const rect = sheetContainerRef.current?.getBoundingClientRect();
      return JSON.stringify({
        zoom: appState.zoom.value,
        scrollX: appState.scrollX,
        scrollY: appState.scrollY,
        sheetBoundingRect: rect
          ? {
              left: Math.round(rect.left * 100) / 100,
              top: Math.round(rect.top * 100) / 100,
              width: Math.round(rect.width * 100) / 100,
              height: Math.round(rect.height * 100) / 100,
            }
          : null,
        pxWidth,
        pxHeight,
      });
    };

    (window as any).setPrescriptionZoom = (zoomValue: number, scrollX?: number, scrollY?: number) => {
      if (!apiRef.current) return false;
      const appState = apiRef.current.getAppState();
      const newScrollX = scrollX !== undefined ? scrollX : appState.scrollX;
      const newScrollY = scrollY !== undefined ? scrollY : appState.scrollY;
      apiRef.current.updateScene({
        appState: {
          zoom: { value: zoomValue as any },
          scrollX: newScrollX,
          scrollY: newScrollY,
        },
      });
      updateSheetTransform(newScrollX, newScrollY, zoomValue);
      setCurrentZoom(zoomValue);
      return true;
    };

    (window as any).exportSvg = async () => {
      if (!apiRef.current) return '';
      const elements = apiRef.current.getSceneElements();
      const appState = apiRef.current.getAppState();
      const svg = await exportToSvg({
        elements,
        appState: { ...appState, exportBackground: false },
        files: null,
      });
      const serializer = new XMLSerializer();
      const svgString = serializer.serializeToString(svg);
      postToFlutter({ type: 'SVG_EXPORTED', svg: svgString });
      return svgString;
    };

    (window as any).exportPng = async () => {
      if (!apiRef.current) return '';
      const elements = apiRef.current.getSceneElements();
      const appState = apiRef.current.getAppState();
      const blob = await exportToBlob({
        elements,
        appState: { ...appState, exportBackground: false },
        files: null,
        mimeType: 'image/png',
      });
      return new Promise<string>((resolve) => {
        const reader = new FileReader();
        reader.onloadend = () => {
          const base64 = reader.result as string;
          postToFlutter({ type: 'PNG_EXPORTED', dataUrl: base64 });
          resolve(base64);
        };
        reader.readAsDataURL(blob);
      });
    };

    // Notify Flutter that editor is ready, with retry loop to ensure bridge delivery
    let attempt = 0;
    const intervalId = setInterval(() => {
      attempt++;
      postToFlutter({ type: 'READY', attempt });
      if (attempt >= 25) clearInterval(intervalId);
    }, 100);

    postToFlutter({ type: 'READY', attempt: 0 });

    return () => clearInterval(intervalId);
  }, [postToFlutter, centerPrescriptionPage, pxWidth, pxHeight, updateSheetTransform]);

  // Track stroke changes to inform Flutter
  const handleChange = useCallback(
    (elements: readonly any[], appState: any) => {
      if (appState?.zoom) {
        updateSheetTransform(appState.scrollX, appState.scrollY, appState.zoom.value);
      }
      const activeElements = elements.filter((el) => !el.isDeleted);
      postToFlutter({
        type: 'INK_CHANGED',
        strokeCount: activeElements.length,
      });
    },
    [postToFlutter, updateSheetTransform],
  );

  return (
    <div className="workspace-container">
      {/* Top Toolbar */}
      <div className="workspace-toolbar">
        <div className="tool-group">
          <button
            className={`tool-btn ${activeTool === 'pen' ? 'active' : ''}`}
            onClick={setPenMode}
            title="Pen (Stylus)"
          >
            ✏️ Pen
          </button>
          <button
            className={`tool-btn ${activeTool === 'eraser' ? 'active' : ''}`}
            onClick={setEraserMode}
            title="Eraser"
          >
            🧹 Eraser
          </button>

          <div
            className={`color-dot ${strokeColor === '#000000' ? 'active' : ''}`}
            style={{ background: '#000000' }}
            onClick={() => handleColorChange('#000000')}
            title="Black Ink"
          />
          <div
            className={`color-dot ${strokeColor === '#1a365d' ? 'active' : ''}`}
            style={{ background: '#1a365d' }}
            onClick={() => handleColorChange('#1a365d')}
            title="Blue Ink"
          />

          <button
            className={`tool-btn ${strokeWidth === 1 ? 'active' : ''}`}
            style={{ padding: '0 8px', fontSize: '11px' }}
            onClick={() => handleWidthChange(1)}
            title="Fine Line"
          >
            Fine
          </button>
          <button
            className={`tool-btn ${strokeWidth === 2 ? 'active' : ''}`}
            style={{ padding: '0 8px', fontSize: '11px' }}
            onClick={() => handleWidthChange(2)}
            title="Medium Line"
          >
            Med
          </button>
        </div>

        <div className="tool-group">
          <button className="tool-btn" onClick={handleUndo} title="Undo">
            ↩ Undo
          </button>
          <button className="tool-btn" onClick={handleRedo} title="Redo">
            ↪ Redo
          </button>
          <button className="tool-btn" onClick={handleClear} title="Clear Page">
            🗑 Clear
          </button>
        </div>

        {/* Prescription Document Zoom & Navigation Controls */}
        <div className="tool-group" style={{ borderLeft: '1px solid #d0d7de', paddingLeft: '8px' }}>
          <button
            className={`tool-btn ${activeTool === 'hand' ? 'active' : ''}`}
            onClick={setHandMode}
            title="Pan (Hand Tool)"
          >
            ✋ Pan
          </button>
          <button className="tool-btn" onClick={() => handleZoomStep(-0.25)} title="Zoom Out">
            🔍−
          </button>
          <button
            className="tool-btn"
            onClick={handleResetZoom}
            title="Reset to 100% Zoom"
            style={{ minWidth: '48px', textAlign: 'center', fontSize: '11px', fontWeight: 600 }}
          >
            {Math.round(currentZoom * 100)}%
          </button>
          <button className="tool-btn" onClick={() => handleZoomStep(0.25)} title="Zoom In">
            🔍+
          </button>
          <button className="tool-btn" onClick={handleFitPage} title="Fit Entire Page in Viewport">
            📄 Fit
          </button>
        </div>

        {/* Forensic Debug Toolbar Group */}
        <div className="tool-group" style={{ marginLeft: 'auto', borderLeft: '1px solid #d0d7de', paddingLeft: '8px' }}>
          <span style={{ fontSize: '11px', fontWeight: 600, color: '#64748b' }}>DEBUG:</span>
          <button
            className={`tool-btn ${debugMode === 'standard' ? 'active' : ''}`}
            style={{ fontSize: '11px', padding: '0 6px' }}
            onClick={() => setDebugMode('standard')}
          >
            Normal
          </button>
          <button
            className={`tool-btn ${debugMode === 'testA' ? 'active' : ''}`}
            style={{ fontSize: '11px', padding: '0 6px', color: '#dc2626' }}
            onClick={() => setDebugMode('testA')}
          >
            Test A
          </button>
          <button
            className={`tool-btn ${debugMode === 'testB' ? 'active' : ''}`}
            style={{ fontSize: '11px', padding: '0 6px', color: '#16a34a' }}
            onClick={() => setDebugMode('testB')}
          >
            Test B
          </button>
        </div>
      </div>

      {/* Viewport: Forensic Test A / Test B / Standard */}
      {debugMode === 'testA' ? (
        <div
          className="page-viewport forensic-debug-viewport"
          style={{
            background: '#18181b',
            padding: '24px',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            overflow: 'auto',
          }}
        >
          <div style={{ color: '#f87171', fontWeight: 700, fontSize: '14px', marginBottom: '12px' }}>
            FORENSIC TEST A: Plain HTML &lt;img&gt; Only (Uploaded Template)
          </div>
          {doctorInfo.templateImage ? (
            <img
              id="test-a-img"
              src={doctorInfo.templateImage}
              alt="Test A Uploaded Template"
              style={{
                maxWidth: '90%',
                maxHeight: '85vh',
                border: '6px solid #ef4444',
                boxShadow: '0 0 24px rgba(239, 68, 68, 0.6)',
                background: '#ffffff',
                display: 'block',
              }}
              onLoad={(e) => {
                logImageDiagnostics(e.currentTarget, 'TestA-onLoad', postToFlutter);
                postToFlutter({ type: 'TEMPLATE_LOADED', success: true });
              }}
              onError={(e) => {
                logImageDiagnostics(e.currentTarget, 'TestA-onError', postToFlutter);
                postToFlutter({ type: 'TEMPLATE_LOADED', success: false, error: 'Test A image failed to load' });
              }}
            />
          ) : (
            <div style={{ color: '#ffffff', padding: '24px', background: '#3f3f46', borderRadius: '8px' }}>
              No custom templateImage configured in doctorInfo (Default template active)
            </div>
          )}
        </div>
      ) : debugMode === 'testB' ? (
        <div
          className="page-viewport forensic-debug-viewport"
          style={{
            background: '#0f172a',
            padding: '24px',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            overflow: 'auto',
          }}
        >
          <div style={{ color: '#4ade80', fontWeight: 700, fontSize: '14px', marginBottom: '12px' }}>
            FORENSIC TEST B: Synthetic In-Memory Data URL &lt;img&gt;
          </div>
          <img
            id="test-b-img"
            src={syntheticImageSrc}
            alt="Test B Synthetic Template"
            style={{
              maxWidth: '90%',
              maxHeight: '85vh',
              border: '6px solid #22c55e',
              boxShadow: '0 0 24px rgba(34, 197, 94, 0.6)',
              background: '#ffffff',
              display: 'block',
            }}
            onLoad={(e) => {
              logImageDiagnostics(e.currentTarget, 'TestB-onLoad', postToFlutter);
              postToFlutter({ type: 'TEMPLATE_LOADED', success: true });
            }}
            onError={(e) => {
              logImageDiagnostics(e.currentTarget, 'TestB-onError', postToFlutter);
              postToFlutter({ type: 'TEMPLATE_LOADED', success: false, error: 'Test B image failed to load' });
            }}
          />
        </div>
      ) : (
        <div className="page-viewport" ref={viewportRef}>
          {/* 1. Transformed Prescription Document / Page Container: Spatially locked with Excalidraw camera */}
          <div
            ref={sheetContainerRef}
            className="prescription-sheet-container"
            style={{
              width: `${pxWidth}px`,
              height: `${pxHeight}px`,
              transformOrigin: '0 0',
              transform: `translate(${currentTransformRef.current.scrollX * currentTransformRef.current.zoom}px, ${currentTransformRef.current.scrollY * currentTransformRef.current.zoom}px) scale(${currentTransformRef.current.zoom})`,
            }}
          >
            <div
              className="prescription-sheet"
              style={{
                width: `${pxWidth}px`,
                height: `${pxHeight}px`,
              }}
            >
              {doctorInfo.templateImage ? (
                /* ── 1. Custom Prescription Template: Uploaded image covers entire page ── */
                <div className="custom-template-layer">
                  <img
                    id="custom-template-img"
                    src={doctorInfo.templateImage}
                    alt="Custom Prescription Template"
                    className="custom-template-img"
                    onLoad={(e) => {
                      logImageDiagnostics(e.currentTarget, 'Standard-Custom-onLoad', postToFlutter);
                      postToFlutter({ type: 'TEMPLATE_LOADED', success: true });
                    }}
                    onError={(e) => {
                      logImageDiagnostics(e.currentTarget, 'Standard-Custom-onError', postToFlutter);
                      postToFlutter({ type: 'TEMPLATE_LOADED', success: false, error: 'Image element failed to load' });
                    }}
                  />
                </div>
              ) : (
                /* ── 2. Default Prescription Template: Standard clinic letterhead layout ── */
                <div className="default-template-layer">
                  <div className="prescription-header">
                    <div>
                      <div className="clinic-title">{doctorInfo.clinic || 'Medical Clinic'}</div>
                      <div className="doctor-name">{doctorInfo.name || 'Doctor'}</div>
                      <div className="doctor-meta">
                        {doctorInfo.qualifications} {doctorInfo.regNumber ? `• Reg: ${doctorInfo.regNumber}` : ''}
                      </div>
                    </div>
                  </div>

                  <div className="patient-info-bar">
                    <div className="patient-field">
                      <span className="field-label">Patient:</span>
                      <span className="field-value">{patientInfo.name || '—'}</span>
                    </div>
                    <div className="patient-field">
                      <span className="field-label">Age/Sex:</span>
                      <span className="field-value">
                        {patientInfo.age} Y / {patientInfo.gender || '—'}
                      </span>
                    </div>
                    <div className="patient-field">
                      <span className="field-label">City:</span>
                      <span className="field-value">{patientInfo.city || '—'}</span>
                    </div>
                    <div className="patient-field">
                      <span className="field-label">Date:</span>
                      <span className="field-value">{consultationDate}</span>
                    </div>
                  </div>

                  <div className="rx-banner">℞</div>

                  <div className="default-template-body" />

                  <div className="prescription-footer">
                    <span>Consultation ID: {consultationId}</span>
                    <span>Doctor Signature: __________________</span>
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* 2. Excalidraw Ink Layer Container: Fills full viewport with transparent canvas */}
          <div className="excalidraw-canvas-container">
            <Excalidraw
              excalidrawAPI={handleApi}
              initialData={initialData}
              UIOptions={uiOptions}
              onChange={handleChange}
              onScrollChange={handleScrollChange}
            />
          </div>
        </div>
      )}
    </div>
  );
}
