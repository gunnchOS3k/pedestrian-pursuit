# Pedestrian Pursuit — repo-native targets

.PHONY: engineering-wave010 headless-smoke stream-c-exhaust
.PHONY: vxp3-structural vxp3-capture vxp3-gates
.PHONY: vxp31-structural vxp31-capture vxp31-gates

engineering-wave010:
	bash tools/engineering_wave010/run_wave010.sh

headless-smoke:
	bash tools/run_godot_headless.sh

stream-c-exhaust:
	python3 tools/digital_engineering_exhaustion/stream_c/run_stream_c.py

vxp3-structural:
	python3 tools/vxp3/run_structural.py

vxp3-capture:
	bash tools/vxp3/run_capture.sh

vxp3-gates:
	python3 tools/vxp3/emit_gates.py

vxp31-structural:
	python3 tools/vxp31/run_structural.py

vxp31-capture:
	bash tools/vxp31/run_runtime_capture.sh

vxp31-gates:
	python3 tools/vxp31/emit_vxp31_gates.py
