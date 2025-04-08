# BeaconSyncAR-iBeacon-ARKit

iOS app for BLE-assisted AR synchronization using Apple ARKit's ARWorldMap.

![ScreenRecording_03-22-2025 14-27-37_1](https://github.com/user-attachments/assets/3cd3fe7e-235f-4dc1-b7f6-e30f26ed6000)

## 🚀 Quick Start

### Prerequisites
- Xcode 16+
- iOS device with ARKit support
- BLE Beacons (see [BeaconScanner](https://github.com/ARBeacon/BeaconScanner) for setup)
- Running [backend](https://github.com/ARBeacon/BeaconSyncAR-api)

### Local Setup

1. Clone the repository: 
```bash
git clone https://github.com/ARBeacon/BeaconSyncAR-iBeacon-ARKit.git
cd BeaconSyncAR-iBeacon-ARKit
```
2. Configure environment variables:
```bash
cp BeaconSyncAR-iBeacon-ARKit/Config.xcconfig.example BeaconSyncAR-iBeacon-ARKit/Config.xcconfig
```
Edit the Config.xcconfig file with your [backend](https://github.com/ARBeacon/BeaconSyncAR-api) endpoint url.

3. Run the app:

open the project in Xcode and click "Run".

_Note: This README.md was refined with the assistance of [DeepSeek](https://www.deepseek.com)_
