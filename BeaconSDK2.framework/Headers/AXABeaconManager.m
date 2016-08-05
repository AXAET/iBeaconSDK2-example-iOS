//
//  AXABeaconManager.m
//  AXASDK
//
//  Created by AXAET_APPLE on 15/7/15.
//  Copyright (c) 2015年 axaet. All rights reserved.
//

#import "AXABeaconManager.h"
#import "AXABeacon.h"

#define ServiceUUID     @"FFF0"
#define WriteUUID       @"FFF1"
#define NotifyUUID      @"FFF2"

@import UIKit;
static AXABeaconManager *instance = nil;
@interface AXABeaconManager () <CLLocationManagerDelegate, CBCentralManagerDelegate,CBPeripheralDelegate, CBPeripheralManagerDelegate>
{
    
}
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CBPeripheralManager *peripheralManager;
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral *peripheral;
@property (nonatomic, strong) NSMutableArray *timerArray;

@property (nonatomic, strong) NSMutableArray *discoverDevices;

@end

@implementation AXABeaconManager

+ (AXABeaconManager *)sharedManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AXABeaconManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        self.discoverDevices = [[NSMutableArray alloc] init];
        [self createLocationManager];
        [self createCentralManager];
        [self createPeripheralManager];
    }
    return self;
}

- (void)createLocationManager {
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
}

- (void)createPeripheralManager {
    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
}

- (void)startRangingBeaconsInRegion:(CLBeaconRegion *)region {
    [self.locationManager startRangingBeaconsInRegion:region];
}

- (void)stopRangingBeaconsInRegion:(CLBeaconRegion *)region {
    [self.locationManager stopRangingBeaconsInRegion:region];
}

- (void)startMonitoringForRegion:(CLRegion *)region {
    [self.locationManager startMonitoringForRegion:region];
}

- (void)stopMonitoringForRegion:(CLRegion *)region {
    [self.locationManager stopMonitoringForRegion:region];
}

- (void)startAdvertisingWithProximityUUID:(NSString *)proximityUUID major:(CLBeaconMajorValue)major minor:(CLBeaconMinorValue)minor identifier:(NSString *)identifier power:(NSNumber *)power {
    
    CLBeaconRegion *region = [[CLBeaconRegion alloc] initWithProximityUUID:[[NSUUID alloc] initWithUUIDString:proximityUUID]
                                                                     major:major
                                                                     minor:minor
                                                                identifier:identifier];
    NSDictionary *beaconPeripheralData = [region peripheralDataWithMeasuredPower:power];
    [self.peripheralManager startAdvertising:beaconPeripheralData];
}

- (void)stopAdvertising {
    [self.peripheralManager stopAdvertising];
}

- (BOOL)isAdvertising {
    return self.peripheralManager.isAdvertising;
}

- (void)requestAlwaysAuthorization {
    if ([self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
        [self.locationManager requestAlwaysAuthorization];
    }
}

- (void)requestWhenInUseAuthorization {
    if ([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
        [self.locationManager requestWhenInUseAuthorization];
    }
}

- (void)createCentralManager {
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
}

-(void) startFindBleDevices {
    //    @[[CBUUID UUIDWithString:@"FFF0"]]
    [self.centralManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@YES}];
}

- (void)startFindBleDevicesWithServices:(NSArray<CBUUID *> *)serviceUUIDs options:(NSDictionary<NSString *,id> *)options {
    [self.centralManager scanForPeripheralsWithServices:serviceUUIDs options:options];
}

-(void) stopFindBleDevices {
    [self.centralManager stopScan];
}

- (void)connectBleDevice:(AXABeacon *)beacon {
    [self connectDevice:beacon.peripheral];
}

- (void)disconnectBleDevice:(AXABeacon *)beacon {
    [self disconnectDevice:beacon.peripheral];
}

-(void) connectDevice:(CBPeripheral *)peripheral {
    self.peripheral = peripheral;
    self.peripheral.delegate = self;
    [self.centralManager connectPeripheral:peripheral options:nil];
}


-(void) disconnectDevice:(CBPeripheral *)peripheral {
    [self.centralManager cancelPeripheralConnection:peripheral];
}

-(void)writeProximityUUID:(NSString *)proximityUUID {
    Byte byte[17];
    NSString *replaceStr = [proximityUUID stringByReplacingOccurrencesOfString:@"-" withString:@""];
    
    byte[0] = 0x01;
    for (int ix = 0; ix < 16; ix++) {
        NSRange range = NSMakeRange(2*ix, 2);
        NSString *subStr = [replaceStr substringWithRange:range];
        NSScanner *scanner = [NSScanner scannerWithString:subStr];
        unsigned int hex;
        [scanner scanHexInt:&hex];
        byte[ix + 1] = hex;
    }
    
    NSData *data = [[NSData alloc] initWithBytes:byte length:17];
    [self writeCharacteristic:self.peripheral sUUID:ServiceUUID cUUID:WriteUUID data:data];
}

- (void)writeMajor:(NSString *)major withMinor:(NSString *)minor withPower:(NSString *)power withAdvInterval:(NSString *)advInterval {
    Byte byte[8];
    byte[0] = 0x02;
    byte[1] = [major intValue]/256;
    byte[2] = [major intValue]%256;
    byte[3] = [minor intValue]/256;
    byte[4] = [minor intValue]%256;
    byte[5] = [power intValue];
    byte[6] = [advInterval intValue]/256;
    byte[7] = [advInterval intValue]%256;
    
    NSData *data = [[NSData alloc] initWithBytes:byte length:8];
    [self writeCharacteristic:self.peripheral sUUID:ServiceUUID cUUID:WriteUUID data:data];
}

- (void)writeName:(NSString *)name {
    Byte byte[20];
    byte[0] = 0x07;
    byte[1] = (int)name.length;
    const char *a = [name UTF8String];
    for (int i = 0; i< name.length; i++) {
        byte[i + 2] = a[i];
    }
    
    NSData *data = [[NSData alloc] initWithBytes:byte length:name.length + 2];
    [self writeCharacteristic:self.peripheral sUUID:ServiceUUID cUUID:WriteUUID data:data];
}

- (void)writePassword:(NSString *)psd {
    Byte password[7];
    password[0] = 0x04;
    const char *a = [psd UTF8String];
    for (int i = 0; i < 6; i++) {
        password[i+1] = a[i];
    }
    
    NSData *data = [[NSData alloc] initWithBytes:password length:7];
    [self writeCharacteristic:self.peripheral sUUID:ServiceUUID cUUID:WriteUUID data:data];
}

- (void)resetDevice {
    Byte byte[1];
    byte[0] = 0x03;
    NSData *data = [[NSData alloc] initWithBytes:byte length:1];
    [self writeCharacteristic:self.peripheral sUUID:ServiceUUID cUUID:WriteUUID data:data];
}

- (void)writeModifyPassword:(NSString *)originPsw newPSW:(NSString *)newPsw {
    Byte password[13];
    password[0] = 0x0c;
    const char *a = [originPsw UTF8String];
    const char *b = [newPsw UTF8String];
    for (int i = 0; i < 6; i++) {
        password[i+1] = a[i];
        password[i+7] = b[i];
    }
    
    NSData *data = [[NSData alloc] initWithBytes:password length:13];
    [self writeCharacteristic:self.peripheral sUUID:ServiceUUID cUUID:WriteUUID data:data];
}

#pragma mark - private method

- (void)writeCharacteristic:(CBPeripheral *)peripheral sUUID:(NSString *)sUUID cUUID:(NSString *)cUUID data:(NSData *)data {
    for ( CBService *service in peripheral.services ) {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:sUUID]]) {
            for ( CBCharacteristic *characteristic in service.characteristics ) {
                if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:cUUID]]) {
                    [peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
                }
            }
        }
    }
}

- (void)setNotificationForCharacteristic:(CBPeripheral *)peripheral sUUID:(NSString *)sUUID cUUID:(NSString *)cUUID enable:(BOOL)enable {
    for ( CBService *service in peripheral.services ) {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:sUUID]]) {
            for (CBCharacteristic *characteristic in service.characteristics ) {
                if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:cUUID]])
                {
                    [peripheral setNotifyValue:enable forCharacteristic:characteristic];
                }
            }
        }
    }
}

#pragma mark - delegate

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region {
    if ([self.beaconDelegate respondsToSelector:@selector(didRangeBeacons:inRegion:)]) {
        [self.beaconDelegate didRangeBeacons:beacons inRegion:region];
    }
}

- (void)locationManager:(CLLocationManager *)manager rangingBeaconsDidFailForRegion:(CLBeaconRegion *)region withError:(NSError *)error {
    if ([self.beaconDelegate respondsToSelector:@selector(rangingBeaconsDidFailForRegion:withError:)]) {
        [self.beaconDelegate rangingBeaconsDidFailForRegion:region withError:error];
    }
}

- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region {
    if ([self.beaconDelegate respondsToSelector:@selector(didStartMonitoringForRegion:)]) {
        [self.beaconDelegate didStartMonitoringForRegion:region];
    }
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error {
    if ([self.beaconDelegate respondsToSelector:@selector(monitoringDidFailForRegion:withError:)]) {
        [self.beaconDelegate monitoringDidFailForRegion:region withError:error];
    }
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    if ([self.beaconDelegate respondsToSelector:@selector(didEnterRegion:)]) {
        [self.beaconDelegate didEnterRegion:region];
    }
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    if ([self.beaconDelegate respondsToSelector:@selector(didExitRegion:)]) {
        [self.beaconDelegate didExitRegion:region];
    }
}

#pragma mark - centralManager delegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {

}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    if ([RSSI intValue] == 127) {
        return;
    }
    AXABeacon *beacon = [[AXABeacon alloc] init];
    beacon.peripheral = peripheral;
    beacon.name = [advertisementData objectForKey:CBAdvertisementDataLocalNameKey];
    beacon.rssi = RSSI;
    beacon.uuidString = peripheral.identifier.UUIDString;
    beacon.isConnectable = [[advertisementData objectForKey:CBAdvertisementDataIsConnectable] boolValue];
    
    AXABeacon *temp = [self findDeviceWithUUIDStr:beacon.uuidString inArray:self.discoverDevices];
    if (temp) {
        int index = (int)[self.discoverDevices indexOfObject:temp];
        [self.discoverDevices replaceObjectAtIndex:index withObject:beacon];
    }
    else {
        [self.discoverDevices addObject:beacon];
    }

    if ([self.tagDelegate respondsToSelector:@selector(didDiscoverBeacon:)]) {
        [self.tagDelegate didDiscoverBeacon:beacon];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    AXABeacon *beacon = [self findDeviceWithUUIDStr:peripheral.identifier.UUIDString inArray:self.discoverDevices];
    if ([self.tagDelegate respondsToSelector:@selector(didConnectBeacon:)]) {
        [self.tagDelegate didConnectBeacon:beacon];
    }
    [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    AXABeacon *beacon = [self findDeviceWithUUIDStr:peripheral.identifier.UUIDString inArray:self.discoverDevices];
    if ([self.tagDelegate respondsToSelector:@selector(didDisconnectBeacon:)]) {
        [self.tagDelegate didDisconnectBeacon:beacon];
    }
}

#pragma mark - CBPeripheralDelegate
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        NSLog(@"%s,%@",__func__, error);
    }
    
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        NSLog(@"%s,%@",__func__, error);
    }
    
    [self setNotificationForCharacteristic:peripheral sUUID:ServiceUUID cUUID:NotifyUUID enable:YES];
}

-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"%s,%@",__func__, error);
    }
    
    AXABeacon *beacon = [self findDeviceWithUUIDStr:peripheral.identifier.UUIDString inArray:self.discoverDevices];
    Byte byte[20];
    [characteristic.value getBytes:byte length:characteristic.value.length];
    
    if (byte[0] == 0x11) {
        NSString *uuid = [NSString stringWithFormat:@"%2X", byte[1]];
        for (int i = 2; i < 17; i++) {
            uuid = [uuid stringByAppendingString:[NSString stringWithFormat:@"%2X", byte[i]]];
            if (i == 4 || i==6 || i == 8 || i == 10) {
                uuid = [uuid stringByAppendingString:@"-"];
            }
        }
        uuid = [uuid stringByReplacingOccurrencesOfString:@" " withString:@"0"];
        beacon.proximityUUID = uuid;
        
        if ([self.tagDelegate respondsToSelector:@selector(didGetProximityUUIDForBeacon:)]) {
            [self.tagDelegate didGetProximityUUIDForBeacon:beacon];
        }
    }
    else if (byte[0] == 0x12) {
        NSString *major;
        NSString *minor;
        NSString *power;
        NSString *advInterval;
        major = [NSString stringWithFormat:@"%d", byte[1] * 256 + byte[2]];
        minor = [NSString stringWithFormat:@"%d", byte[3] * 256 + byte[4]];
        power = [NSString stringWithFormat:@"%d", byte[5]];
        advInterval = [NSString stringWithFormat:@"%d", byte[6] * 256 + byte[7]];
        
        beacon.major = major;
        beacon.minor = minor;
        beacon.power = power;
        beacon.advInterval = advInterval;
        
        if ([self.tagDelegate respondsToSelector:@selector(didGetMajorMinorPowerAdvInterval:)]) {
            [self.tagDelegate didGetMajorMinorPowerAdvInterval:beacon];
        }
    }
    else if (byte[0] == 0x05) {
        if ([self.tagDelegate respondsToSelector:@selector(didWritePassword:)]) {
            [self.tagDelegate didWritePassword:YES];
        }
    }
    else if (byte[0] == 0x0a) {
        if ([self.tagDelegate respondsToSelector:@selector(didWritePassword:)]) {
            [self.tagDelegate didWritePassword:NO];
        }
    }
    else if (byte[0] == 0x0b) {
    }
    else if (byte[0] == 0x06) {
    }
    else if (byte[0] == 0x0d) {
        if ([self.tagDelegate respondsToSelector:@selector(didModifyPasswordRight)]) {
            [self.tagDelegate didModifyPasswordRight];
        }
    }
}

-(void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error {

}

#pragma mark - private

- (AXABeacon *)findDeviceWithUUIDStr:(NSString *)str inArray:(NSMutableArray *)array {
    for (AXABeacon *temp in array) {
        if ([temp.uuidString isEqualToString:str]) {
            return temp;
        }
    }
    return nil;
}

#pragma mark - peripheralManager delegate 

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    NSLog(@"%s", __func__);
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error {
    NSLog(@"%d", peripheral.isAdvertising);
}

@end
