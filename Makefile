APP := build/Build/Products/Debug/MacToolbox.app

.PHONY: project build run dmg clean

project:
	xcodegen generate --quiet

build: project
	xcodebuild -project MacToolbox.xcodeproj -scheme MacToolbox -configuration Debug \
		-derivedDataPath build -quiet build

run: build
	-pkill -x MacToolbox
	open $(APP)

dmg:
	scripts/package.sh $(or $(VERSION),0.0.0-local)

clean:
	rm -rf build dist MacToolbox.xcodeproj
