# Build, test and publish

Every PR runs Swift package tests and builds both native simulator applications on macOS. A successful push to main publishes both zipped simulator apps to a versioned GitHub prerelease (v0.1.<run number>). Simulator artifacts cannot be installed on physical devices.

The next step for physical-device distribution is App Store Connect registration and signing. Proposed bundle IDs are com.ericdalling.jokersandmarbles.controller and com.ericdalling.jokersandmarbles.tv; confirm before registering. TestFlight requires distribution signing for both targets, App Store Connect credentials, and app records. Do not commit signing secrets. The TestFlight workflow is separately gated and must be verified on physical devices.

Generate locally: brew install xcodegen; xcodegen generate; swift test. Open JokersAndMarbles.xcodeproj in Xcode. The initial apps are placeholders, not playable games.
