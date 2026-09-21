# VXP311 Viewport Validation

## Method
Viewport surfaces are captured with a **SubViewport at the exact requested size** (`capture_method: subviewport_exact_size`), rendering a live `MainMenu.tscn` instance. This avoids labeling a stretched 1280×720 framebuffer as 1600×900.

Window/`DisplayServer` resize alone is insufficient under `canvas_items` stretch and can yield off-by-one sizes (e.g. 1365×768).

## Manifest fields (per viewport id)
```json
{
  "id": "viewport_1366x768",
  "requested_resolution": "1366x768",
  "actual_png_width": 1366,
  "actual_png_height": 768,
  "dimension_match": true,
  "evidence_class": "REAL_RUNTIME_CAPTURE"
}
```

Pixel 6a-class landscape uses evidence class  
`PIXEL6A_LOGICAL_LANDSCAPE_REAL_RUNTIME_SIMULATION` (960×540) — **not** `PHYSICAL_DEVICE_CAPTURE`.

## Failures
- requested ≠ actual PNG IHDR
- duplicate SHA-256 across distinct viewport entries
- missing / near-empty PNG
- wrong evidence class
