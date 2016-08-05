# iBeaconSDK2-example-iOS
###AXABeacon SDK

update the method of "startFindBleDevices", in the new method, you can specify one or more service types in serviceUUIDs, while in background mode, you must specify it to discovery specify peripheral. In the Demo, you can find how to discover or read RSSI of beacon in background.

#####Development

1.Import SDK into the project, and decompress SDK file. Drag SDK. Framework to the project, but not the entire file.

After drag to the project, it will pop up the following dialong box, select "Copy items into destination group's folder(if needed)", and click “Finish”.

Detail instruction, please refer to demo in the decompression bag.

Attention: iBeacon monitoring should add NSLocationAlwaysUsageDescription key value or NSLocationWhenInUseUsageDescription key value in the info.plist file.
