APP := build/Build/Products/Debug/MacToolbox.app

.PHONY: project build run clean

project:
	xcodegen generate --quiet

build: project
	xcodebuild -project MacToolbox.xcodeproj -scheme MacToolbox -configuration Debug \
		-derivedDataPath build -quiet build

run: build
	-pkill -x MacToolbox
	open $(APP)

clean:
	rm -rf build MacToolbox.xcodeproj
