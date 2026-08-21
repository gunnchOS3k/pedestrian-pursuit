# Pedestrian Pursuit — repo-native targets

.PHONY: engineering-wave010 headless-smoke

engineering-wave010:
	bash tools/engineering_wave010/run_wave010.sh

headless-smoke:
	bash tools/run_godot_headless.sh
